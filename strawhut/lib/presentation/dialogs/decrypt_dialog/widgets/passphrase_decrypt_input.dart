import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

/// 解密对话框 - 暗号输入组件
///
/// 提供暗号（passphrase）输入功能，用于协商密钥加密模式的解密流程。
///
/// 架构位置：应用层（Presentation Layer）→ 解密对话框子组件
/// 使用场景：DecryptDialog 中检测到协商密钥模式时显示
///
/// 功能：
/// - 暗号输入框（带密码可见性切换）
/// - 提示信息：此卡片通过暗号加密
/// - 提示文本：请与创作者确认暗号内容
///
/// 外部通过 GlobalKey<PassphraseDecryptInputState> 访问：
/// - passphrase: 获取当前暗号值（String?）
/// - clear(): 清空输入
class PassphraseDecryptInput extends ConsumerStatefulWidget {
  /// 创建解密暗号输入组件实例
  const PassphraseDecryptInput({
    super.key,
    this.enabled = true,
    this.onVaultSelectionChanged,
  });

  /// Whether selection and manual editing are enabled.
  final bool enabled;

  /// Reports whether a saved vault entry is currently selected.
  final ValueChanged<bool>? onVaultSelectionChanged;

  @override
  ConsumerState<PassphraseDecryptInput> createState() =>
      PassphraseDecryptInputState();
}

/// PassphraseDecryptInput 的公开状态类
///
/// 通过 GlobalKey 暴露给父组件，提供取值和清空功能。
class PassphraseDecryptInputState
    extends ConsumerState<PassphraseDecryptInput> {
  /// 暗号输入控制器
  final _controller = TextEditingController();

  /// 暗号是否可见
  bool _obscurePassphrase = true;

  PassphraseEntry? _selectedEntry;

  /// ID of the explicitly selected vault entry, if any.
  String? get selectedEntryId => _selectedEntry?.id;

  /// Whether the current value came from an explicit vault selection.
  bool get isFromVault => _selectedEntry != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final selectedEntry = _selectedEntry;
    if (selectedEntry != null && _controller.text != selectedEntry.passphrase) {
      setState(() {
        _selectedEntry = null;
      });
      widget.onVaultSelectionChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 获取当前暗号值
  ///
  /// 返回：当前文本框中的暗号字符串（已 trim），如果为空则返回 null
  String? get passphrase {
    final text = _controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// 清空输入
  void clear() {
    _controller.clear();
    _selectedEntry = null;
  }

  void _selectEntry(PassphraseEntry entry) {
    setState(() {
      _selectedEntry = entry;
      _controller.text = entry.passphrase;
      _obscurePassphrase = true;
    });
    widget.onVaultSelectionChanged?.call(true);
  }

  Future<void> _showVaultPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.read(passphraseEntriesProvider);
    final entries = entriesAsync.when(
      data: (data) => data,
      loading: () => <PassphraseEntry>[],
      error: (_, __) => <PassphraseEntry>[],
    );

    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.vaultEmptySelectHint)));
      }
      return;
    }

    final PassphraseEntry? selected;
    if (defaultTargetPlatform == TargetPlatform.android) {
      selected = await showModalBottomSheet<PassphraseEntry>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => _buildVaultBottomSheet(context, entries, l10n),
      );
    } else {
      selected = await showDialog<PassphraseEntry>(
        context: context,
        builder: (context) => _buildVaultDialog(context, entries, l10n),
      );
    }

    if (selected != null && mounted) {
      _selectEntry(selected);
    }
  }

  Widget _buildVaultDialog(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    return SimpleDialog(
      title: Text(l10n.selectPassphraseTitle),
      children: entries
          .map(
            (entry) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.label)),
                  Text(
                    l10n.usedCount(entry.useCount),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildVaultBottomSheet(
    BuildContext context,
    List<PassphraseEntry> entries,
    AppLocalizations l10n,
  ) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
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
                  leading: const Icon(Icons.lock_outline),
                  title: Text(entry.label),
                  subtitle: Text(l10n.usedCount(entry.useCount)),
                  onTap: () => Navigator.pop(context, entry),
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
    final entriesAsync = ref.watch(passphraseEntriesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        entriesAsync.when(
          data: (entries) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: widget.enabled && entries.isNotEmpty
                  ? () => _showVaultPicker(context)
                  : null,
              icon: const Icon(Icons.password, size: 18),
              label: Text(l10n.selectFromVault),
            ),
          ),
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

        if (_selectedEntry != null) ...[
          InputChip(
            avatar: const Icon(Icons.lock_outline, size: 18),
            label: Text(_selectedEntry!.label),
            onDeleted: widget.enabled
                ? () {
                    setState(() {
                      _selectedEntry = null;
                      _controller.clear();
                    });
                    widget.onVaultSelectionChanged?.call(false);
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],

        // 提示信息：此卡片通过暗号加密
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.decryptPassphraseInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 暗号输入框
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: l10n.decryptPassphraseLabel,
            hintText: l10n.decryptPassphraseHint,
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
      ],
    );
  }
}
