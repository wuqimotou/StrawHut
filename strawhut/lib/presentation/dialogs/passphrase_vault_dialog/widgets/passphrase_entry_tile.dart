import 'package:flutter/material.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/l10n/l10n.dart';

/// 暗号保险库条目卡片组件
///
/// 展示单条暗号条目的信息，包括：
/// - 锁图标 + 备注名称（标题）
/// - 创建时间（副标题，格式 YYYY-MM-DD HH:mm）
/// - 暗号内容（默认遮罩为 "********"，可通过眼睛图标切换显示）
/// - 删除按钮
///
/// 架构位置：应用层（Presentation Layer）→ 暗号保险库对话框子组件
class PassphraseEntryTile extends StatefulWidget {
  /// 创建暗号条目卡片实例
  ///
  /// 参数：
  /// - [entry]: 暗号条目数据
  /// - [onDelete]: 删除按钮回调，由父组件处理确认逻辑
  const PassphraseEntryTile({
    required this.entry,
    required this.onDelete,
    super.key,
  });

  /// 暗号条目数据
  final PassphraseEntry entry;

  /// 删除按钮回调
  ///
  /// 点击删除按钮时触发，由父组件负责显示确认对话框和执行删除操作。
  final VoidCallback onDelete;

  @override
  State<PassphraseEntryTile> createState() => _PassphraseEntryTileState();
}

class _PassphraseEntryTileState extends State<PassphraseEntryTile> {
  /// 暗号内容是否可见
  bool _isPassphraseVisible = false;

  /// 格式化 ISO 8601 时间字符串为 "YYYY-MM-DD HH:mm"
  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return '${dateTime.year}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } on Exception {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 左侧锁图标
            Icon(
              Icons.lock_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),

            // 中间内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 备注名称（标题）
                  Text(
                    widget.entry.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // 创建时间（副标题）
                  Text(
                    _formatDateTime(widget.entry.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 暗号内容行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isPassphraseVisible
                              ? widget.entry.passphrase
                              : '********',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: _isPassphraseVisible
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 眼睛切换图标
                      IconButton(
                        icon: Icon(
                          _isPassphraseVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPassphraseVisible = !_isPassphraseVisible;
                          });
                        },
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // 右侧删除按钮
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              onPressed: widget.onDelete,
              tooltip: l10n.delete,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
