import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/utils/image_service.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';

/// 自定义 Quill 编辑器工具栏
///
/// 为 StrawHut 知识卡片编辑器提供格式控制按钮。
/// 所有按钮统一采用 Neumorphism 浮空（convex）样式，与全局设计体系一致。
///
/// 工具栏按钮分组：
/// 1. 撤销/重做：undo、redo
/// 2. 文本样式：加粗、斜体、下划线、删除线
/// 3. 标题：H1、H2、H3
/// 4. 列表：有序列表、无序列表
/// 5. 高级格式：代码块、引用块、分隔线
/// 6. 插入：图片
/// 7. 颜色：字体颜色选择器
///
/// 架构位置：应用层 -> 编辑器子组件
/// 依赖：接收外部传入的 QuillController，与编辑器实例绑定
class QuillToolbar extends StatefulWidget {
  /// 创建工具栏组件实例
  ///
  /// 参数 [controller] - Quill 编辑器控制器，用于与编辑器同步状态
  const QuillToolbar({
    required this.controller, super.key,
  });

  /// Quill 编辑器控制器，用于操作编辑器内容和读取当前选区格式状态
  final quill.QuillController controller;

  @override
  State<QuillToolbar> createState() => _QuillToolbarState();
}

class _QuillToolbarState extends State<QuillToolbar> {
  /// 水平滚动控制器，用于 Scrollbar
  final _scrollController = ScrollController();

  /// 待恢复的 toggledStyle
  ///
  /// 当用户点击格式化按钮后，flutter_quill 会将格式属性写入
  /// controller.toggledStyle。但如果用户随后点击编辑框（触发 selection
  /// 更新），_updateSelection 会清空 toggledStyle，导致格式状态丢失。
  ///
  /// 此变量在按钮点击后记录 toggledStyle，在 onSelectionChanged 中
  /// 检测到非文字输入的 selection 更新时恢复它。
  quill.Style? _pendingToggledStyle;

  /// 上次的文档长度，用于区分 selection 更新来源
  ///
  /// 文字输入会改变文档长度，而点击编辑框不会。
  /// 通过比较文档长度判断是否需要恢复 toggledStyle。
  int _lastDocLength = 0;

  @override
  void initState() {
    super.initState();
    _lastDocLength = widget.controller.document.length;
    widget.controller.onSelectionChanged = _onSelectionChanged;
  }

  @override
  void dispose() {
    // 清理回调，避免 controller 被复用时回调悬空
    if (widget.controller.onSelectionChanged == _onSelectionChanged) {
      widget.controller.onSelectionChanged = null;
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// selection 变化回调
  ///
  /// 当 selection 变化不是由文字输入引起（文档长度未变）时，
  /// 恢复之前记录的 toggledStyle，防止格式化状态丢失。
  void _onSelectionChanged(TextSelection selection) {
    final currentDocLength = widget.controller.document.length;
    if (currentDocLength == _lastDocLength && _pendingToggledStyle != null) {
      // 文档长度未变 → 非文字输入（如点击编辑框移动光标）
      // 恢复 toggledStyle，保持用户刚设置的格式状态
      widget.controller.forceToggledStyle(_pendingToggledStyle!);
    }
    _pendingToggledStyle = null;
    _lastDocLength = currentDocLength;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Container(
      // 工具栏容器：与全局水墨设计体系一致
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.divider),
        ),
      ),
      // Scrollbar 在 Padding 外层，贴容器底部
      child: Scrollbar(
        // 水平滚动条
        controller: _scrollController,
        thickness: 4,
        thumbVisibility: true,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          // 不裁切按钮的浮空阴影（上下溢出）
          clipBehavior: Clip.none,
          // 内边距用 Padding 而非 Container.padding，
          // 避免 decoration 边界裁切子按钮的浮空阴影
          child: Padding(
            // 垂直留足阴影空间（阴影 offset=4 + blur=8，需上下各 ~10px）
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Row(
              children: [
                // === 第一组：撤销/重做 ===
                _buildGroup([
                  _buildHistoryButton(isUndo: true),
                  _buildHistoryButton(isUndo: false),
                ]),

                _buildDivider(),

                // === 第二组：文本样式（加粗、斜体、下划线、删除线） ===
                _buildGroup([
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.bold,
                    icon: Icons.format_bold,
                    tooltip: '加粗',
                  ),
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.italic,
                    icon: Icons.format_italic,
                    tooltip: '斜体',
                  ),
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.underline,
                    icon: Icons.format_underline,
                    tooltip: '下划线',
                  ),
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.strikeThrough,
                    icon: Icons.format_strikethrough,
                    tooltip: '删除线',
                  ),
                ]),

                _buildDivider(),

                // === 第三组：标题（H1、H2、H3） ===
                _buildHeaderStyleDropdown(),

                _buildDivider(),

                // === 第四组：列表（有序、无序） ===
                _buildGroup([
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.ol,
                    icon: Icons.format_list_numbered,
                    tooltip: '有序列表',
                  ),
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.ul,
                    icon: Icons.format_list_bulleted,
                    tooltip: '无序列表',
                  ),
                ]),

                _buildDivider(),

                // === 第五组：高级格式（代码块、引用块、分隔线） ===
                _buildGroup([
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.codeBlock,
                    icon: Icons.code,
                    tooltip: '代码块',
                  ),
                  _buildToggleStyleButton(
                    attribute: quill.Attribute.blockQuote,
                    icon: Icons.format_quote,
                    tooltip: '引用块',
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.horizontal_rule,
                    tooltip: '分隔线',
                    onPressed: _insertHorizontalRule,
                  ),
                ]),

                _buildDivider(),

                // === 第六组：插入图片 ===
                _buildToolbarIconButton(
                  icon: Icons.image,
                  tooltip: '插入图片',
                  onPressed: () => _insertImage(context),
                ),

                _buildDivider(),

                // === 第七组：字体颜色选择器 ===
                _buildColorButton(),

                // Extra spacing at end for comfortable scroll
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建一组按钮（组内按钮间留 4px 间距避免阴影覆盖）
  Widget _buildGroup(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            buttons[i],
            if (i < buttons.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  /// 构建垂直分隔线
  Widget _buildDivider() {
    final tokens = NeumorphicTokens.ofContext(context);
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: tokens.divider,
    );
  }

  /// 构建撤销/重做按钮（浮空样式）
  ///
  /// 通过 childBuilder 将 flutter_quill 原生按钮渲染为 Neumorphism 浮空风格。
  /// [canPressed] 控制禁用态（无操作可撤销/重做时按钮禁用）。
  Widget _buildHistoryButton({required bool isUndo}) {
    return quill.QuillToolbarHistoryButton(
      isUndo: isUndo,
      controller: widget.controller,
      options: quill.QuillToolbarHistoryButtonOptions(
        iconData: isUndo ? Icons.undo : Icons.redo,
        tooltip: isUndo ? '撤销' : '重做',
        childBuilder: (dynamic options, dynamic extraOptions) {
          final opts = options as quill.QuillToolbarHistoryButtonOptions;
          final extra = extraOptions as quill.QuillToolbarHistoryButtonExtraOptions;
          return _ToolbarIconButton(
            icon: opts.iconData ?? (isUndo ? Icons.undo : Icons.redo),
            tooltip: opts.tooltip ?? (isUndo ? '撤销' : '重做'),
            onPressed: extra.canPressed ? extra.onPressed : null,
          );
        },
      ),
    );
  }

  /// 构建切换样式按钮（加粗、斜体等，浮空样式）
  ///
  /// 通过 childBuilder 渲染为浮空风格，选中态（isToggled）用墨色填充。
  ///
  /// 点击后记录 toggledStyle，防止后续 selection 更新（如点击编辑框）
  /// 清空格式状态。
  Widget _buildToggleStyleButton({
    required quill.Attribute<dynamic> attribute,
    required IconData icon,
    required String tooltip,
  }) {
    return quill.QuillToolbarToggleStyleButton(
      attribute: attribute,
      controller: widget.controller,
      options: quill.QuillToolbarToggleStyleButtonOptions(
        iconData: icon,
        tooltip: tooltip,
        childBuilder: (dynamic options, dynamic extraOptions) {
          final opts = options as quill.QuillToolbarToggleStyleButtonOptions;
          final extra =
              extraOptions as quill.QuillToolbarToggleStyleButtonExtraOptions;
          return _ToolbarIconButton(
            icon: opts.iconData ?? icon,
            tooltip: opts.tooltip ?? tooltip,
            isSelected: extra.isToggled,
            onPressed: () {
              extra.onPressed?.call();
              // 记录 toggledStyle，在 selection 更新时恢复
              _pendingToggledStyle = widget.controller.toggledStyle;
            },
          );
        },
      ),
    );
  }

  /// 构建字体颜色按钮（浮空样式）
  ///
  /// 通过 childBuilder 渲染为浮空风格，图标颜色反映当前字体颜色。
  /// 用 customOnPressedCallback 替换默认颜色选择器为水墨风对话框。
  Widget _buildColorButton() {
    return quill.QuillToolbarColorButton(
      controller: widget.controller,
      isBackground: false,
      options: quill.QuillToolbarColorButtonOptions(
        iconData: Icons.format_color_text,
        tooltip: '字体颜色',
        customOnPressedCallback: (controller, isBackground) async {
          await _showColorPickerDialog(controller, isBackground);
        },
        childBuilder: (dynamic options, dynamic extraOptions) {
          final opts = options as quill.QuillToolbarColorButtonOptions;
          final extra =
              extraOptions as quill.QuillToolbarColorButtonExtraOptions;
          return _ToolbarIconButton(
            icon: opts.iconData ?? Icons.format_color_text,
            tooltip: opts.tooltip ?? '字体颜色',
            iconColor: extra.iconColor,
            onPressed: extra.onPressed,
          );
        },
      ),
    );
  }

  /// 显示自定义水墨风颜色选择器对话框
  Future<void> _showColorPickerDialog(
    quill.QuillController controller,
    bool isBackground,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ColorPickerDialog(
        controller: controller,
        isBackground: isBackground,
      ),
    );
  }

  /// 构建标题样式下拉选择器（浮空样式）
  ///
  /// flutter_quill 的 DropdownButton childBuilder 不可用（抛 UnimplementedError），
  /// 因此自建等效组件，监听 controller 选区变化更新当前标题级别，
  /// 用 Neumorphism 浮空容器 + PopupMenuButton 实现。
  Widget _buildHeaderStyleDropdown() {
    return _HeaderStyleDropdown(controller: widget.controller);
  }

  /// 构建自定义浮空图标按钮（分隔线、图片等）
  Widget _buildToolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return _ToolbarIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  /// 插入水平分隔线
  void _insertHorizontalRule() {
    final index = widget.controller.selection.baseOffset;
    widget.controller.replaceText(
      index,
      0,
      const quill.BlockEmbed('hr', ''),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  /// 插入图片
  ///
  /// 弹出图片来源选择对话框，用户可以选择从文件选择或输入 URL。
  Future<void> _insertImage(BuildContext context) async {
    final tokens = NeumorphicTokens.ofContext(context);
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '插入图片',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                NeumorphicButton(
                  label: '从文件选择',
                  style: NeumorphicButtonStyle.secondary,
                  expanded: true,
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.file),
                ),
                SizedBox(height: tokens.spaceSm),
                NeumorphicButton(
                  label: '输入 URL',
                  style: NeumorphicButtonStyle.secondary,
                  expanded: true,
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.url),
                ),
                SizedBox(height: tokens.spaceLg),
                Align(
                  alignment: Alignment.centerRight,
                  child: NeumorphicButton(
                    label: '取消',
                    style: NeumorphicButtonStyle.secondary,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.url) {
      await _insertImageFromUrl(context);
    } else {
      await _pickImageFromFile(context);
    }
  }

  /// 通过 URL 插入图片
  Future<void> _insertImageFromUrl(BuildContext context) async {
    final tokens = NeumorphicTokens.ofContext(context);
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入图片 URL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/image.png',
                    hintStyle: TextStyle(color: tokens.textHint),
                    filled: true,
                    fillColor: tokens.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(tokens.radiusSmall),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(tokens.radiusSmall),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(tokens.radiusSmall),
                      borderSide: BorderSide(color: tokens.inkSecondary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: '取消',
                      style: NeumorphicButtonStyle.secondary,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                    const SizedBox(width: 12),
                    NeumorphicButton(
                      label: '确定',
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () =>
                          Navigator.pop(dialogContext, urlController.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (url != null && url.isNotEmpty) {
      _insertImageEmbed(url);
    }
  }

  /// 从文件选择器选择图片
  Future<void> _pickImageFromFile(BuildContext context) async {
    try {
      final result = await _pickFile();
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final base64DataUrl =
            await ImageService.compressAndEncodeImage(filePath);
        if (ImageService.isImageSizeExceeded(base64DataUrl.length)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('图片过大（压缩后仍超过 2MB），请使用更小的图片')),
            );
          }
          return;
        }
        _insertImageEmbed(base64DataUrl);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败：$e')),
        );
      }
    }
  }

  /// 调用 file_picker 选择文件
  Future<file_picker.FilePickerResult?> _pickFile() async {
    final picker = file_picker.FilePicker.platform;
    return picker.pickFiles(
      type: file_picker.FileType.image,
    );
  }

  /// 将图片嵌入编辑器
  void _insertImageEmbed(String url) {
    final index = widget.controller.selection.baseOffset;
    widget.controller.replaceText(
      index,
      0,
      quill.BlockEmbed.image(url),
      TextSelection.collapsed(offset: index + 1),
    );
  }
}

/// 图片来源枚举
enum ImageSource {
  /// 从文件选择
  file,

  /// 通过 URL 输入
  url,
}

/// 浮空工具栏图标按钮
///
/// 将 flutter_quill 原生 Material 按钮统一为 Neumorphism 浮空（convex）样式。
/// 选中态用墨色填充，禁用态平整无阴影，按下凹陷。
/// 支持 [IconData] 而非 SVG（与 flutter_quill 图标体系兼容）。
class _ToolbarIconButton extends StatefulWidget {
  const _ToolbarIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isSelected = false,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isSelected;
  final Color? iconColor;

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    NeumorphicShape shape;
    NeumorphicIntensity intensity;

    if (_isDisabled) {
      shape = NeumorphicShape.flat;
      intensity = NeumorphicIntensity.subtle;
    } else if (_isPressed) {
      shape = NeumorphicShape.concave;
      intensity = NeumorphicIntensity.normal;
    } else if (_isHovering && !_isMobile) {
      shape = NeumorphicShape.convex;
      intensity = NeumorphicIntensity.strong;
    } else {
      shape = NeumorphicShape.convex;
      intensity = _isMobile
          ? NeumorphicIntensity.subtle
          : NeumorphicIntensity.normal;
    }

    // 选中态：墨色填充，图标反白
    final surfaceColor =
        widget.isSelected ? tokens.inkPrimary : tokens.surface;
    final effectiveIconColor = widget.iconColor ??
        (widget.isSelected
            ? (tokens.brightness == Brightness.dark
                ? tokens.surface
                : const Color(0xFFF5F5F5))
            : (_isDisabled ? tokens.textHint : tokens.textPrimary));

    Widget button = SizedBox(
      width: 40,
      height: 40,
      child: NeumorphicContainer(
        shape: shape,
        intensity: intensity,
        color: surfaceColor,
        borderRadius: tokens.radiusMedium,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 18, color: effectiveIconColor),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return MouseRegion(
      cursor: _isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) {
        if (!_isDisabled && !_isMobile) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (_isHovering) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!_isDisabled) {
            setState(() => _isPressed = true);
          }
        },
        onTapUp: (_) {
          if (_isPressed) {
            setState(() => _isPressed = false);
            widget.onPressed?.call();
          }
        },
        onTapCancel: () {
          if (_isPressed) {
            setState(() => _isPressed = false);
          }
        },
        child: button,
      ),
    );
  }
}

/// 标题样式下拉选择器（浮空样式）
///
/// flutter_quill 的 DropdownButton childBuilder 不可用，因此自建等效组件：
/// - 监听 controller 选区变化，更新当前标题级别
/// - 浮空容器 + PopupMenu 实现选择交互
/// - 配色与全局 Neumorphism 水墨体系一致
class _HeaderStyleDropdown extends StatefulWidget {
  const _HeaderStyleDropdown({required this.controller});

  final quill.QuillController controller;

  @override
  State<_HeaderStyleDropdown> createState() => _HeaderStyleDropdownState();
}

class _HeaderStyleDropdownState extends State<_HeaderStyleDropdown> {
  quill.Attribute<dynamic> _selected = quill.Attribute.header;

  static const _options = <quill.Attribute<int?>>[
    quill.Attribute.h1,
    quill.Attribute.h2,
    quill.Attribute.h3,
    quill.Attribute.header,
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChange);
  }

  @override
  void didUpdateWidget(covariant _HeaderStyleDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChange);
      widget.controller.addListener(_didChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChange);
    super.dispose();
  }

  void _didChange() {
    final attr = widget.controller.toolbarButtonToggler[quill.Attribute.header.key];
    quill.Attribute<dynamic> newSelected;
    if (attr != null) {
      widget.controller.toolbarButtonToggler.remove(quill.Attribute.header.key);
      newSelected = attr;
    } else {
      newSelected = widget.controller
              .getSelectionStyle()
              .attributes[quill.Attribute.header.key] ??
          quill.Attribute.header;
    }
    if (newSelected != _selected) {
      setState(() => _selected = newSelected);
    }
  }

  String _label(quill.Attribute<dynamic> value) {
    return switch (value) {
      quill.Attribute.h1 => 'H1',
      quill.Attribute.h2 => 'H2',
      quill.Attribute.h3 => 'H3',
      quill.Attribute.header => '正文',
      _ => '正文',
    };
  }

  void _select(quill.Attribute<int?> attr) {
    setState(() => _selected = attr);
    widget.controller.formatSelection(attr);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return PopupMenuButton<quill.Attribute<int?>>(
      tooltip: '标题样式',
      onSelected: _select,
      itemBuilder: (context) => _options
          .map(
            (attr) => PopupMenuItem(
              value: attr,
              child: Text(
                _label(attr),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: attr == _selected ? FontWeight.w600 : FontWeight.w400,
                  color: attr == _selected ? tokens.inkPrimary : tokens.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      padding: EdgeInsets.zero,
      child: _DropdownTrigger(
        label: _label(_selected),
        tokens: tokens,
      ),
    );
  }
}

/// 下拉触发器（浮空样式）
class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.label,
    required this.tokens,
  });

  final String label;
  final NeumorphicTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
      child: NeumorphicContainer(
        shape: NeumorphicShape.convex,
        intensity: NeumorphicIntensity.normal,
        color: tokens.surface,
        borderRadius: tokens.radiusMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 水墨风颜色选择器对话框
///
/// 提供预设色板 + 自定义 HEX 输入，配色与全局 Neumorphism 体系一致。
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.controller,
    required this.isBackground,
  });

  final quill.QuillController controller;
  final bool isBackground;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late TextEditingController _hexController;
  Color _selectedColor = const Color(0xFF1C1C1E);

  /// 预设色板（低饱和水墨风 + 常用色）
  static const _presetColors = <Color>[
    Color(0xFF1C1C1E), // 浓墨
    Color(0xFF3A3A3C), // 淡墨
    Color(0xFF6A6A6C), // 水墨晕染
    Color(0xFFA04040), // 警告红
    Color(0xFFB8860B), // 提醒金
    Color(0xFF4A7C59), // 成功绿
    Color(0xFF2B6CB0), // 信息蓝
    Color(0xFF8B4513), // 赭石
    Color(0xFF5D4E75), // 紫罗兰
    Color(0xFFC0C0C0), // 银灰
    Color(0xFFE8E8E8), // 浅灰
    Color(0xFFFFFFFF), // 白色
  ];

  @override
  void initState() {
    super.initState();
    // 读取当前选区颜色
    final attrs = widget.controller.getSelectionStyle().attributes;
    final colorHex = widget.isBackground
        ? attrs['background']?.value
        : attrs['color']?.value;
    if (colorHex != null) {
      _selectedColor = _hexToColor(colorHex.toString());
    }
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyColor(Color? color) {
    if (color == null) {
      widget.controller.formatSelection(
        widget.isBackground
            ? const quill.BackgroundAttribute(null)
            : const quill.ColorAttribute(null),
      );
    } else {
      final hex = '#${_colorToHex(color)}';
      widget.controller.formatSelection(
        widget.isBackground
            ? quill.BackgroundAttribute(hex)
            : quill.ColorAttribute(hex),
      );
    }
  }

  String _colorToHex(Color color) {
    return color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
  }

  Color _hexToColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isBackground ? '选择背景颜色' : '选择字体颜色',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              // 预设色板
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                        _hexController.text = _colorToHex(color);
                      });
                      _applyColor(color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(
                          color: isSelected
                              ? tokens.inkPrimary
                              : tokens.divider,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: tokens.spaceMd),
              // HEX 输入
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.divider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        prefixText: '#',
                        hintText: 'RRGGBBAA',
                        hintStyle: TextStyle(color: tokens.textHint),
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSmall),
                          borderSide: BorderSide(color: tokens.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSmall),
                          borderSide: BorderSide(color: tokens.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSmall),
                          borderSide: BorderSide(color: tokens.inkSecondary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: tokens.textPrimary,
                      ),
                      onChanged: (value) {
                        try {
                          final color = _hexToColor(value);
                          setState(() => _selectedColor = color);
                          _applyColor(color);
                        } catch (_) {
                          // 忽略无效输入
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceLg),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: '清除颜色',
                    style: NeumorphicButtonStyle.secondary,
                    onPressed: () {
                      _applyColor(null);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 12),
                  NeumorphicButton(
                    label: '完成',
                    style: NeumorphicButtonStyle.primary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
