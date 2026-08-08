import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/add_passphrase_dialog.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/widgets/passphrase_entry_tile.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 暗号保险库管理对话框
///
/// 展示已保存的暗号列表，支持以下操作：
/// - 查看所有已保存的暗号条目
/// - 添加新暗号（调用 AddPassphraseDialog）
/// - 删除单条暗号（带确认对话框）
/// - 清除全部暗号（需输入 DELETE 确认）
///
/// 平台适配：
/// - Windows：AlertDialog，ConstrainedBox(maxWidth: 480, maxHeight: 600)
/// - Android：ModalBottomSheet + DraggableScrollableSheet
///
/// 架构位置：应用层（Presentation Layer）→ 暗号保险库对话框
class PassphraseVaultDialog extends ConsumerStatefulWidget {
  /// 创建暗号保险库对话框实例
  const PassphraseVaultDialog({super.key});

  /// 弹出暗号保险库对话框
  ///
  /// 根据平台自动选择 AlertDialog 或 ModalBottomSheet。
  static Future<void> show(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) =>
              const _PassphraseVaultMobile(),
        ),
      );
    }
    return showDialog(
      context: context,
      builder: (context) => const PassphraseVaultDialog(),
    );
  }

  @override
  ConsumerState<PassphraseVaultDialog> createState() =>
      _PassphraseVaultDialogState();
}

/// PassphraseVaultDialog 的内部状态管理类
class _PassphraseVaultDialogState extends ConsumerState<PassphraseVaultDialog> {
  /// 处理添加暗号
  Future<void> _handleAddPassphrase() async {
    final result = await AddPassphraseDialog.show(context);
    if ((result ?? false) && mounted) {
      ref.invalidate(passphraseEntriesProvider);
    }
  }

  /// 处理删除单条暗号
  Future<void> _handleDeletePassphrase(String id, String label) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = NeumorphicTokens.ofContext(context);
        return Dialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusXLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeumorphicIcon(
                        StrawIcons.trash,
                        size: 22,
                        color: tokens.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.deletePassphraseTitle,
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
                  Text(
                    l10n.deletePassphraseMessage(label),
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NeumorphicButton(
                        label: l10n.cancel,
                        onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 12),
                    NeumorphicButton(
                      label: l10n.delete,
                        style: NeumorphicButtonStyle.primary,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if ((confirmed ?? false) && mounted) {
      try {
        final vaultService =
            ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
        await vaultService.deletePassphrase(id);
        ref.invalidate(passphraseEntriesProvider);
      } on PassphraseVaultException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: NeumorphicTokens.ofContext(context).error,
            ),
          );
        }
      }
    }
  }

  /// 处理清除全部暗号
  Future<void> _handleClearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = NeumorphicTokens.ofContext(context);
        var inputText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDeleteEnabled = inputText == 'DELETE';
            return Dialog(
              backgroundColor: tokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusXLarge),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          NeumorphicIcon(
                            StrawIcons.warning,
                            size: 22,
                            color: tokens.error,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.clearAllTitle,
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
                      Text(
                        l10n.clearAllWarning,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      Text(
                        l10n.clearAllConfirmInput,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spaceSm),
                      TextField(
                        onChanged: (value) {
                          inputText = value;
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSmall),
                          ),
                          hintText: 'DELETE',
                        ),
                      ),
                      SizedBox(height: tokens.spaceLg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          NeumorphicButton(
                            label: l10n.cancel,
                            onPressed: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          label: l10n.clearAll,
                            style: NeumorphicButtonStyle.primary,
                            onPressed: isDeleteEnabled
                                ? () => Navigator.pop(context, true)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if ((confirmed ?? false) && mounted) {
      try {
        final vaultService =
            ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
        await vaultService.clearAll();
        ref.invalidate(passphraseEntriesProvider);
      } on PassphraseVaultException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: NeumorphicTokens.ofContext(context).error,
            ),
          );
        }
      }
    }
  }

  /// 构建空状态界面
  Widget _buildEmptyState(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.unlock,
              size: 56,
              color: tokens.textHint,
            ),
            SizedBox(height: tokens.spaceMd),
            Text(
              l10n.vaultEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            Text(
              l10n.vaultEmptyDesc,
              style: TextStyle(fontSize: 13, color: tokens.textHint),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spaceLg + 4),
            NeumorphicButton(
              label: l10n.vaultAddButton,
              icon: StrawIcons.add,
              style: NeumorphicButtonStyle.primary,
              onPressed: _handleAddPassphrase,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建暗号列表
  Widget _buildPassphraseList(
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Column(
      children: [
        // 安全提示
        NeumorphicContainer(
          shape: NeumorphicShape.flat,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeumorphicIcon(
                StrawIcons.lock,
                size: 18,
                color: tokens.inkSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.vaultSecurityNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm + tokens.spaceXs),

        // 暗号条目列表
        ...entries.map(
          (entry) => PassphraseEntryTile(
            entry: entry,
            onDelete: () => _handleDeletePassphrase(entry.id, entry.label),
          ),
        ),

        SizedBox(height: tokens.spaceSm + tokens.spaceXs),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: NeumorphicButton(
                label: l10n.vaultAddButton,
                icon: StrawIcons.add,
                expanded: true,
                onPressed: _handleAddPassphrase,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeumorphicButton(
                label: l10n.vaultClearAllButton,
                icon: StrawIcons.trash,
                expanded: true,
                onPressed: entries.isNotEmpty ? _handleClearAll : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建底部计数标签
  Widget _buildCountLabel(AppLocalizations l10n, int count) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceSm + tokens.spaceXs),
      child: Text(
        l10n.vaultCountLabel(count),
        style: TextStyle(fontSize: 12, color: tokens.textHint),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final entriesAsync = ref.watch(passphraseEntriesProvider);

    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                      l10n.vaultTitle,
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
                  child: entriesAsync.when(
                    data: (entries) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (entries.isEmpty)
                            _buildEmptyState(l10n)
                          else
                            _buildPassphraseList(entries, l10n),
                          _buildCountLabel(l10n, entries.length),
                        ],
                      );
                    },
                    loading: () => SizedBox(
                      height: 200,
                      child: Center(
                        child: NeumorphicContainer(
                          shape: NeumorphicShape.flat,
                          borderRadius: tokens.radiusXLarge,
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: tokens.inkPrimary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                    error: (Object error, _) => SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NeumorphicIcon(
                              StrawIcons.error,
                              size: 40,
                              color: tokens.error,
                            ),
                            SizedBox(height: tokens.spaceSm),
                            Text(
                              error.toString(),
                              style: TextStyle(
                                color: tokens.error,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              Align(
                alignment: Alignment.centerRight,
                child: NeumorphicButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 移动端底部弹出版本
class _PassphraseVaultMobile extends ConsumerStatefulWidget {
  const _PassphraseVaultMobile();

  @override
  ConsumerState<_PassphraseVaultMobile> createState() =>
      _PassphraseVaultMobileState();
}

class _PassphraseVaultMobileState
    extends ConsumerState<_PassphraseVaultMobile> {
  Future<void> _handleAddPassphrase() async {
    final result = await AddPassphraseDialog.show(context);
    if ((result ?? false) && mounted) {
      ref.invalidate(passphraseEntriesProvider);
    }
  }

  Future<void> _handleDeletePassphrase(String id, String label) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = NeumorphicTokens.ofContext(context);
        return Dialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusXLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeumorphicIcon(
                        StrawIcons.trash,
                        size: 22,
                        color: tokens.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.deletePassphraseTitle,
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
                  Text(
                    l10n.deletePassphraseMessage(label),
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textSecondary,
                    ),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NeumorphicButton(
                        label: l10n.cancel,
                        onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 12),
                    NeumorphicButton(
                      label: l10n.delete,
                        style: NeumorphicButtonStyle.primary,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if ((confirmed ?? false) && mounted) {
      try {
        final vaultService =
            ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
        await vaultService.deletePassphrase(id);
        ref.invalidate(passphraseEntriesProvider);
      } on PassphraseVaultException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: NeumorphicTokens.ofContext(context).error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleClearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = NeumorphicTokens.ofContext(context);
        var inputText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDeleteEnabled = inputText == 'DELETE';
            return Dialog(
              backgroundColor: tokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusXLarge),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          NeumorphicIcon(
                            StrawIcons.warning,
                            size: 22,
                            color: tokens.error,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.clearAllTitle,
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
                      Text(
                        l10n.clearAllWarning,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      Text(
                        l10n.clearAllConfirmInput,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spaceSm),
                      TextField(
                        onChanged: (value) {
                          inputText = value;
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSmall),
                          ),
                          hintText: 'DELETE',
                        ),
                      ),
                      SizedBox(height: tokens.spaceLg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          NeumorphicButton(
                            label: l10n.cancel,
                            onPressed: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          label: l10n.clearAll,
                            style: NeumorphicButtonStyle.primary,
                            onPressed: isDeleteEnabled
                                ? () => Navigator.pop(context, true)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if ((confirmed ?? false) && mounted) {
      try {
        final vaultService =
            ref.read<PassphraseVaultService>(passphraseVaultServiceProvider);
        await vaultService.clearAll();
        ref.invalidate(passphraseEntriesProvider);
      } on PassphraseVaultException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: NeumorphicTokens.ofContext(context).error,
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.unlock,
              size: 56,
              color: tokens.textHint,
            ),
            SizedBox(height: tokens.spaceMd),
            Text(
              l10n.vaultEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            Text(
              l10n.vaultEmptyDesc,
              style: TextStyle(fontSize: 13, color: tokens.textHint),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spaceLg + 4),
            NeumorphicButton(
              label: l10n.vaultAddButton,
              icon: StrawIcons.add,
              style: NeumorphicButtonStyle.primary,
              onPressed: _handleAddPassphrase,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassphraseList(
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Column(
      children: [
        // 安全提示
        NeumorphicContainer(
          shape: NeumorphicShape.flat,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeumorphicIcon(
                StrawIcons.lock,
                size: 18,
                color: tokens.inkSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.vaultSecurityNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm + tokens.spaceXs),

        // 暗号条目列表
        ...entries.map(
          (entry) => PassphraseEntryTile(
            entry: entry,
            onDelete: () => _handleDeletePassphrase(entry.id, entry.label),
          ),
        ),

        SizedBox(height: tokens.spaceSm + tokens.spaceXs),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: NeumorphicButton(
                label: l10n.vaultAddButton,
                icon: StrawIcons.add,
                expanded: true,
                onPressed: _handleAddPassphrase,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeumorphicButton(
                label: l10n.vaultClearAllButton,
                icon: StrawIcons.trash,
                expanded: true,
                onPressed: entries.isNotEmpty ? _handleClearAll : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountLabel(AppLocalizations l10n, int count) {
    final tokens = NeumorphicTokens.ofContext(context);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceSm + tokens.spaceXs),
      child: Text(
        l10n.vaultCountLabel(count),
        style: TextStyle(fontSize: 12, color: tokens.textHint),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final entriesAsync = ref.watch(passphraseEntriesProvider);
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
                  l10n.vaultTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm + tokens.spaceXs),

          // 可滚动内容区域
          Flexible(
            child: SingleChildScrollView(
              child: entriesAsync.when(
                data: (entries) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entries.isEmpty)
                        _buildEmptyState(l10n)
                      else
                        _buildPassphraseList(entries, l10n),
                      _buildCountLabel(l10n, entries.length),
                    ],
                  );
                },
                loading: () => SizedBox(
                  height: 200,
                  child: Center(
                    child: NeumorphicContainer(
                      shape: NeumorphicShape.flat,
                      borderRadius: tokens.radiusXLarge,
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: tokens.inkPrimary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
                error: (Object error, _) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NeumorphicIcon(
                          StrawIcons.error,
                          size: 40,
                          color: tokens.error,
                        ),
                        SizedBox(height: tokens.spaceSm),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: tokens.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 底部关闭按钮
          Padding(
            padding: EdgeInsets.only(
              top: 8,
              bottom: 8 + bottomInset,
            ),
            child: NeumorphicButton(
              label: l10n.cancel,
              expanded: true,
              minimumSize: const Size(0, 48),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
