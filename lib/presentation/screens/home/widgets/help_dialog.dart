import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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
                        _buildRepoHeader(context),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '1. 创建知识卡片',
                          '点击首页的"发布知识卡片"按钮进入编辑器。'
                              '在编辑器中，您可以：\n'
                              '• 填写卡片标题（必填）\n'
                              '• 使用富文本编辑器编写内容，支持文字、图片、附件等\n'
                              '• 添加描述和标签（可选，便于分类）\n'
                              '• 设置发布者别名或勾选"匿名模式"\n'
                              '• 也可以直接导入本地文件（文档、图片、音视频等）作为卡片内容\n'
                              '填写完成后点击"发布"按钮进入加密设置。',
                          StrawIcons.editNote,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '2. 选择加密模式',
                          '发布时可选择两种加密模式：\n'
                              '• 随机密钥模式（推荐）：系统自动生成 '
                              'AES-256 高强度密钥，安全性最高。发布后会生成 '
                              '.key 密钥文件，需妥善保管并单独分享给接收者。适合文件传输场景。\n'
                              '• 协商密钥模式：双方约定一个暗号（至少 '
                              '8 位），系统通过 PBKDF2 '
                              '派生密钥。无需传递密钥文件，适合口头或即时通讯分享暗号的场景。建议使用 '
                              '12 位以上含字母、数字、符号的暗号以增强安全性。',
                          StrawIcons.lock,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '3. 选择发布格式',
                          '加密完成后可选择两种发布格式：\n'
                              '• .straw 格式：专用二进制容器格式，体积小、效率高，推荐优先使用。\n'
                              '• .png 格式：将加密数据嵌入图片像素中，生成一张外观正常的图片。请注意：PNG '
                              '图片必须以原图方式发送（不压缩、不转格式、不二次截图），否则接收方将无法解密。'
                              '发布前会弹出强确认提醒。',
                          StrawIcons.image,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '4. 打开知识卡片',
                          '点击首页的"解密知识卡片"按钮：\n'
                              '• 选择 .straw 文件或 .png 图片\n'
                              '• 根据加密方式选择解密方法：\n'
                              '  - 密钥解密：手动输入 Base64 密钥，或上传 .key 文件，或从文件中自动提取\n'
                              '  - 暗号解密：输入加密时约定的暗号，也可从暗号保险库中选择已保存的暗号\n'
                              '• 解密成功后即可查看卡片内容\n'
                              '• 大文件解密支持取消操作',
                          StrawIcons.folderOpen,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '5. 暗号保险库',
                          '点击首页右上角的保险库图标可管理已保存的'
                              '暗号：\n'
                              '• 加密时可勾选"发布后保存暗号到保险库"\n'
                              '• 解密时可勾选"解密后保存暗号到保险库"\n'
                              '• 保险库中的暗号使用设备安全存储加密保存\n'
                              '• 最多可保存 10 条暗号\n'
                              '• 注意：保存暗号会修改本应用"零持久化存储"的隐私承诺，请自行评估风险',
                          StrawIcons.password,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _buildSection(
                          context,
                          '6. 安全与隐私',
                          '• 所有加密操作在本地完成，数据不会上传到任何服务器，零网络请求\n'
                              '• 采用 AES-256-GCM 认证加密，密钥通过 '
                              'PBKDF2-HMAC-SHA256（600000 次迭代）派生\n'
                              '• 除您主动保存的暗号外，不保存任何知识卡片、密钥、草稿或历史记录\n'
                              '• 请妥善保管密钥文件或暗号，遗忘后无法恢复内容',
                          StrawIcons.lock,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        SizedBox(height: tokens.spaceXs),
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
                      _buildRepoHeader(context),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '1. 创建知识卡片',
                        '点击首页的"发布知识卡片"按钮进入编辑器。'
                            '在编辑器中，您可以：\n'
                            '• 填写卡片标题（必填）\n'
                            '• 使用富文本编辑器编写内容，支持文字、图片、附件等\n'
                            '• 添加描述和标签（可选，便于分类）\n'
                            '• 设置发布者别名或勾选"匿名模式"\n'
                            '• 也可以直接导入本地文件（文档、图片、音视频等）作为卡片内容\n'
                            '填写完成后点击"发布"按钮进入加密设置。',
                        StrawIcons.editNote,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '2. 选择加密模式',
                        '发布时可选择两种加密模式：\n'
                            '• 随机密钥模式（推荐）：系统自动生成 '
                            'AES-256 高强度密钥，安全性最高。发布后会生成 '
                            '.key 密钥文件，需妥善保管并单独分享给接收者。适合文件传输场景。\n'
                            '• 协商密钥模式：双方约定一个暗号（至少 '
                            '8 位），系统通过 PBKDF2 '
                            '派生密钥。无需传递密钥文件，适合口头或即时通讯分享暗号的场景。建议使用 '
                            '12 位以上含字母、数字、符号的暗号以增强安全性。',
                        StrawIcons.lock,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '3. 选择发布格式',
                        '加密完成后可选择两种发布格式：\n'
                            '• .straw 格式：专用二进制容器格式，体积小、效率高，推荐优先使用。\n'
                            '• .png 格式：将加密数据嵌入图片像素中，生成一张外观正常的图片。请注意：PNG '
                            '图片必须以原图方式发送（不压缩、不转格式、不二次截图），否则接收方将无法解密。'
                            '发布前会弹出强确认提醒。',
                        StrawIcons.image,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '4. 打开知识卡片',
                        '点击首页的"解密知识卡片"按钮：\n'
                            '• 选择 .straw 文件或 .png 图片\n'
                            '• 根据加密方式选择解密方法：\n'
                            '  - 密钥解密：手动输入 Base64 密钥，或上传 .key 文件，或从文件中自动提取\n'
                            '  - 暗号解密：输入加密时约定的暗号，也可从暗号保险库中选择已保存的暗号\n'
                            '• 解密成功后即可查看卡片内容\n'
                            '• 大文件解密支持取消操作',
                        StrawIcons.folderOpen,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '5. 暗号保险库',
                        '点击首页右上角的保险库图标可管理已保存的'
                            '暗号：\n'
                            '• 加密时可勾选"发布后保存暗号到保险库"\n'
                            '• 解密时可勾选"解密后保存暗号到保险库"\n'
                            '• 保险库中的暗号使用设备安全存储加密保存\n'
                            '• 最多可保存 10 条暗号\n'
                            '• 注意：保存暗号会修改本应用"零持久化存储"的隐私承诺，请自行评估风险',
                        StrawIcons.password,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      _buildSection(
                        context,
                        '6. 安全与隐私',
                        '• 所有加密操作在本地完成，数据不会上传到任何服务器，零网络请求\n'
                            '• 采用 AES-256-GCM 认证加密，密钥通过 '
                            'PBKDF2-HMAC-SHA256（600000 次迭代）派生\n'
                            '• 除您主动保存的暗号外，不保存任何知识卡片、密钥、草稿或历史记录\n'
                            '• 请妥善保管密钥文件或暗号，遗忘后无法恢复内容',
                        StrawIcons.lock,
                      ),
                      SizedBox(height: tokens.spaceMd),
                      SizedBox(height: tokens.spaceXs),
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

  /// 构建 GitHub 仓库地址头部
  Widget _buildRepoHeader(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      color: tokens.surfaceAlt,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          NeumorphicIcon(
            StrawIcons.info,
            size: 18,
            color: tokens.inkSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GitHub 仓库',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  'https://github.com/wuqimotou/StrawHut',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.inkSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
