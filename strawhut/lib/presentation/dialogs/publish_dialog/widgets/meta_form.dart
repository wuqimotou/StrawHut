import 'package:flutter/material.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';

/// 发布对话框 - 元数据表单组件
///
/// 用于填写知识卡片的元信息，包括标题、发布者代号、描述、标签和匿名模式。
///
/// 架构位置：应用层（Presentation Layer）→ 发布对话框子组件
/// 使用场景：PublishDialog 的内容区域
///
/// 表单字段：
/// - 标题输入框（必填）：知识卡片的标题
/// - 发布者代号输入框（必填）：匿名模式下禁用
/// - 描述输入框（可选）：最多 200 字符
/// - 标签输入（可选）：用逗号分隔，最多 10 个标签，每个最多 20 字符
/// - 匿名模式开关（Switch）：
///   - 开启时：发布者代号自动生成为 Anonymous_xxxx
///   - 开启时：禁用发布者代号输入框
///
/// 表单验证规则：
/// - 标题不能为空
/// - 发布者代号不能为空（非匿名模式）
/// - 描述不超过 200 字符
/// - 标签数量不超过 10 个，每个不超过 20 字符
///
/// 数据来源：用户输入
/// 数据流向：PublishDialog 读取表单值 → 组装 CardMeta 对象
class MetaForm extends StatefulWidget {
  /// 创建元数据表单组件实例
  ///
  /// 参数说明：
  /// - [onChanged]: 表单变化时的回调函数，通知父组件表单状态已更新
  /// - [initialTitle]: 初始标题值，可用于自动填充编辑器首行内容
  const MetaForm({
    super.key,
    this.onChanged,
    this.initialTitle,
  });

  /// 表单变化时的回调函数
  final VoidCallback? onChanged;

  /// 初始标题值
  final String? initialTitle;

  @override
  MetaFormState createState() => MetaFormState();
}

/// MetaForm 的内部状态管理类
///
/// 负责管理所有表单控制器的生命周期，
/// 以及表单验证和状态同步。
///
/// 此类对外暴露是因为 PublishDialog 需要通过 GlobalKey 访问其
/// validate() 方法和 getter，以获取表单数据。
class MetaFormState extends State<MetaForm> {
  /// 全局表单 Key，用于触发表单验证
  final _formKey = GlobalKey<FormState>();

  /// 标题输入框控制器
  late final TextEditingController _titleController;

  /// 发布者代号输入框控制器
  final _publisherController = TextEditingController();

  /// 描述输入框控制器
  final _descriptionController = TextEditingController();

  /// 标签输入框控制器
  final _tagsController = TextEditingController();

  /// 匿名模式开关状态
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    // 初始化标题控制器，并设置初始值
    _titleController = TextEditingController(text: widget.initialTitle ?? '');

    // 为所有控制器添加监听器，在值变化时通知父组件
    _titleController.addListener(_notifyChanged);
    _publisherController.addListener(_notifyChanged);
    _descriptionController.addListener(_notifyChanged);
    _tagsController.addListener(_notifyChanged);
  }

  /// 通知父组件表单状态已变化
  void _notifyChanged() {
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    // 释放所有控制器资源，避免内存泄漏
    _titleController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// 验证表单是否有效
  ///
  /// 返回：true 表示表单验证通过，false 表示验证失败
  ///
  /// 验证规则：
  /// 1. 标题不能为空
  /// 2. 非匿名模式下，发布者代号不能为空
  /// 3. 描述不超过 200 字符
  /// 4. 标签数量不超过 10 个，每个标签不超过 20 字符
  bool validate() {
    return _formKey.currentState?.validate() ?? false;
  }

  /// 获取表单数据 - 标题
  String get title => _titleController.text.trim();

  /// 获取表单数据 - 发布者代号
  ///
  /// 匿名模式下返回 null，由父组件自动生成
  String? get publisherAlias {
    return _isAnonymous ? null : _publisherController.text.trim();
  }

  /// 获取表单数据 - 描述
  ///
  /// 返回空字符串时表示无描述
  String get description => _descriptionController.text.trim();

  /// 获取表单数据 - 标签列表
  ///
  /// 将逗号分隔的字符串解析为标签列表，
  /// 自动过滤空字符串和去除首尾空格。
  List<String> get tags {
    final raw = _tagsController.text.trim();
    if (raw.isEmpty) return [];

    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 获取表单数据 - 是否匿名模式
  bool get isAnonymous => _isAnonymous;

  /// 构建表单 UI
  ///
  /// 布局结构：
  /// - Form（包含全局验证逻辑）
  ///   - Column 布局
  ///     - TextFormField（标题）
  ///     - TextFormField（发布者代号）
  ///     - SwitchListTile（匿名模式）
  ///     - TextFormField（描述，maxLines: 3）
  ///     - TextFormField（标签，逗号分隔）
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题输入框（必填）
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '卡片标题',
              border: OutlineInputBorder(),
              hintText: '请输入知识卡片标题',
            ),
            // 标题验证器：不能为空
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入卡片标题';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 发布者代号输入框（非匿名模式下必填）
          TextFormField(
            controller: _publisherController,
            decoration: const InputDecoration(
              labelText: '发布者代号',
              border: OutlineInputBorder(),
              hintText: '请输入你的发布者代号',
            ),
            // 匿名模式下禁用输入框
            enabled: !_isAnonymous,
            // 发布者代号验证器：非匿名模式下不能为空
            validator: (value) {
              if (!_isAnonymous && (value == null || value.trim().isEmpty)) {
                return '请输入发布者代号';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // 匿名模式开关
          SwitchListTile(
            title: const Text('匿名发布'),
            subtitle: const Text('开启后发布者代号将自动生成'),
            value: _isAnonymous,
            // 切换匿名模式时更新状态并通知父组件
            onChanged: (value) {
              setState(() {
                _isAnonymous = value;
              });
              _notifyChanged();
            },
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),

          // 描述输入框（可选，最多 200 字符）
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: '描述（可选）',
              border: const OutlineInputBorder(),
              hintText: '简要描述卡片内容，帮助他人识别',
              // 显示字符计数器
              counterText: '${_descriptionController.text.length}/$MAX_DESCRIPTION_LENGTH',
            ),
            maxLines: 3,
            // 描述验证器：不超过最大长度限制
            maxLength: MAX_DESCRIPTION_LENGTH,
            validator: (value) {
              if (value != null && value.length > MAX_DESCRIPTION_LENGTH) {
                return '描述不能超过 $MAX_DESCRIPTION_LENGTH 个字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 标签输入框（可选，逗号分隔，最多 10 个标签）
          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: '标签（可选，用逗号分隔）',
              border: OutlineInputBorder(),
              hintText: '例如：Flutter, 加密, 笔记',
              helperText: '最多 10 个标签，每个最多 20 个字符',
            ),
            // 标签验证器：检查数量和长度限制
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }

              final parsedTags = value
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (parsedTags.length > MAX_TAGS_COUNT) {
                return '标签数量不能超过 $MAX_TAGS_COUNT 个';
              }

              for (final tag in parsedTags) {
                if (tag.length > MAX_TAG_LENGTH) {
                  final display =
                      tag.length > 10 ? '${tag.substring(0, 10)}...' : tag;
                  return '每个标签不能超过 $MAX_TAG_LENGTH 个字符（'
                      ' 当前："$display"）';
                }
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}
