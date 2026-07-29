import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';

/// 线性细描边图标系统（Neumorphism 风格）
///
/// 设计规范：
/// - stroke-width: 1.6（细描边，柔和不抢眼）
/// - stroke-linecap: round
/// - stroke-linejoin: round
/// - 不使用 fill，仅描边
/// - 24x24 viewBox，颜色通过 colorParam 注入 currentColor
///
/// 用法：
/// ```dart
/// NeumorphicIcon(StrawIcons.lock, size: 24, color: tokens.inkPrimary)
/// ```
class StrawIcons {
  StrawIcons._();

  /// SVG 公共头部与样式注入
  ///
  /// 通过 `__COLOR__` 占位符注入颜色，避免依赖 SVG 的 currentColor 解析差异。
  static String _wrap(String body) {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="__COLOR__" stroke-width="1.6" '
        'stroke-linecap="round" stroke-linejoin="round">$body</svg>';
  }

  /// 加密锁（应用主标识）
  static const String lock = '''
<rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/>
<path d="M7.5 10.5V7.5a4.5 4.5 0 0 1 9 0v3"/>
<circle cx="12" cy="15.5" r="1.5"/>
<path d="M12 17v1.5"/>
''';

  /// 新建/发布（加号圆环）
  static const String plusCircle = '''
<circle cx="12" cy="12" r="8"/>
<path d="M12 8.5v7M8.5 12h7"/>
''';

  /// 打开文件夹
  static const String folderOpen = '''
<path d="M4 7.5a1.5 1.5 0 0 1 1.5-1.5h4l2 2h7A1.5 1.5 0 0 1 20 9.5v7A1.5 1.5 0 0 1 18.5 18h-13A1.5 1.5 0 0 1 4 16.5z"/>
<path d="M4 10h16"/>
''';

  /// 上传文件
  static const String uploadFile = '''
<path d="M19 15v3a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-3"/>
<path d="M12 16V5"/>
<path d="M8.5 8.5 12 5l3.5 3.5"/>
''';

  /// 编辑/笔记
  static const String editNote = '''
<path d="M5 19h14"/>
<path d="M5 5h14a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/>
<path d="M7 9h10M7 11h6"/>
''';

  /// 返回箭头
  static const String arrowBack = '''
<path d="M15 6l-6 6 6 6"/>
''';

  /// 发布/上传（纸飞机）
  static const String publish = '''
<path d="M21 3L10.5 13.5"/>
<path d="M21 3l-6.5 18-4-7.5L3 10z"/>
''';

  /// 预览/眼睛
  static const String eye = '''
<path d="M2.5 12s3.5-6.5 9.5-6.5S21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>
<circle cx="12" cy="12" r="2.8"/>
''';

  /// 密码/钥匙
  static const String password = '''
<circle cx="8" cy="15" r="3.5"/>
<path d="M10.5 12.5 19 4"/>
<path d="M16 7l2 2"/>
<path d="M18 5l2 2"/>
''';

  /// 帮助/问号
  static const String help = '''
<circle cx="12" cy="12" r="9"/>
<path d="M9.5 9.5a2.5 2.5 0 0 1 5 0c0 2.5-2.5 2-2.5 4"/>
<circle cx="12" cy="17" r="0.6" fill="__COLOR__"/>
''';

  /// 拖拽上传/云上传
  static const String cloudUpload = '''
<path d="M7 18a4.5 4.5 0 0 1-1-8.9 6 6 0 0 1 11.5 1.2A4 4 0 0 1 16.5 18"/>
<path d="M12 13v8"/>
<path d="M9 16l3-3 3 3"/>
''';

  /// 文件下载
  static const String fileDownload = '''
<path d="M19 13v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-5"/>
<path d="M12 16V4"/>
<path d="M8.5 12.5 12 16l3.5-3.5"/>
''';

  /// 相册/图片
  static const String image = '''
<rect x="4" y="4" width="16" height="16" rx="2"/>
<circle cx="9" cy="9" r="1.6"/>
<path d="M4 16l4.5-4.5 4 4L16 12l4 4"/>
''';

  /// 关闭/取消（X）
  static const String close = '''
<path d="M6 6l12 12M18 6L6 18"/>
''';

  /// 复制
  static const String copy = '''
<rect x="8" y="8" width="12" height="12" rx="2"/>
<path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>
''';

  /// 删除/垃圾桶
  static const String trash = '''
<path d="M4 7h16"/>
<path d="M9 7V5a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 5v2"/>
<path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12"/>
<path d="M10 11v6M14 11v6"/>
''';

  /// 保存/磁盘
  static const String save = '''
<path d="M5 5h11l3 3v11a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/>
<path d="M8 5v5h7V5"/>
<path d="M8 14h8v6H8z"/>
''';

  /// 警告/三角感叹
  static const String warning = '''
<path d="M12 4l9 16H3z"/>
<path d="M12 10v5"/>
<circle cx="12" cy="17.5" r="0.6" fill="__COLOR__"/>
''';

  /// 错误/圆圈X
  static const String error = '''
<circle cx="12" cy="12" r="9"/>
<path d="M9 9l6 6M15 9l-6 6"/>
''';

  /// 成功/勾选
  static const String check = '''
<circle cx="12" cy="12" r="9"/>
<path d="M8.5 12.5l2.5 2.5 4.5-5"/>
''';

  /// 信息/i
  static const String info = '''
<circle cx="12" cy="12" r="9"/>
<path d="M12 11v5"/>
<circle cx="12" cy="8" r="0.6" fill="__COLOR__"/>
''';

  /// 设置/齿轮
  static const String settings = '''
<circle cx="12" cy="12" r="3"/>
<path d="M12 2.5v3M12 18.5v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2.5 12h3M18.5 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>
''';

  /// 主题/月亮
  static const String moon = '''
<path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/>
''';

  /// 语言/地球
  static const String globe = '''
<circle cx="12" cy="12" r="9"/>
<path d="M3 12h18"/>
<path d="M12 3a14 14 0 0 1 0 18 14 14 0 0 1 0-18z"/>
''';

  /// 文档/文件
  static const String document = '''
<path d="M6 3h8l4 4v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/>
<path d="M14 3v4h4"/>
<path d="M8 13h8M8 16h8M8 10h4"/>
''';

  /// 搜索
  static const String search = '''
<circle cx="11" cy="11" r="6"/>
<path d="M15.5 15.5 20 20"/>
''';

  /// 添加（小加号）
  static const String add = '''
<path d="M12 5v14M5 12h14"/>
''';

  /// 隐藏/眼睛关闭
  static const String eyeOff = '''
<path d="M4 4l16 16"/>
<path d="M9.5 9.5a2.8 2.8 0 0 0 4 4"/>
<path d="M6.5 6.5C4 8 2.5 12 2.5 12s3.5 6.5 9.5 6.5c1.8 0 3.4-.5 4.8-1.2"/>
<path d="M19.5 14.5C21 13 21.5 12 21.5 12S18 5.5 12 5.5c-.5 0-1 0-1.5.1"/>
''';

  /// 视频
  static const String video = '''
<rect x="3" y="6" width="13" height="12" rx="2"/>
<path d="M16 10l5-3v10l-5-3z"/>
''';

  /// 音频
  static const String audio = '''
<path d="M9 18V7l10-2v11"/>
<circle cx="6" cy="18" r="2.5"/>
<circle cx="16" cy="16" r="2.5"/>
''';

  /// 图片（图）
  static const String picture = '''
<rect x="4" y="5" width="16" height="14" rx="2"/>
<circle cx="9" cy="10" r="1.6"/>
<path d="M4 17l5-5 4 4 3-3 4 4"/>
''';

  /// 粘贴/剪贴板
  static const String clipboard = '''
<rect x="5" y="5" width="14" height="16" rx="2"/>
<path d="M9 5V3.5A1.5 1.5 0 0 1 10.5 2h3A1.5 1.5 0 0 1 15 3.5V5"/>
<path d="M9 11h6M9 14h6M9 17h3"/>
''';

  /// 解密/解锁
  static const String unlock = '''
<rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/>
<path d="M7.5 10.5V7.5a4.5 4.5 0 0 1 8.5-2"/>
<circle cx="12" cy="15.5" r="1.5"/>
<path d="M12 17v1.5"/>
''';

  /// 刷新/重试
  static const String refresh = '''
<path d="M4 12a8 8 0 0 1 13.5-5.5L20 8"/>
<path d="M20 4v4h-4"/>
<path d="M20 12a8 8 0 0 1-13.5 5.5L4 16"/>
<path d="M4 20v-4h4"/>
''';

  /// 用户/人物
  static const String person = '''
<circle cx="12" cy="8" r="4"/>
<path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>
''';

  /// 日历
  static const String calendar = '''
<rect x="4" y="5" width="16" height="16" rx="2"/>
<path d="M4 9h16"/>
<path d="M8 3v4M16 3v4"/>
''';

  /// 保存到设备/下载
  static const String saveAlt = '''
<path d="M19 13v5a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-5"/>
<path d="M12 16V4"/>
<path d="M8.5 12.5 12 16l3.5-3.5"/>
''';

  /// 获取完整 SVG 字符串（已注入颜色）
  static String svg(String iconBody, Color color) {
    // Flutter 3.27+ 使用 .r/.g/.b/.a 浮点分量
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final a = (color.a * 255.0).round().clamp(0, 255);
    final hex = '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        '${a.toRadixString(16).padLeft(2, '0')}';
    return _wrap(iconBody).replaceAll('__COLOR__', hex);
  }
}

/// 软质风格图标 Widget
///
/// 基于 SVG 渲染线性细描边图标，颜色随主题自适应。
///
/// 用法：
/// ```dart
/// NeumorphicIcon(StrawIcons.lock, size: 24)
/// ```
class NeumorphicIcon extends StatelessWidget {
  const NeumorphicIcon(
    this.iconBody, {
    super.key,
    this.size = 24,
    this.color,
  });

  /// 图标 SVG body（来自 [StrawIcons]）
  final String iconBody;

  /// 图标尺寸（宽高相同）
  final double size;

  /// 图标颜色；为 null 时取主题 inkSecondary
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        NeumorphicTokens.ofContext(context).inkSecondary;
    return SvgPicture.string(
      StrawIcons.svg(iconBody, resolvedColor),
      width: size,
      height: size,
    );
  }
}
