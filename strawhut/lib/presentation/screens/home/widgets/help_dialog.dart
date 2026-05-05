import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// 使用教程对话框
///
/// 展示 StrawHut 应用的核心功能和使用步骤。
/// 包含：创建卡片、加密模式说明、解密卡片、安全提示。
class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // On Android, use full-screen dialog for better mobile UX
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('使用教程'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: '关闭',
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          context,
                          '1. 创建知识卡片',
                          '点击首页的"发布知识卡片"按钮进入编辑器，'
                              '输入标题、内容、描述和标签后点击发布，'
                              '即可生成加密的知识卡片文件。',
                          Icons.edit_note,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          context,
                          '2. 选择加密模式',
                          '发布时可选择两种加密模式：\n'
                              '• 随机密钥模式（推荐）：'
                              '系统自动生成高强度密钥，适合文件传输场景。\n'
                              '• 协商密钥模式：通过自定义暗号派生密钥，'
                              '适合口头分享场景。',
                          Icons.lock,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          context,
                          '3. 打开知识卡片',
                          '点击首页的"解密知识卡片"按钮选择 .straw 文件'
                              '或 .png 图片，输入密钥或暗号后即可解密查看内容。',
                          Icons.folder_open,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          context,
                          '4. 安全提示',
                          '• 所有加密操作在本地完成，数据不会上传到任何'
                              '服务器。\n'
                              '• 请妥善保管密钥文件或暗号，遗忘后无法'
                              '恢复内容。\n'
                              '• 支持将加密内容嵌入 PNG 图片元数据中分享。',
                          Icons.security,
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom action button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('我知道了'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop AlertDialog style
    return Dialog(
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
                  Icon(Icons.school, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '使用教程',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const Divider(height: 24),
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
                        Icons.edit_note,
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        context,
                        '2. 选择加密模式',
                        '发布时可选择两种加密模式：\n'
                            '• 随机密钥模式（推荐）：'
                            '系统自动生成高强度密钥，适合文件传输场景。\n'
                            '• 协商密钥模式：通过自定义暗号派生密钥，'
                            '适合口头分享场景。',
                        Icons.lock,
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        context,
                        '3. 打开知识卡片',
                        '点击首页的"解密知识卡片"按钮选择 .straw 文件'
                            '或 .png 图片，输入密钥或暗号后即可解密查看内容。',
                        Icons.folder_open,
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        context,
                        '4. 安全提示',
                        '• 所有加密操作在本地完成，数据不会上传到任何'
                            '服务器。\n'
                            '• 请妥善保管密钥文件或暗号，遗忘后无法'
                            '恢复内容。\n'
                            '• 支持将加密内容嵌入 PNG 图片元数据中分享。',
                        Icons.security,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 关闭按钮
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('我知道了'),
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
    IconData icon,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
