import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/core/migration/migration_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/migration_provider.dart';

/// 迁移旧版文件对话框
///
/// 允许用户选择旧版 JSON 格式的 .straw 文件，输入密钥，
/// 解密后将内容迁移到新版二进制格式。
///
/// 流程：
/// 1. 用户点击"选择旧版文件"按钮，选择 .straw 文件
/// 2. 系统检测文件是否为旧版格式
/// 3. 如果是旧版格式，用户输入密钥（Base64 或暗号）
/// 4. 点击"执行迁移"按钮
/// 5. 解密旧版内容 → 重新加密为新格式 → 保存新文件
/// 6. 显示迁移结果
class MigrationDialog extends ConsumerStatefulWidget {
  /// 创建迁移对话框实例
  const MigrationDialog({super.key});

  /// 显示迁移对话框
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const MigrationDialog(),
    );
  }

  @override
  ConsumerState<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends ConsumerState<MigrationDialog> {
  /// 选中的文件路径（Desktop）
  String? _selectedFilePath;

  /// 选中的文件名
  String? _selectedFileName;

  /// 是否为旧版格式
  bool? _isOldFormat;

  /// 密钥输入控制器
  final _keyController = TextEditingController();

  /// 是否正在迁移
  bool _isMigrating = false;

  /// 迁移结果消息
  String? _resultMessage;

  /// 迁移是否成功
  bool? _migrationSuccess;

  /// 旧版文件解析后的 JSON 数据
  Map<String, dynamic>? _oldFileJson;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  /// 选择 .straw 文件
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['straw'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;

    Uint8List? bytes;
    if (file.bytes != null) {
      bytes = file.bytes;
    } else if (file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } on Exception {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取文件')),
          );
        }
        return;
      }
    }

    if (bytes == null) return;

    final isOld = MigrationService.isOldFormat(bytes);
    Map<String, dynamic>? oldJson;
    if (isOld) {
      try {
        oldJson = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } on FormatException {
        oldJson = null;
      }
    }

    setState(() {
      _selectedFilePath = file.path;
      _selectedFileName = fileName;
      _isOldFormat = isOld;
      _oldFileJson = oldJson;
      _resultMessage = null;
      _migrationSuccess = null;
      _keyController.clear();
    });
  }

  /// 执行迁移
  Future<void> _performMigration() async {
    final l10n = AppLocalizations.of(context)!;
    final keyText = _keyController.text.trim();

    if (keyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.migrationKeyRequired)),
      );
      return;
    }

    final oldJson = _oldFileJson;
    if (oldJson == null) return;

    setState(() {
      _isMigrating = true;
      _resultMessage = null;
      _migrationSuccess = null;
    });

    try {
      // 1. Parse old format JSON
      final contentJson = _oldFileJson!['content'] as Map<String, dynamic>;
      final meta = CardMeta.fromJson(
        _oldFileJson!['meta'] as Map<String, dynamic>,
      );

      // 2. Extract legacy encrypted data and IV
      final encryptedDataBase64 = contentJson['encrypted_data'] as String?;
      final ivBase64 = contentJson['iv'] as String?;

      if (encryptedDataBase64 == null || ivBase64 == null) {
        setState(() {
          _isMigrating = false;
          _resultMessage = l10n.migrationFailed('文件中没有加密数据');
          _migrationSuccess = false;
        });
        return;
      }

      // 3. Derive key from input
      Uint8List key;
      final cryptoService = ref.read(cryptoServiceProvider);

      final kdfAlgorithm = contentJson['kdf_algorithm'] as String?;
      final saltBase64 = contentJson['salt'] as String?;
      final kdfIterations = contentJson['kdf_iterations'] as int?;

      if (kdfAlgorithm != null && saltBase64 != null && kdfIterations != null) {
        // Negotiated key mode: derive key from passphrase
        final salt = base64Decode(saltBase64);
        key = await cryptoService.deriveKeyFromPassphrase(
          passphrase: keyText,
          salt: salt,
          iterations: kdfIterations,
        );
      } else {
        // Random key mode: decode base64 key
        key = base64Decode(keyText);
      }

      // 4. Decrypt using legacy method (single-block AES-256-GCM)
      final plaintextBytes = cryptoService.decryptLegacyContent(
        encryptedDataBase64: encryptedDataBase64,
        ivBase64: ivBase64,
        key: key,
      );

      // 5. Get decrypted delta JSON
      final deltaJson = utf8.decode(plaintextBytes);

      // 6. Determine output path
      final inputPath = _selectedFilePath;
      String outputPath;
      if (inputPath != null && inputPath.isNotEmpty) {
        // Same directory, add _migrated suffix
        final lastSep = inputPath.lastIndexOf(Platform.pathSeparator);
        final dir = inputPath.substring(0, lastSep);
        final baseName = _selectedFileName ?? 'file';
        final nameWithoutExt = baseName.endsWith('.straw')
            ? baseName.substring(0, baseName.length - 6)
            : baseName;
        outputPath = '$dir${Platform.pathSeparator}'
            '${nameWithoutExt}_migrated.straw';
      } else {
        // Fallback: use a temp name
        final ts = DateTime.now().millisecondsSinceEpoch;
        outputPath = '${Directory.systemTemp.path}/migrated_$ts.straw';
      }

      // 7. Migrate using MigrationService
      final migrationService = ref.read(migrationServiceProvider);
      final migrationResult =
          await migrationService.migrateFromDecryptedContent(
        deltaJson: deltaJson,
        meta: meta,
        key: key,
        outputPath: outputPath,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
      );

      if (mounted) {
        setState(() {
          _isMigrating = false;
          if (migrationResult.success) {
            _resultMessage = l10n.migrationSuccess;
            _migrationSuccess = true;
          } else {
            final errMsg = migrationResult.errorMessage ?? '未知错误';
            _resultMessage = l10n.migrationFailed(errMsg);
            _migrationSuccess = false;
          }
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _resultMessage = l10n.migrationFailed(e.toString());
          _migrationSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.sync, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.migrateLegacyFile),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Description
              Text(
                l10n.migrateLegacyFileDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // File selection
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedFileName ?? l10n.selectLegacyFile,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // File format status
              if (_selectedFileName != null) ...[
                const SizedBox(height: 8),
                _buildFormatStatus(context),
              ],

              // Key input (only if old format detected)
              if (_isOldFormat ?? false) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _keyController,
                  decoration: InputDecoration(
                    labelText: _oldFileJson != null && _isNegotiatedKeyMode()
                        ? l10n.decryptPassphraseLabel
                        : l10n.copyKey,
                    hintText: _oldFileJson != null && _isNegotiatedKeyMode()
                        ? l10n.decryptPassphraseHint
                        : 'Base64',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      _oldFileJson != null && _isNegotiatedKeyMode()
                          ? Icons.lock_outline
                          : Icons.vpn_key,
                    ),
                  ),
                ),
              ],

              // Migration result
              if (_resultMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_migrationSuccess ?? false)
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_migrationSuccess ?? false)
                            ? Icons.check_circle
                            : Icons.error,
                        color: (_migrationSuccess ?? false)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resultMessage!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Loading indicator
              if (_isMigrating) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if ((_isOldFormat ?? false) && !_isMigrating)
          FilledButton(
            onPressed: _performMigration,
            child: Text(l10n.performMigration),
          ),
      ],
    );
  }

  /// Check if the old file uses negotiated key mode
  bool _isNegotiatedKeyMode() {
    final content = _oldFileJson?['content'] as Map<String, dynamic>?;
    if (content == null) return false;
    return content['kdf_algorithm'] != null;
  }

  /// Build the format status indicator
  Widget _buildFormatStatus(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_isOldFormat ?? false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              size: 18,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.oldFormatDetected,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      );
    } else if (_isOldFormat == false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.notOldFormat,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
