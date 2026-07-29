import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:strawhut/core/utils/image_service.dart';

/// 自定义 Quill 编辑器工具栏
///
/// 为 StrawHut 知识卡片编辑器提供格式控制按钮。
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
///
/// 使用场景：
/// EditorScreen 中将此组件放置在编辑器上方，用户通过点击按钮
/// 对选中文本或光标位置应用格式。
class QuillToolbar extends StatefulWidget {
  /// 创建工具栏组件实例
  ///
  /// 参数 [controller] - Quill 编辑器控制器，用于与编辑器同步状态
  const QuillToolbar({
    super.key,
    required this.controller,
  });

  /// Quill 编辑器控制器，用于操作编辑器内容和读取当前选区格式状态
  final quill.QuillController controller;

  @override
  State<QuillToolbar> createState() => _QuillToolbarState();
}

class _QuillToolbarState extends State<QuillToolbar> {
  /// 水平滚动控制器，用于 Scrollbar
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // 工具栏容器：带边框和背景色
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Scrollbar(
        // 水平滚动条
        controller: _scrollController,
        thickness: 4,
        thumbVisibility: true,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // === 第一组：撤销/重做 ===
              _buildGroup([
                quill.QuillToolbarHistoryButton(
                  isUndo: true,
                  controller: widget.controller,
                ),
                quill.QuillToolbarHistoryButton(
                  isUndo: false,
                  controller: widget.controller,
                ),
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
                  icon: Icons.strikethrough_s,
                  tooltip: '删除线',
                ),
              ]),

              _buildDivider(),

              // === 第三组：标题（H1、H2、H3） ===
              quill.QuillToolbarSelectHeaderStyleDropdownButton(
                controller: widget.controller,
              ),

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
                _buildCustomIconButton(
                  icon: Icons.horizontal_rule,
                  tooltip: '分隔线',
                  onPressed: _insertHorizontalRule,
                ),
              ]),

              _buildDivider(),

              // === 第六组：插入图片 ===
              _buildCustomIconButton(
                icon: Icons.image,
                tooltip: '插入图片',
                onPressed: () => _insertImage(context),
              ),

              _buildDivider(),

              // === 第七组：字体颜色选择器 ===
              quill.QuillToolbarColorButton(
                controller: widget.controller,
                isBackground: false,
              ),
              // Extra spacing at end for comfortable scroll
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建一组按钮（带内边距，至少 8dp 间距）
  Widget _buildGroup(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: buttons),
    );
  }

  /// 构建垂直分隔线
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withOpacity(0.3),
    );
  }

  /// 构建切换样式按钮（加粗、斜体等）
  ///
  /// 当光标位置已应用该样式时，按钮会高亮显示。
  Widget _buildToggleStyleButton({
    required quill.Attribute<dynamic> attribute,
    required IconData icon,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 48,
        child: quill.QuillToolbarToggleStyleButton(
          attribute: attribute,
          controller: widget.controller,
        ),
      ),
    );
  }

  /// 构建自定义图标按钮（用于非标准功能，如分隔线、图片）
  ///
  /// 确保按钮至少有 48x48dp 的触摸区域。
  Widget _buildCustomIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 48,
        child: IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 48,
          ),
        ),
      ),
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
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('插入图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从文件选择'),
              onTap: () => Navigator.pop(context, ImageSource.file),
              minLeadingWidth: 40,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('输入 URL'),
              onTap: () => Navigator.pop(context, ImageSource.url),
              minLeadingWidth: 40,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
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
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入图片 URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/image.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text),
            child: const Text('确定'),
          ),
        ],
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
  /// 独立为静态方法以便在需要时替换实现
  Future<file_picker.FilePickerResult?> _pickFile() async {
    final picker = file_picker.FilePicker.platform;
    return picker.pickFiles(
      type: file_picker.FileType.image,
      allowMultiple: false,
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
