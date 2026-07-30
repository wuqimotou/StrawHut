import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 发布对话框 - 密钥显示组件
///
/// 展示加密生成的 Base64 密钥字符串，提供复制功能和安全提示。
///
/// 架构位置：应用层（Presentation Layer）→ 发布对话框子组件
/// 使用场景：PublishDialog 中密钥生成后显示
///
/// 显示内容：
/// - Base64 密钥字符串（SelectableText，等宽字体）
/// - 复制按钮（复制到剪贴板）
/// - 警告提示："请妥善保管此密钥，丢失后无法恢复"
///
/// 安全注意事项：
/// - 密钥为敏感数据，仅在对话框中临时展示
/// - 用户确认发布后，密钥引用应尽快清理
/// - 提示用户不要截图或分享密钥
class KeyDisplay extends StatefulWidget {
  /// 创建密钥显示组件实例
  ///
  /// 参数说明：
  /// - [keyBase64]: Base64 编码的密钥字符串，必填
  const KeyDisplay({required this.keyBase64, super.key});

  /// Base64 编码的密钥字符串
  final String keyBase64;

  @override
  State<KeyDisplay> createState() => _KeyDisplayState();
}

/// KeyDisplay 的内部状态管理类
///
/// 用于管理复制按钮的反馈状态（如显示"已复制"提示）。
class _KeyDisplayState extends State<KeyDisplay> {
  /// 是否刚刚完成复制操作
  bool _isCopied = false;

  /// 复制密钥到剪贴板
  ///
  /// 使用 Flutter 的 Clipboard API 将密钥字符串复制到系统剪贴板，
  /// 并显示短暂的视觉反馈（按钮变为"已复制"）。
  /// 同时弹出 SnackBar 提示用户复制成功。
  Future<void> _copyToClipboard() async {
    // 将密钥字符串写入系统剪贴板
    await Clipboard.setData(ClipboardData(text: widget.keyBase64));

    // 显示复制成功的视觉反馈
    setState(() {
      _isCopied = true;
    });

    final tokens = NeumorphicTokens.ofContext(context);
    // 显示 SnackBar 提示（AC-COPY-02）
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeumorphicIcon(
                StrawIcons.check,
                size: 20,
                color: tokens.surface,
              ),
              const SizedBox(width: 8),
              const Flexible(child: Text('密钥已复制到剪贴板')),
            ],
          ),
          backgroundColor: tokens.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // 1.5 秒后恢复按钮状态
    await Future.delayed(const Duration(milliseconds: 1500), () {});
    if (mounted) {
      setState(() {
        _isCopied = false;
      });
    }
  }

  /// 构建密钥显示 UI
  ///
  /// 布局结构：
  /// - Column 布局
  ///   - Text（提示文本："密钥（请妥善保存）"）
  ///   - NeumorphicContainer（凹槽，包含 SelectableText 显示密钥）
  ///   - NeumorphicButton（复制按钮）
  ///   - NeumorphicContainer（凹槽 + 警告色，安全提示）
  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 密钥标题
        Text(
          '密钥（请妥善保存）：',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: tokens.textPrimary,
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // 密钥字符串显示区域（凹陷软槽）
        NeumorphicContainer(
          shape: NeumorphicShape.concave,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            widget.keyBase64,
            // 使用等宽字体显示密钥，便于用户准确识别每个字符
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 0.5,
              color: tokens.textPrimary,
            ),
          ),
        ),
        SizedBox(height: tokens.spaceMd),

        // 复制按钮（软质凸起）
        NeumorphicButton(
          label: _isCopied ? '已复制' : '复制到剪贴板',
          icon: _isCopied ? StrawIcons.check : StrawIcons.copy,
          style: _isCopied
              ? NeumorphicButtonStyle.primary
              : NeumorphicButtonStyle.secondary,
          expanded: true,
          onPressed: _copyToClipboard,
        ),
        SizedBox(height: tokens.spaceLg),

        // 安全警告提示（扁平背景，退居次要，避免与输入框争夺视觉焦点）
        NeumorphicContainer(
          shape: NeumorphicShape.flat,
          color: tokens.surfaceAlt,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.all(12),
          child: Row(
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
                  '请妥善保管此密钥，丢失后无法恢复。\n'
                  '密钥丢失将无法解密知识卡片！',
                  style: TextStyle(
                    color: tokens.warning,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
