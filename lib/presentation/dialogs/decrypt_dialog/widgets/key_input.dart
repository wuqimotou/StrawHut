import 'dart:convert';

import 'package:flutter/material.dart';

/// Base64 密钥的最小合法长度（32 字节 Base64 编码）
///
/// 32 字节经 Base64 编码后为 ceil(32 / 3) * 4 = 44 字符，
/// 也可能因末尾填充不同而为 43 字符。
const _kMinKeyLength = 43;

/// Base64 密钥的最大合法长度
const _kMaxKeyLength = 44;

/// Base64 字符合法正则：大小写字母、数字、+/、末尾可选 =
final _kBase64Regex = RegExp(r'^[A-Za-z0-9+/]+=*$');

/// 解密对话框 - 密钥输入组件
///
/// 提供手动输入 Base64 密钥字符串的文本框。
///
/// 架构位置：应用层（Presentation Layer）→ 解密对话框子组件
/// 使用场景：DecryptDialog 中方式 A 解密
///
/// 功能说明：
/// - TextField 用于输入 Base64 密钥
/// - 格式验证（约 43~44 字符，Base64 格式）
/// - 输入错误时显示红色提示
/// - 通过 [TextEditingController] 暴露密钥值供父组件读取
/// - 支持 [onKeyChanged] 回调通知父组件密钥变化
///
/// 验证规则：
/// - 长度约 43~44 字符（32 字节 Base64 编码）
/// - 符合 Base64 字符集（A-Z, a-z, 0-9, +, /, =）
/// - 不能为空
class KeyInput extends StatefulWidget {
  /// 创建密钥输入组件实例
  ///
  /// 参数：
  /// - [controller] - 可选的文本控制器，用于外部控制和设置初始值
  /// - [onKeyChanged] - 密钥值变化时的回调，参数为当前输入的密钥字符串，
  ///   验证失败时传 null
  const KeyInput({super.key, this.controller, this.onKeyChanged});

  /// 文本控制器，用于外部控制和设置初始值（如从 .key 文件解析后填充）
  final TextEditingController? controller;

  /// 密钥值变化回调
  ///
  /// 当用户输入内容发生变化时触发。
  /// 参数为当前验证通过的密钥字符串，验证失败时为 null。
  final void Function(String?)? onKeyChanged;

  @override
  State<KeyInput> createState() => KeyInputState();
}

/// KeyInput 的内部状态类
///
/// 对外公开，允许父组件通过 GlobalKey 访问 setKey/clear 方法。
class KeyInputState extends State<KeyInput> {
  /// 内部文本控制器，在外部未提供时使用
  late final TextEditingController _controller;

  /// 是否显示错误信息
  bool _hasError = false;

  /// 错误消息文本
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // 使用外部提供的 controller 或创建内部实例
    _controller = widget.controller ?? TextEditingController();
    // 监听输入变化，实时验证格式
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // 仅在内部创建的 controller 需要释放
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// 文本变化时的处理：验证 Base64 格式和长度
  void _onTextChanged() {
    final text = _controller.text.trim();

    // 空输入时不报错，清除状态
    if (text.isEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
      widget.onKeyChanged?.call(null);
      return;
    }

    // 验证 Base64 字符合法性
    if (!_kBase64Regex.hasMatch(text)) {
      setState(() {
        _hasError = true;
        _errorMessage = '密钥格式不正确，请输入有效的 Base64 字符串';
      });
      widget.onKeyChanged?.call(null);
      return;
    }

    // 验证长度（32 字节 Base64 编码应为 43~44 字符）
    if (text.length < _kMinKeyLength || text.length > _kMaxKeyLength) {
      setState(() {
        _hasError = true;
        _errorMessage =
            '密钥长度不正确，应为 $_kMinKeyLength~$_kMaxKeyLength 个字符，'
            '当前为 ${text.length} 个字符';
      });
      widget.onKeyChanged?.call(null);
      return;
    }

    // 尝试验证 Base64 是否可以正常解码
    try {
      base64Decode(text);
      // 解码成功，清除错误
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
      widget.onKeyChanged?.call(text);
    } on FormatException {
      // Base64 解码失败
      setState(() {
        _hasError = true;
        _errorMessage = '密钥格式不正确，无法解析为有效的 Base64 数据';
      });
      widget.onKeyChanged?.call(null);
    }
  }

  /// 从外部设置密钥值（例如从 .key 文件解析后填充）
  ///
  /// 参数：[key] - Base64 编码的密钥字符串
  void setKey(String key) {
    _controller.text = key;
  }

  /// 清除输入的密钥
  void clear() {
    _controller.clear();
  }

  /// 获取当前输入的密钥值
  ///
  /// 返回：当前文本框中的密钥字符串（已 trim），如果为空则返回 null
  String? get currentKey {
    final text = _controller.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提示标签
        const Text(
          '方式 A：手动输入密钥',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        // 密钥输入框
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: '请输入 Base64 编码的密钥字符串',
            helperText: '32 字节密钥经 Base64 编码后约 43~44 个字符',
            helperStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.key),
            border: const OutlineInputBorder(),
            // 错误状态使用红色边框和错误文本
            errorText: _hasError ? _errorMessage : null,
            errorStyle: const TextStyle(fontSize: 12),
            // 清除按钮，方便用户快速清空重输
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: clear,
                    tooltip: '清除输入',
                  )
                : null,
          ),
          // 使用等宽字体，方便阅读和比对 Base64 字符串
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          // 最大行数限制，防止输入过长
          maxLines: 3,
          minLines: 1,
          // 自动大写关闭，避免 Base64 大小写被改变
          textCapitalization: TextCapitalization.none,
        ),
      ],
    );
  }
}
