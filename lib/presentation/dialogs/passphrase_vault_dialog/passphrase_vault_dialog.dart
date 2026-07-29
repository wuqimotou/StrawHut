import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/add_passphrase_dialog.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/widgets/passphrase_entry_tile.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

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
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePassphraseTitle),
        content: Text(l10n.deletePassphraseMessage(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
              backgroundColor: Colors.red[700],
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
        var inputText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDeleteEnabled = inputText == 'DELETE';
            return AlertDialog(
              title: Text(l10n.clearAllTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.clearAllWarning),
                  const SizedBox(height: 16),
                  Text(l10n.clearAllConfirmInput),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      inputText = value;
                      setDialogState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDeleteEnabled
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: isDeleteEnabled
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(l10n.clearAll),
                ),
              ],
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
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  /// 构建空状态界面
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_encryption_outlined,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.vaultEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.vaultEmptyDesc,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _handleAddPassphrase,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.vaultAddButton),
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
    return Column(
      children: [
        // 安全提示
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.vaultSecurityNote,
                  style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 暗号条目列表
        ...entries.map(
          (entry) => PassphraseEntryTile(
            entry: entry,
            onDelete: () => _handleDeletePassphrase(entry.id, entry.label),
          ),
        ),

        const SizedBox(height: 12),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleAddPassphrase,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.vaultAddButton),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: entries.isNotEmpty ? _handleClearAll : null,
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: entries.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                label: Text(
                  l10n.vaultClearAllButton,
                  style: entries.isNotEmpty
                      ? TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        )
                      : null,
                ),
                style: entries.isNotEmpty
                    ? OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建底部计数标签
  Widget _buildCountLabel(AppLocalizations l10n, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        l10n.vaultCountLabel(count),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(passphraseEntriesProvider);

    return AlertDialog(
      title: Text(l10n.vaultTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, _) => SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
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
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePassphraseTitle),
        content: Text(l10n.deletePassphraseMessage(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
              backgroundColor: Colors.red[700],
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
        var inputText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDeleteEnabled = inputText == 'DELETE';
            return AlertDialog(
              title: Text(l10n.clearAllTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.clearAllWarning),
                  const SizedBox(height: 16),
                  Text(l10n.clearAllConfirmInput),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      inputText = value;
                      setDialogState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDeleteEnabled
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: isDeleteEnabled
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(l10n.clearAll),
                ),
              ],
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
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_encryption_outlined,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.vaultEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.vaultEmptyDesc,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _handleAddPassphrase,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.vaultAddButton),
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
    return Column(
      children: [
        // 安全提示
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.vaultSecurityNote,
                  style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 暗号条目列表
        ...entries.map(
          (entry) => PassphraseEntryTile(
            entry: entry,
            onDelete: () => _handleDeletePassphrase(entry.id, entry.label),
          ),
        ),

        const SizedBox(height: 12),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleAddPassphrase,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.vaultAddButton),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: entries.isNotEmpty ? _handleClearAll : null,
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: entries.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                label: Text(
                  l10n.vaultClearAllButton,
                  style: entries.isNotEmpty
                      ? TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        )
                      : null,
                ),
                style: entries.isNotEmpty
                    ? OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountLabel(AppLocalizations l10n, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        l10n.vaultCountLabel(count),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题
          Text(
            l10n.vaultTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

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
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, _) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: Colors.red[700],
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
          Container(
            padding: EdgeInsets.only(
              top: 8,
              bottom: 8 + bottomInset,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
