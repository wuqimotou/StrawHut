import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_constants.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 添加暗号对话框
///
/// 提供暗号保存到保险库的表单界面，包含：
/// - 备注名称输入（可选，最多 50 字符）
/// - 暗号输入（必填，带可见性切换）
/// - 实时暗号强度指示器
/// - 安全风险警告与确认复选框
/// - 取消 / 确认保存按钮
///
/// 验证规则：
/// - veryWeak 暗号：确认保存按钮禁用，显示强度不足提示
/// - 复选框必须勾选才能启用确认保存按钮
/// - 保存时捕获异常：DUPLICATE_PASSPHRASE、VAULT_FULL、INVALID_PASSPHRASE
///
/// 架构位置：应用层（Presentation Layer）→ 暗号保险库对话框子组件
class AddPassphraseDialog extends ConsumerStatefulWidget {
  /// 创建添加暗号对话框实例
  ///
  /// [initialPassphrase] 可选的初始暗号，用于从解密对话框保存暗号时预填。
  const AddPassphraseDialog({super.key, this.initialPassphrase});

  /// 初始暗号（可选）
  final String? initialPassphrase;

  /// 弹出添加暗号对话框
  ///
  /// 返回值：
  /// - true：保存成功
  /// - null：用户取消
  static Future<bool?> show(
    BuildContext context, {
    String? initialPassphrase,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) => _AddPassphraseMobile(
            scrollController: scrollController,
            initialPassphrase: initialPassphrase,
          ),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AddPassphraseDialog(
        initialPassphrase: initialPassphrase,
      ),
    );
  }

  @override
  ConsumerState<AddPassphraseDialog> createState() =>
      _AddPassphraseDialogState();
}

/// AddPassphraseDialog 的内部状态管理类
class _AddPassphraseDialogState extends ConsumerState<AddPassphraseDialog> {
  /// 备注名称输入控制器
  final _labelController = TextEditingController();

  /// 暗号输入控制器
  final _passphraseController = TextEditingController();

  /// 暗号是否可见
  bool _obscurePassphrase = true;

  /// 当前暗号强度
  PassphraseStrength _strength = PassphraseStrength.veryWeak;

  /// 安全风险确认复选框状态
  bool _riskConfirmed = false;

  /// 错误消息
  String? _errorMessage;

  /// 是否正在保存
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _passphraseController.addListener(_onPassphraseChanged);
    // 如果有初始暗号，预填并评估强度
    if (widget.initialPassphrase != null &&
        widget.initialPassphrase!.isNotEmpty) {
      _passphraseController.text = widget.initialPassphrase!;
      _strength = PassphraseStrengthService.evaluate(
        widget.initialPassphrase!,
      );
    }
  }

  @override
  void dispose() {
    _passphraseController.removeListener(_onPassphraseChanged);
    _labelController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  /// 暗号输入变化回调
  void _onPassphraseChanged() {
    final newStrength =
        PassphraseStrengthService.evaluate(_passphraseController.text);
    setState(() {
      _strength = newStrength;
      _errorMessage = null;
    });
  }

  /// 获取强度对应的颜色
  Color _getStrengthColor() {
    final tokens = NeumorphicTokens.ofContext(context);
    switch (_strength) {
      case PassphraseStrength.strong:
        return tokens.success;
      case PassphraseStrength.medium:
        return tokens.warning;
      case PassphraseStrength.weak:
        return tokens.warning;
      case PassphraseStrength.veryWeak:
        return tokens.error;
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

  /// 确认保存按钮是否可用
  bool get _canSave =>
      _strength != PassphraseStrength.veryWeak &&
      _riskConfirmed &&
      _passphraseController.text.trim().isNotEmpty &&
      !_isSaving;

  /// 处理保存操作
  Future<void> _handleSave() async {
    if (!_canSave) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final vaultService =
          ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
      final label = _labelController.text.trim();
      final entryCount = await vaultService.getEntryCount();
      final defaultLabel = l10n.passphraseDefaultLabel(entryCount + 1);
      await vaultService.savePassphrase(
        passphrase: _passphraseController.text.trim(),
        label: label.isEmpty ? defaultLabel : label,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PassphraseVaultException catch (e) {
      setState(() {
        _isSaving = false;
        switch (e.code) {
          case 'DUPLICATE_PASSPHRASE':
            _errorMessage = l10n.duplicatePassphrase;
          case 'VAULT_FULL':
            _errorMessage = l10n.vaultFull;
          case 'INVALID_PASSPHRASE':
            _errorMessage = l10n.passphraseTooWeak;
          default:
            _errorMessage = e.message;
        }
      });
    } on Exception catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 构建暗号强度指示器
  Widget _buildStrengthIndicator(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);
    final strengthColor = _getStrengthColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 强度圆点指示器
            ...List.generate(4, (index) {
              final isActive = index <= _strength.index;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? strengthColor : tokens.surfaceAlt,
                ),
              );
            }),
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
        // veryWeak 详细提示
        if (_strength == PassphraseStrength.veryWeak) ...[
          const SizedBox(height: 4),
          Text(
            l10n.passphraseTooWeak,
            style: TextStyle(fontSize: 12, color: tokens.error),
          ),
        ],
      ],
    );
  }

  /// 构建安全风险警告区域
  Widget _buildRiskWarning(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeumorphicIcon(
                StrawIcons.warning,
                size: 20,
                color: tokens.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.savePassphraseWarning,
                  style: TextStyle(fontSize: 13, color: tokens.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 确认复选框
          InkWell(
            onTap: () {
              setState(() {
                _riskConfirmed = !_riskConfirmed;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _riskConfirmed,
                    onChanged: (value) {
                      setState(() {
                        _riskConfirmed = value ?? false;
                      });
                    },
                    activeColor: tokens.warning,
                    checkColor: tokens.surface,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.savePassphraseConfirm,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建表单内容（桌面端和移动端共用）
  Widget _buildFormContent(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 备注名称输入
        TextField(
          controller: _labelController,
          maxLength: PassphraseVaultConstants.passphraseLabelMaxLength,
          decoration: InputDecoration(
            labelText: l10n.passphraseLabelField,
            hintText: l10n.passphraseLabelHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
            ),
            counterText: '',
          ),
        ),
        SizedBox(height: tokens.spaceMd),

        // 暗号输入
        TextField(
          controller: _passphraseController,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: l10n.passphraseLabel,
            hintText: l10n.passphraseHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
            ),
            suffixIcon: IconButton(
              icon: NeumorphicIcon(
                _obscurePassphrase ? StrawIcons.eyeOff : StrawIcons.eye,
                size: 20,
                color: tokens.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassphrase = !_obscurePassphrase;
                });
              },
            ),
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // 暗号强度指示器（仅在输入暗号后显示）
        if (_passphraseController.text.isNotEmpty) ...[
          _buildStrengthIndicator(l10n),
          SizedBox(height: tokens.spaceSm + tokens.spaceXs),
        ],

        // 安全风险警告区域
        _buildRiskWarning(l10n),
        SizedBox(height: tokens.spaceSm + tokens.spaceXs),

        // 错误消息
        if (_errorMessage != null) ...[
          NeumorphicContainer(
            shape: NeumorphicShape.flat,
            borderRadius: tokens.radiusSmall,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeumorphicIcon(
                  StrawIcons.error,
                  size: 18,
                  color: tokens.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: tokens.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spaceSm),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);

    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  NeumorphicIcon(
                    StrawIcons.lock,
                    size: 22,
                    color: tokens.inkPrimary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.addPassphraseTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildFormContent(l10n),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: l10n.cancel,
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  NeumorphicButton(
                    label: l10n.confirmSave,
                    style: NeumorphicButtonStyle.primary,
                    onPressed: _canSave ? _handleSave : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 移动端底部弹出版本
class _AddPassphraseMobile extends ConsumerStatefulWidget {
  const _AddPassphraseMobile({
    required this.scrollController,
    this.initialPassphrase,
  });

  final ScrollController scrollController;
  final String? initialPassphrase;

  @override
  ConsumerState<_AddPassphraseMobile> createState() =>
      _AddPassphraseMobileState();
}

class _AddPassphraseMobileState extends ConsumerState<_AddPassphraseMobile> {
  final _labelController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _obscurePassphrase = true;
  PassphraseStrength _strength = PassphraseStrength.veryWeak;
  bool _riskConfirmed = false;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _passphraseController.addListener(_onPassphraseChanged);
    // 如果有初始暗号，预填并评估强度
    if (widget.initialPassphrase != null &&
        widget.initialPassphrase!.isNotEmpty) {
      _passphraseController.text = widget.initialPassphrase!;
      _strength = PassphraseStrengthService.evaluate(
        widget.initialPassphrase!,
      );
    }
  }

  @override
  void dispose() {
    _passphraseController.removeListener(_onPassphraseChanged);
    _labelController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _onPassphraseChanged() {
    final newStrength =
        PassphraseStrengthService.evaluate(_passphraseController.text);
    setState(() {
      _strength = newStrength;
      _errorMessage = null;
    });
  }

  Color _getStrengthColor() {
    final tokens = NeumorphicTokens.ofContext(context);
    switch (_strength) {
      case PassphraseStrength.strong:
        return tokens.success;
      case PassphraseStrength.medium:
        return tokens.warning;
      case PassphraseStrength.weak:
        return tokens.warning;
      case PassphraseStrength.veryWeak:
        return tokens.error;
    }
  }

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

  bool get _canSave =>
      _strength != PassphraseStrength.veryWeak &&
      _riskConfirmed &&
      _passphraseController.text.trim().isNotEmpty &&
      !_isSaving;

  Future<void> _handleSave() async {
    if (!_canSave) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final vaultService =
          ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
      final label = _labelController.text.trim();
      final entryCount = await vaultService.getEntryCount();
      final defaultLabel = l10n.passphraseDefaultLabel(entryCount + 1);
      await vaultService.savePassphrase(
        passphrase: _passphraseController.text.trim(),
        label: label.isEmpty ? defaultLabel : label,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on PassphraseVaultException catch (e) {
      setState(() {
        _isSaving = false;
        switch (e.code) {
          case 'DUPLICATE_PASSPHRASE':
            _errorMessage = l10n.duplicatePassphrase;
          case 'VAULT_FULL':
            _errorMessage = l10n.vaultFull;
          case 'INVALID_PASSPHRASE':
            _errorMessage = l10n.passphraseTooWeak;
          default:
            _errorMessage = e.message;
        }
      });
    } on Exception catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildStrengthIndicator(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);
    final strengthColor = _getStrengthColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(4, (index) {
              final isActive = index <= _strength.index;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? strengthColor : tokens.surfaceAlt,
                ),
              );
            }),
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
        if (_strength == PassphraseStrength.veryWeak) ...[
          const SizedBox(height: 4),
          Text(
            l10n.passphraseTooWeak,
            style: TextStyle(fontSize: 12, color: tokens.error),
          ),
        ],
      ],
    );
  }

  Widget _buildRiskWarning(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeumorphicIcon(
                StrawIcons.warning,
                size: 20,
                color: tokens.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.savePassphraseWarning,
                  style: TextStyle(fontSize: 13, color: tokens.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              setState(() {
                _riskConfirmed = !_riskConfirmed;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _riskConfirmed,
                    onChanged: (value) {
                      setState(() {
                        _riskConfirmed = value ?? false;
                      });
                    },
                    activeColor: tokens.warning,
                    checkColor: tokens.surface,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.savePassphraseConfirm,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽指示条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Row(
            children: [
              NeumorphicIcon(
                StrawIcons.lock,
                size: 22,
                color: tokens.inkPrimary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.addPassphraseTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),

          // 可滚动表单内容
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 备注名称
                  TextField(
                    controller: _labelController,
                    maxLength:
                        PassphraseVaultConstants.passphraseLabelMaxLength,
                    decoration: InputDecoration(
                      labelText: l10n.passphraseLabelField,
                      hintText: l10n.passphraseLabelHint,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(tokens.radiusSmall),
                      ),
                      counterText: '',
                    ),
                  ),
                  SizedBox(height: tokens.spaceMd),

                  // 暗号输入
                  TextField(
                    controller: _passphraseController,
                    obscureText: _obscurePassphrase,
                    decoration: InputDecoration(
                      labelText: l10n.passphraseLabel,
                      hintText: l10n.passphraseHint,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(tokens.radiusSmall),
                      ),
                      suffixIcon: IconButton(
                        icon: NeumorphicIcon(
                          _obscurePassphrase
                              ? StrawIcons.eyeOff
                              : StrawIcons.eye,
                          size: 20,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassphrase = !_obscurePassphrase;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spaceSm),

                  // 暗号强度指示器
                  if (_passphraseController.text.isNotEmpty) ...[
                    _buildStrengthIndicator(l10n),
                    SizedBox(height: tokens.spaceSm + tokens.spaceXs),
                  ],

                  // 安全风险警告
                  _buildRiskWarning(l10n),
                  SizedBox(height: tokens.spaceSm + tokens.spaceXs),

                  // 错误消息
                  if (_errorMessage != null) ...[
                    NeumorphicContainer(
                      shape: NeumorphicShape.flat,
                      borderRadius: tokens.radiusSmall,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NeumorphicIcon(
                            StrawIcons.error,
                            size: 18,
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
                    SizedBox(height: tokens.spaceSm),
                  ],
                ],
              ),
            ),
          ),

          // 底部操作栏
          Padding(
            padding: EdgeInsets.only(
              top: 8,
              bottom: 8 + bottomInset,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NeumorphicButton(
                  label: l10n.cancel,
                  onPressed:
                    _isSaving ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              NeumorphicButton(
                label: l10n.confirmSave,
                  style: NeumorphicButtonStyle.primary,
                  onPressed: _canSave ? _handleSave : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
