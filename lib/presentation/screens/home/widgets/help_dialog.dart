import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';
import 'package:strawhut/presentation/dialogs/migration_dialog/migration_dialog.dart';

/// 使用教程对话框
///
/// 展示 StrawHut 应用的核心功能和使用步骤。
/// 包含：创建卡片、加密模式说明、解密卡片、安全提示。
class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    // On Android, use full-screen dialog for better mobile UX
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Dialog.fullscreen(
        backgroundColor: tokens.surface,
        child: Scaffold(
          backgroundColor: tokens.surface,
          appBar: AppBar(
            backgroundColor: tokens.surface,
            foregroundColor: tokens.textPrimary,
            elevation: 0,
            title: Text(
              '使用教程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            leading: NeumorphicIconButton(
              icon: StrawIcons.close,
              onPressed: () => Navigator.pop(context),
              tooltip: '关闭',
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(tokens.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          context,
                          '1. 创建知识卡片',
                          '点击首页的"发布知识卡片"按钮进入编辑器，'
                              '输入标题、内容、描述和标签后点击发布，'
                              '即可生成加密的知识卡片文件。',
                          StrawIcons.editNote,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '2. 选择加密模式',
                          '发布时可选择两种加密模式：\n'
                              '• 随机密钥模式（推荐）：'
                              '系统自动生成高强度密钥，适合文件传输场景。\n'
                              '• 协商密钥模式：通过自定义暗号派生密钥，'
                              '适合口头分享场景。',
                          StrawIcons.lock,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '3. 打开知识卡片',
                          '点击首页的"解密知识卡片"按钮选择 .straw 文件'
                              '或 .png 图片，输入密钥或暗号后即可解密查看内容。',
                          StrawIcons.folderOpen,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '4. 安全提示',
                          '• 所有加密操作在本地完成，数据不会上传到任何'
                              '服务器。\n'
                              '• 除您主动保存的暗号外，不保存任何知识卡片、'
                              '密钥、草稿或历史记录。\n'
                              '• 请妥善保管密钥文件或暗号，遗忘后无法'
                              '恢复内容。\n'
                              '• 支持将加密内容嵌入 PNG 图片元数据中分享。',
                          StrawIcons.lock,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        SizedBox(height: tokens.spaceXs),
                        _buildMigrationTile(context),
                      ],
                    ),
                  ),
                ),
                // Bottom action button
                Container(
                  padding: EdgeInsets.all(tokens.spaceMd),
                  color: tokens.surface,
                  child: SizedBox(
                    width: double.infinity,
                    child: NeumorphicButton(
                      label: '我知道了',
                      style: NeumorphicButtonStyle.primary,
                      expanded: true,
                      minimumSize: const Size(0, 48),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop Dialog style
    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  NeumorphicIcon(
                    StrawIcons.info,
                    size: 22,
                    color: tokens.inkPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '使用教程',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceSm),
              // 教程内容
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        context,
                        '1. 创建知识卡片',
                        '点击首页的"发布知识卡片"按钮进入编辑器，'
                            '输入标题、内容、描述和标签后点击发布，'
                            '即可生成加密的知识卡片文件。',
                        StrawIcons.editNote,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '2. 选择加密模式',
                        '发布时可选择两种加密模式：\n'
                            '• 随机密钥模式（推荐）：'
                            '系统自动生成高强度密钥，适合文件传输场景。\n'
                            '• 协商密钥模式：通过自定义暗号派生密钥，'
                            '适合口头分享场景。',
                        StrawIcons.lock,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '3. 打开知识卡片',
                        '点击首页的"解密知识卡片"按钮选择 .straw 文件'
                            '或 .png 图片，输入密钥或暗号后即可解密查看内容。',
                        StrawIcons.folderOpen,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '4. 安全提示',
                        '• 所有加密操作在本地完成，数据不会上传到任何'
                            '服务器。\n'
                            '• 请妥善保管密钥文件或暗号，遗忘后无法'
                            '恢复内容。\n'
                            '• 支持将加密内容嵌入 PNG 图片元数据中分享。',
                        StrawIcons.lock,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      SizedBox(height: tokens.spaceXs),
                      _buildMigrationTile(context),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              // 关闭按钮
              Align(
                alignment: Alignment.centerRight,
                child: NeumorphicButton(
                  label: '我知道了',
                  style: NeumorphicButtonStyle.primary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    String icon,
  ) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: NeumorphicIcon(
            icon,
            size: 20,
            color: tokens.inkPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建迁移旧版文件入口
  Widget _buildMigrationTile(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    final l10n = AppLocalizations.of(context)!;

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      borderRadius: tokens.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: NeumorphicIcon(
          StrawIcons.cloudUpload,
          size: 22,
          color: tokens.inkPrimary,
        ),
        title: Text(
          l10n.migrateLegacyFile,
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          l10n.migrateLegacyFileDescription,
          style: TextStyle(color: tokens.textSecondary),
        ),
        contentPadding: EdgeInsets.zero,
        onTap: () {
          Navigator.pop(context); // Close help dialog first
          MigrationDialog.show(context);
        },
      ),
    );
  }
}
