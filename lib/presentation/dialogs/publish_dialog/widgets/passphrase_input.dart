import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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

  /// 获取强度对应的颜色（使用 Neumorphic tokens 语义色）
  Color _getStrengthColor(NeumorphicTokens tokens) {
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
  /// 桌面端使用 Dialog，Android 端使用 ModalBottomSheet。
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
        final tokens = NeumorphicTokens.ofContext(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.vaultEmptySelectHint),
            backgroundColor: tokens.inkPrimary,
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
      // 桌面端: 使用 Dialog
      final selected = await showDialog<PassphraseEntry>(
        context: context,
        builder: (context) => _buildVaultDialog(context, entries, l10n),
      );
      if (selected != null) {
        setPassphraseFromVault(selected);
      }
    }
  }

  /// 构建桌面端保险库选择对话框
  Widget _buildVaultDialog(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NeumorphicIcon(
                    StrawIcons.lock,
                    size: 20,
                    color: tokens.inkPrimary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.selectPassphraseTitle,
                      style: TextStyle(
                        fontSize: 16,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: NeumorphicContainer(
                              shape: NeumorphicShape.convex,
                              borderRadius: tokens.radiusSmall,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: InkWell(
                                onTap: () => Navigator.pop(context, entry),
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSmall),
                                child: Row(
                                  children: [
                                    NeumorphicIcon(
                                      StrawIcons.lock,
                                      size: 20,
                                      color: tokens.inkSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      l10n.usedCount(entry.useCount),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 Android 端保险库选择底部弹窗
  Widget _buildVaultBottomSheet(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    final tokens = NeumorphicTokens.ofContext(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.lock,
                  size: 20,
                  color: tokens.inkPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.selectPassphraseTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: NeumorphicContainer(
                    shape: NeumorphicShape.convex,
                    borderRadius: tokens.radiusSmall,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, entry),
                      borderRadius:
                          BorderRadius.circular(tokens.radiusSmall),
                      child: Row(
                        children: [
                          NeumorphicIcon(
                            StrawIcons.lock,
                            size: 20,
                            color: tokens.inkSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  l10n.usedCount(entry.useCount),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
    final strengthColor = _getStrengthColor(tokens);
    final entriesAsync = ref.watch(passphraseEntriesProvider);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      // 透明边框：由外层凹陷软质容器的阴影定义边界
      borderSide: BorderSide(color: Colors.transparent, width: 1),
    );
    final inputBorderFocused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      borderSide: BorderSide(color: tokens.inkSecondary, width: 1.5),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 从保险库选择按钮
        entriesAsync.when(
          data: (entries) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeumorphicButton(
              label: l10n.selectFromVault,
              icon: StrawIcons.password,
              style: NeumorphicButtonStyle.secondary,
              expanded: true,
              onPressed: entries.isNotEmpty
                  ? () => _showVaultPicker(context)
                  : null,
            ),
          ),
          loading: () => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeumorphicButton(
              label: l10n.selectFromVault,
              icon: StrawIcons.password,
              style: NeumorphicButtonStyle.secondary,
              expanded: true,
              onPressed: null,
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeumorphicButton(
              label: l10n.selectFromVault,
              icon: StrawIcons.password,
              style: NeumorphicButtonStyle.secondary,
              expanded: true,
              onPressed: null,
            ),
          ),
        ),

        // 暗号输入框（凹陷软槽，视觉焦点）
        NeumorphicContainer(
          shape: NeumorphicShape.concave,
          borderRadius: tokens.radiusSmall,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _passphraseController,
            focusNode: _passphraseFocus,
            obscureText: _obscurePassphrase,
            decoration: InputDecoration(
              labelText: l10n.passphraseLabel,
              labelStyle: TextStyle(color: tokens.textSecondary),
              hintText: l10n.passphraseHint,
              hintStyle: TextStyle(color: tokens.textHint),
              prefixIcon: NeumorphicIcon(
                StrawIcons.lock,
                size: 20,
                color: tokens.textSecondary,
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: inputBorderFocused,
              filled: true,
              fillColor: tokens.surface,
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
            style: TextStyle(color: tokens.textPrimary),
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // 确认暗号输入框（凹陷软槽，视觉焦点）
        NeumorphicContainer(
          shape: NeumorphicShape.concave,
          borderRadius: tokens.radiusSmall,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _confirmController,
            focusNode: _confirmFocus,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: l10n.passphraseConfirmLabel,
              labelStyle: TextStyle(color: tokens.textSecondary),
              hintText: l10n.passphraseConfirmHint,
              hintStyle: TextStyle(color: tokens.textHint),
              prefixIcon: NeumorphicIcon(
                StrawIcons.lock,
                size: 20,
                color: tokens.textSecondary,
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: inputBorderFocused,
              filled: true,
              fillColor: tokens.surface,
              errorText: _mismatch ? l10n.passphraseMismatch : null,
              errorStyle: TextStyle(fontSize: 12, color: tokens.error),
              suffixIcon: IconButton(
                icon: NeumorphicIcon(
                  _obscureConfirm ? StrawIcons.eyeOff : StrawIcons.eye,
                  size: 20,
                  color: tokens.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
              ),
            ),
            style: TextStyle(color: tokens.textPrimary),
          ),
        ),

        // 暗号强度指示器（移到确认暗号框下方，spaceMd 间距确保不遮挡阴影）
        if (_passphraseController.text.isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          Row(
            children: [
              Text(
                '${l10n.passphraseStrengthLabel}：',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: LinearProgressIndicator(
                    value: _getStrengthValue(),
                    backgroundColor: tokens.surfaceAlt,
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
              style: TextStyle(fontSize: 12, color: tokens.error),
            ),
          ],
          // 弱强度警告（扁平背景，退居次要）
          if (_strength == PassphraseStrength.weak) ...[
            const SizedBox(height: 4),
            NeumorphicContainer(
              shape: NeumorphicShape.flat,
              color: tokens.surfaceAlt,
              borderRadius: tokens.radiusSmall,
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeumorphicIcon(
                    StrawIcons.warning,
                    size: 16,
                    color: tokens.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseWeakWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        SizedBox(height: tokens.spaceMd),

        // 安全提示（扁平背景，退居次要，避免与输入框争夺视觉焦点）
        NeumorphicContainer(
          shape: NeumorphicShape.flat,
          color: tokens.surfaceAlt,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeumorphicIcon(
                    StrawIcons.info,
                    size: 16,
                    color: tokens.inkSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseSecurityNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeumorphicIcon(
                    StrawIcons.info,
                    size: 16,
                    color: tokens.inkSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.passphraseStrengthRequirement,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
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
