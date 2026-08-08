import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 解密对话框 - 密钥文件上传组件
///
/// 提供 .key 文件上传功能，通过文件选择器读取密钥文件中的 Base64 密钥。
///
/// 架构位置：应用层（Presentation Layer）→ 解密对话框子组件
/// 使用场景：DecryptDialog 中方式 B 解密
///
/// 功能说明：
/// - "上传 .key 文件" 按钮
/// - 使用 file_picker 选择 .key 文件
/// - 解析文件获取 key_base64
/// - 验证 .key 文件格式和完整性
/// - 成功后通过 [onKeyFileLoaded] 回调返回解析到的 Base64 密钥
///
/// 文件处理流程：
/// 1. 用户点击"上传 .key 文件"按钮
/// 2. 弹出文件选择器，仅接受 .key 扩展名
/// 3. 读取文件内容（JSON）
/// 4. 解析 JSON 获取 key_data.key_base64
/// 5. 验证文件格式（检查必填字段和格式）
/// 6. 验证通过 → 通过回调传递密钥
/// 7. 验证失败 → 显示错误提示
class KeyFileUpload extends ConsumerStatefulWidget {
  /// 创建密钥文件上传组件实例
  ///
  /// 参数：
  /// - [onKeyFileLoaded] - 成功解析 .key 文件后的回调，
  ///   参数为提取到的 Base64 密钥字符串
  const KeyFileUpload({
    required this.onKeyFileLoaded, super.key,
  });

  /// 密钥文件加载成功回调
  final void Function(String keyBase64) onKeyFileLoaded;

  @override
  ConsumerState<KeyFileUpload> createState() => _KeyFileUploadState();
}

class _KeyFileUploadState extends ConsumerState<KeyFileUpload> {
  /// 是否正在加载文件
  bool _isLoading = false;

  /// 上次加载的文件名（用于显示成功状态）
  String? _loadedFileName;

  /// 错误消息（用于显示在按钮下方）
  String? _errorMessage;

  /// 处理文件上传流程
  ///
  /// 完整流程：
  /// 1. 通过 FileSelectionService 弹出文件选择器（仅 .key 文件）
  /// 2. 读取文件字节内容
  /// 3. 解析 JSON
  /// 4. 验证格式和完整性
  /// 5. 提取 key_base64
  /// 6. 回调通知父组件
  Future<void> _handleFileUpload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ========== 步骤 1：通过 FileSelectionService 选择文件 ==========
      final fileSelectionService = ref.read(fileSelectionServiceProvider);
      final fileIOService = ref.read(fileIOServiceProvider);

      final result = await fileSelectionService.pickKeyFile();

      // 用户取消了文件选择
      if (result == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final (bytes, fileName) = result;

      // ========== 步骤 2：通过 IFileIOService 从字节解析 .key 文件 ==========
      late final KeyFile keyFile;
      try {
        keyFile = await fileIOService.readKeyFileFromBytes(bytes);
      } on FileException catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$fileName 格式不正确：\n${e.message}';
        });
        return;
      }

      // ========== 步骤 3：验证 .key 文件完整性（可选） ==========
      final jsonData = keyFile.toJson();
      final integrityMap = jsonData['integrity'] as Map<String, dynamic>?;
      if (integrityMap != null && integrityMap['hash'] != null) {
        final expectedHash = integrityMap['hash'] as String;
        if (expectedHash.isNotEmpty) {
          final fileContent = utf8.decode(bytes);
          final currentHash = _computeHash(fileContent);
          if (currentHash != expectedHash) {
            setState(() {
              _isLoading = false;
              _errorMessage = '$fileName 完整性校验失败，文件可能已被篡改，请勿使用';
            });
            return;
          }
        }
      }

      // ========== 步骤 4：提取 key_base64 ==========
      final keyBase64 = keyFile.keyData.keyBase64;

      if (keyBase64.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$fileName 中的密钥数据为空';
        });
        return;
      }

      // ========== 步骤 5：成功，回调通知父组件 ==========
      setState(() {
        _isLoading = false;
        _loadedFileName = fileName;
        _errorMessage = null;
      });

      widget.onKeyFileLoaded(keyBase64);
    } on FileException catch (e) {
      // 文件操作异常
      setState(() {
        _isLoading = false;
        _errorMessage = '文件读取失败：${e.message}';
      });
    } on Exception catch (e) {
      // 其他已知异常
      setState(() {
        _isLoading = false;
        _errorMessage = '加载密钥文件时发生错误：$e';
      });
    }
  }

  /// 简易 SHA-256 哈希计算（与 IntegrityService.computeHash 逻辑一致）
  ///
  /// 返回格式："sha256:{十六进制哈希值}"
  String _computeHash(String content) {
    final digest = sha256.convert(utf8.encode(content));
    return 'sha256:$digest';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提示标签
        Text(
          '方式 B：上传 .key 密钥文件',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: tokens.textPrimary,
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // 上传按钮区域
        NeumorphicButton(
          label: _isLoading ? '正在读取...' : '选择 .key 文件',
          icon: StrawIcons.uploadFile,
          expanded: true,
          onPressed: _isLoading ? null : _handleFileUpload,
        ),

        // 成功状态显示
        if (_loadedFileName != null && _errorMessage == null) ...[
          SizedBox(height: tokens.spaceSm),
          NeumorphicContainer(
            shape: NeumorphicShape.flat,
            borderRadius: tokens.radiusSmall,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.check,
                  size: 20,
                  color: tokens.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已加载密钥文件：$_loadedFileName',
                    style: TextStyle(
                      color: tokens.success,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 错误信息显示
        if (_errorMessage != null) ...[
          SizedBox(height: tokens.spaceSm),
          NeumorphicContainer(
            shape: NeumorphicShape.flat,
            borderRadius: tokens.radiusSmall,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeumorphicIcon(
                  StrawIcons.error,
                  size: 20,
                  color: tokens.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: tokens.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 验证结果
///
/// 封装格式验证的结果，包含是否有效和错误列表。
class ValidationResult {
  /// 创建验证结果实例
  const ValidationResult({required this.isValid, this.errors = const []});

  /// 验证是否通过
  final bool isValid;

  /// 验证错误列表（仅当 isValid 为 false 时有内容）
  final List<String> errors;
}
