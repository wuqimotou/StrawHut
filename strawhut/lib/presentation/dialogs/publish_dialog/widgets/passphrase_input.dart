import 'package:flutter/material.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';

/// 发布对话框 - 暗号输入组件
///
/// 提供暗号（passphrase）输入和确认功能，用于协商密钥加密模式。
///
/// 架构位置：应用层（Presentation Layer）→ 发布对话框子组件
/// 使用场景：PublishDialog 中选择协商密钥模式时显示
///
/// 功能：
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
class PassphraseInput extends StatefulWidget {
  /// 创建暗号输入组件实例
  const PassphraseInput({super.key});

  @override
  State<PassphraseInput> createState() => PassphraseInputState();
}

/// PassphraseInput 的公开状态类
///
/// 通过 GlobalKey 暴露给父组件，提供验证、取值和清空功能。
class PassphraseInputState extends State<PassphraseInput> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final strengthColor = _getStrengthColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
