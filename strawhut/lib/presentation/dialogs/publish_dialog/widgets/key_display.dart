import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const KeyDisplay({
    required this.keyBase64,
    super.key,
  });

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
  Future<void> _copyToClipboard() async {
    // 将密钥字符串写入系统剪贴板
    await Clipboard.setData(ClipboardData(text: widget.keyBase64));

    // 显示复制成功的视觉反馈
    setState(() {
      _isCopied = true;
    });

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
  ///   - Container（灰色背景，包含 SelectableText 显示密钥）
  ///   - ElevatedButton（复制按钮）
  ///   - Text（警告提示，红色/橙色）
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 密钥标题
        const Text(
          '密钥（请妥善保存）：',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        // 密钥字符串显示区域
        // 使用灰色背景容器包裹，增强视觉区分度
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SelectableText(
            widget.keyBase64,
            // 使用等宽字体显示密钥，便于用户准确识别每个字符
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 复制按钮
        // 提供一键复制功能，方便用户粘贴到其他位置
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copyToClipboard,
            // 复制成功后显示不同的图标和文本
            icon: Icon(_isCopied ? Icons.check : Icons.copy, size: 18),
            label: Text(_isCopied ? '已复制' : '复制到剪贴板'),
            style: ElevatedButton.styleFrom(
              // 复制成功后变为绿色，提供视觉反馈
              backgroundColor: _isCopied ? Colors.green[600] : null,
              foregroundColor: _isCopied ? Colors.white : null,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 安全警告提示
        // 使用醒目的颜色提醒用户妥善保管密钥
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 警告图标
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              // 警告文本
              Expanded(
                child: Text(
                  '请妥善保管此密钥，丢失后无法恢复。\n'
                  '密钥丢失将无法解密知识卡片！',
                  style: TextStyle(
                    color: Colors.orange[800],
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
