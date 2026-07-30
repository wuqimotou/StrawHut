import 'package:flutter/material.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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
    // 标签输入：实时规范化（中英文逗号统一、去除首尾空格）
    _tagsController.addListener(_normalizeTags);
    _tagsController.addListener(_notifyChanged);
  }

  /// 标签输入规范化监听器
  ///
  /// 将中文逗号（，）替换为英文逗号（,），去除每个标签首尾空格，
  /// 避免光标跳跃：仅在内容确实变化时才回写控制器。
  void _normalizeTags() {
    final text = _tagsController.text;
    if (text.isEmpty) return;

    // 仅当包含中文逗号或逗号附近有空格时才处理
    if (!text.contains('，') &&
        !text.contains(RegExp(r'\s*[,，]\s*'))) {
      return;
    }

    final normalized = text
        .replaceAll('，', ',')
        .split(',')
        .map((e) => e.trim())
        .join(',');

    if (normalized != text) {
      // 保留光标位置（尽量贴近末尾）
      final sel = _tagsController.selection;
      _tagsController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(
          offset: sel.baseOffset.clamp(0, normalized.length),
        ),
      );
    }
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
  /// 兼容英文逗号（,）和中文逗号（，），
  /// 自动过滤空字符串和去除首尾空格。
  List<String> get tags {
    final raw = _tagsController.text.trim();
    if (raw.isEmpty) return [];

    return raw
        .split(RegExp(r'[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 获取表单数据 - 是否匿名模式
  bool get isAnonymous => _isAnonymous;

  /// 更新标题字段值
  ///
  /// 外部调用方可通过此方法自动填充标题。
  /// 使用场景：
  /// - 编辑器内容模式：从编辑器首行文本自动填充
  /// - 文件上传模式：从文件名（不含扩展名）自动填充
  void updateTitle(String newTitle) {
    _titleController.text = newTitle;
  }

  /// 用凹陷软质容器包裹输入框，使其成为视觉焦点
  ///
  /// Neumorphism 层级原则：输入框是用户交互的核心区域，应通过凹陷软槽
  /// （双向阴影模拟内壁）突出；而说明性文字区块应扁平退居次要。
  Widget _concaveField(NeumorphicTokens tokens, TextFormField field) {
    return NeumorphicContainer(
      shape: NeumorphicShape.concave,
      borderRadius: tokens.radiusSmall,
      padding: EdgeInsets.zero,
      child: field,
    );
  }

  /// 构建表单 UI
  ///
  /// 布局结构：
  /// - Form（包含全局验证逻辑）
  ///   - Column 布局
  ///     - TextFormField（标题，凹陷软槽风格）
  ///     - TextFormField（发布者代号）
  ///     - 匿名模式切换（NeumorphicContainer + Switch）
  ///     - TextFormField（描述，maxLines: 3）
  ///     - TextFormField（标签，逗号分隔）
  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    // 统一的输入框边框样式
    // 未聚焦时边框透明，由外层凹陷软质容器的阴影定义边界（Neumorphism 核心原则）
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      borderSide: BorderSide(color: Colors.transparent, width: 1),
    );
    final inputBorderFocused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      borderSide: BorderSide(color: tokens.inkSecondary, width: 1.5),
    );

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题输入框（必填，凹陷软槽作为视觉焦点）
          _concaveField(
            tokens,
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '卡片标题',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: '请输入知识卡片标题',
                hintStyle: TextStyle(color: tokens.textHint),
                prefixIcon: NeumorphicIcon(
                  StrawIcons.editNote,
                  size: 20,
                  color: tokens.textSecondary,
                ),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorderFocused,
                filled: true,
                fillColor: tokens.surface,
              ),
              style: TextStyle(color: tokens.textPrimary),
              // 标题验证器：不能为空
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入卡片标题';
                }
                return null;
              },
            ),
          ),
          SizedBox(height: tokens.spaceMd),

          // 发布者代号输入框（非匿名模式下必填，凹陷软槽）
          _concaveField(
            tokens,
            TextFormField(
              controller: _publisherController,
              decoration: InputDecoration(
                labelText: '发布者代号',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: '请输入你的发布者代号',
                hintStyle: TextStyle(color: tokens.textHint),
                prefixIcon: NeumorphicIcon(
                  StrawIcons.password,
                  size: 20,
                  color: _isAnonymous
                      ? tokens.textHint
                      : tokens.textSecondary,
                ),
                // 匿名模式下显示"匿名模式·无需输入"标识
                suffixIcon: _isAnonymous
                    ? Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.inkWash.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NeumorphicIcon(
                              StrawIcons.lock,
                              size: 12,
                              color: tokens.inkSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '匿名·无需输入',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.inkSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorderFocused,
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  borderSide: BorderSide(
                    color: tokens.inkWash.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                filled: true,
                fillColor: _isAnonymous
                    ? tokens.surfaceAlt.withValues(alpha: 0.5)
                    : tokens.surface,
              ),
              style: TextStyle(
                color: _isAnonymous ? tokens.textHint : tokens.textPrimary,
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
          ),
          SizedBox(height: tokens.spaceXs),

          // 匿名模式切换（等宽附加框，用背景色突出激活态）
          // 与上方输入框等宽，激活时以水墨晕染色填充背景作为视觉强调
          InkWell(
            onTap: () {
              setState(() {
                _isAnonymous = !_isAnonymous;
                // 开启匿名时清空已输入的发布者代号，避免残留数据
                if (_isAnonymous) {
                  _publisherController.clear();
                }
              });
              _notifyChanged();
            },
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                // 激活态：水墨晕染背景突出；未激活：常规表面色
                color: _isAnonymous
                    ? tokens.inkWash.withValues(alpha: 0.12)
                    : tokens.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(
                  color: _isAnonymous
                      ? tokens.inkWash.withValues(alpha: 0.35)
                      : tokens.divider,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  NeumorphicIcon(
                    StrawIcons.lock,
                    size: 16,
                    color: _isAnonymous
                        ? tokens.inkSecondary
                        : tokens.textHint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '匿名发布',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _isAnonymous
                          ? tokens.inkSecondary
                          : tokens.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // 开关
                  Switch(
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                        // 开启匿名时清空已输入的发布者代号
                        if (_isAnonymous) {
                          _publisherController.clear();
                        }
                      });
                      _notifyChanged();
                    },
                    activeColor: tokens.inkPrimary,
                    activeTrackColor: tokens.inkWash,
                    inactiveThumbColor: tokens.surface,
                    inactiveTrackColor: tokens.surfaceAlt,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spaceSm),

          // 描述输入框（可选，最多 200 字符，凹陷软槽）
          _concaveField(
            tokens,
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述（可选）',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: '简要描述卡片内容，帮助他人识别',
                hintStyle: TextStyle(color: tokens.textHint),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorderFocused,
                filled: true,
                fillColor: tokens.surface,
                // 计数器移到软槽外，此处不显示
                counterText: '',
              ),
              style: TextStyle(color: tokens.textPrimary),
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
          ),
          // 描述字数计数器（扁平，在软槽外，动态更新）
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _descriptionController,
                builder: (context, value, _) {
                  return Text(
                    '${value.text.length}/$MAX_DESCRIPTION_LENGTH',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textHint,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMd),

          // 标签输入框（可选，逗号分隔，最多 10 个标签，凹陷软槽）
          _concaveField(
            tokens,
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: '标签（可选，用逗号分隔）',
                labelStyle: TextStyle(color: tokens.textSecondary),
                hintText: '例如：Flutter, 加密, 笔记',
                hintStyle: TextStyle(color: tokens.textHint),
                // helperText 移到软槽外
                prefixIcon: NeumorphicIcon(
                  StrawIcons.add,
                  size: 20,
                  color: tokens.textSecondary,
                ),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorderFocused,
                filled: true,
                fillColor: tokens.surface,
              ),
              style: TextStyle(color: tokens.textPrimary),
              // 标签验证器：检查数量和长度限制（兼容中英文逗号）
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }

                final parsedTags = value
                    .split(RegExp(r'[,，]'))
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
          ),
          // 标签说明（扁平，在软槽外）
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '最多 10 个标签，每个最多 20 个字符',
              style: TextStyle(fontSize: 12, color: tokens.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
