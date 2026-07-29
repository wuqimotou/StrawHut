import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

/// 发布对话框 - 暗号输入组件
///
/// 提供暗号（passphrase）输入和确认功能，用于协商密钥加密模式。
///
/// 架构位置：应用层（Presentation Layer）→ 发布对话框子组件
/// 使用场景：PublishDialog 中选择协商密钥模式时显示
///
/// 功能：
/// - 从保险库选择已保存暗号（快速填充）
/// - 暗号输入框（带密码可见性切换）
/// - 确认暗号输入框（带密码可见性切换）
/// - 实时暗号强度评估与可视化指示
/// - 两次输入一致性检测
/// - 安全提示信息
///
/// 外部通过 GlobalKey<PassphraseInputState> 访问：
/// - validate(): 验证暗号输入是否合法
/// - passphrase: 获取当前暗号值
/// - strength: 获取当前暗号强度
/// - clear(): 清空所有输入
class PassphraseInput extends ConsumerStatefulWidget {
  /// 创建暗号输入组件实例
  const PassphraseInput({super.key});

  @override
  ConsumerState<PassphraseInput> createState() => PassphraseInputState();
}

/// PassphraseInput 的公开状态类
///
/// 通过 GlobalKey 暴露给父组件，提供验证、取值和清空功能。
class PassphraseInputState extends ConsumerState<PassphraseInput> {
  /// 暗号输入控制器
  final _passphraseController = TextEditingController();

  /// 确认暗号输入控制器
  final _confirmController = TextEditingController();

  /// 暗号是否可见
  bool _obscurePassphrase = true;

  /// 确认暗号是否可见
  bool _obscureConfirm = true;

  /// 当前暗号强度
  PassphraseStrength _strength = PassphraseStrength.veryWeak;

  /// 两次输入是否不匹配
  bool _mismatch = false;

  /// 暗号输入焦点节点
  final _passphraseFocus = FocusNode();

  /// 确认暗号输入焦点节点
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _passphraseController.addListener(_onPassphraseChanged);
    _confirmController.addListener(_onConfirmChanged);
  }

  @override
  void dispose() {
    _passphraseController.removeListener(_onPassphraseChanged);
    _confirmController.removeListener(_onConfirmChanged);
    _passphraseController.dispose();
    _confirmController.dispose();
    _passphraseFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// 暗号输入变化回调
  void _onPassphraseChanged() {
    final newStrength =
        PassphraseStrengthService.evaluate(_passphraseController.text);
    final newMismatch = _confirmController.text.isNotEmpty &&
        _passphraseController.text != _confirmController.text;

    setState(() {
      _strength = newStrength;
      _mismatch = newMismatch;
    });
  }

  /// 确认暗号输入变化回调
  void _onConfirmChanged() {
    final newMismatch = _confirmController.text.isNotEmpty &&
        _passphraseController.text != _confirmController.text;

    setState(() {
      _mismatch = newMismatch;
    });
  }

  /// 从保险库条目填充暗号
  ///
  /// 将选中的保险库条目的暗号自动填充到输入框和确认框中，
  /// 并更新强度指示器，清除不一致状态。
  void setPassphraseFromVault(PassphraseEntry entry) {
    _passphraseController.text = entry.passphrase;
    _confirmController.text = entry.passphrase;
    _onPassphraseChanged();
    setState(() {
      _mismatch = false;
    });
  }

  /// 验证暗号输入是否合法
  ///
  /// 检查项：
  /// - 暗号不能为空
  /// - 暗号强度不能为 veryWeak
  /// - 两次输入必须一致
  ///
  /// 返回：验证是否通过
  bool validate() {
    final passphrase = _passphraseController.text;
    final confirm = _confirmController.text;

    // 检查暗号为空
    if (passphrase.trim().isEmpty) {
      return false;
    }

    // 检查强度为极弱
    if (_strength == PassphraseStrength.veryWeak) {
      return false;
    }

    // 检查两次输入不一致
    if (passphrase != confirm) {
      setState(() {
        _mismatch = true;
      });
      return false;
    }

    return true;
  }

  /// 获取当前暗号值
  String get passphrase => _passphraseController.text;

  /// 获取当前暗号强度
  PassphraseStrength get strength => _strength;

  /// 清空所有输入
  void clear() {
    _passphraseController.clear();
    _confirmController.clear();
    setState(() {
      _strength = PassphraseStrength.veryWeak;
      _mismatch = false;
    });
  }

  /// 获取强度对应的颜色
  Color _getStrengthColor() {
    switch (_strength) {
      case PassphraseStrength.strong:
        return Colors.green;
      case PassphraseStrength.medium:
        return Colors.yellow[700]!;
      case PassphraseStrength.weak:
        return Colors.orange;
      case PassphraseStrength.veryWeak:
        return Colors.red;
    }
  }

  /// 获取强度对应的文本
  String _getStrengthText(AppLocalizations l10n) {
    switch (_strength) {
      case PassphraseStrength.strong:
        return l10n.strengthStrong;
      case PassphraseStrength.medium:
        return l10n.strengthMedium;
      case PassphraseStrength.weak:
        return l10n.strengthWeak;
      case PassphraseStrength.veryWeak:
        return l10n.strengthVeryWeak;
    }
  }

  /// 获取强度进度条值（0.0 ~ 1.0）
  double _getStrengthValue() {
    switch (_strength) {
      case PassphraseStrength.strong:
        return 1.0;
      case PassphraseStrength.medium:
        return 0.75;
      case PassphraseStrength.weak:
        return 0.5;
      case PassphraseStrength.veryWeak:
        return 0.25;
    }
  }

  /// 显示保险库暗号选择器
  ///
  /// 桌面端使用 SimpleDialog，Android 端使用 ModalBottomSheet。
  /// 每个条目显示图标、备注名称和使用次数，不显示明文暗号。
  Future<void> _showVaultPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.read(passphraseEntriesProvider);

    final entries = entriesAsync.when(
      data: (data) => data,
      loading: () => <PassphraseEntry>[],
      error: (_, __) => <PassphraseEntry>[],
    );

    if (entries.isEmpty) {
      // 保险库为空，显示提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.vaultEmptySelectHint),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android: 使用 ModalBottomSheet
      final selected = await showModalBottomSheet<PassphraseEntry>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => _buildVaultBottomSheet(context, entries, l10n),
      );
      if (selected != null) {
        setPassphraseFromVault(selected);
      }
    } else {
      // 桌面端: 使用 SimpleDialog
      final selected = await showDialog<PassphraseEntry>(
        context: context,
        builder: (context) => _buildVaultSimpleDialog(context, entries, l10n),
      );
      if (selected != null) {
        setPassphraseFromVault(selected);
      }
    }
  }

  /// 构建桌面端保险库选择对话框
  Widget _buildVaultSimpleDialog(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    return SimpleDialog(
      title: Text(l10n.selectPassphraseTitle),
      children: entries.map((entry) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, entry),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                l10n.usedCount(entry.useCount),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建 Android 端保险库选择底部弹窗
  Widget _buildVaultBottomSheet(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 拖拽指示条
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.selectPassphraseTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(Icons.lock_outline, color: Colors.grey[600]),
                title: Text(entry.label),
                subtitle: Text(l10n.usedCount(entry.useCount)),
                onTap: () => Navigator.pop(context, entry),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom + 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final strengthColor = _getStrengthColor();
    final entriesAsync = ref.watch(passphraseEntriesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 从保险库选择按钮
        entriesAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.password, size: 18),
                  label: Text(l10n.selectFromVault),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showVaultPicker(context),
                icon: const Icon(Icons.password, size: 18),
                label: Text(l10n.selectFromVault),
              ),
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text(l10n.selectFromVault),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.password, size: 18),
              label: Text(l10n.selectFromVault),
            ),
          ),
        ),

        // 暗号输入框
        TextField(
          controller: _passphraseController,
          focusNode: _passphraseFocus,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: l10n.passphraseLabel,
            hintText: l10n.passphraseHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassphrase ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassphrase = !_obscurePassphrase;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 暗号强度指示器
        if (_passphraseController.text.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '${l10n.passphraseStrengthLabel}：',
                style: const TextStyle(fontSize: 13),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _getStrengthValue(),
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStrengthText(l10n),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          // 极弱强度详细提示
          if (_strength == PassphraseStrength.veryWeak) ...[
            const SizedBox(height: 4),
            Text(
              l10n.strengthVeryWeakDetail,
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ],
          // 弱强度警告
          if (_strength == PassphraseStrength.weak) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange[700], size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseWeakWarning,
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],

        // 确认暗号输入框
        TextField(
          controller: _confirmController,
          focusNode: _confirmFocus,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: l10n.passphraseConfirmLabel,
            hintText: l10n.passphraseConfirmHint,
            border: const OutlineInputBorder(),
            errorText: _mismatch ? l10n.passphraseMismatch : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirm = !_obscureConfirm;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 安全提示
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseSecurityNote,
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.blue[700], size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseStrengthRequirement,
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
