import 'package:flutter/material.dart';

/// Neumorphism 设计令牌（水墨风）
///
/// 集中定义颜色、阴影、圆角、间距等设计常量，供所有软质组件复用。
/// 通过 [NeumorphicTheme.of] 获取当前亮/暗模式下的令牌。
///
/// 设计原则：
/// - 元素与背景同色，靠双向阴影定义体积
/// - 全局光源左上角（亮阴影在左上，暗阴影在右下）
/// - 强调色采用水墨黑系，低饱和、安静
/// - 暗色模式阴影色反转
class NeumorphicTokens {
  const NeumorphicTokens({
    required this.brightness,
    required this.surface,
    required this.surfaceAlt,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkWash,
    required this.success,
    required this.warning,
    required this.error,
    required this.lightShadow,
    required this.darkShadow,
    required this.shadowOffset,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusXLarge,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
  });

  final Brightness brightness;

  // ============ 背景与表面 ============
  /// 主背景基色（元素与之同色形成 Neumorphism 效果）
  final Color surface;

  /// 表面微差色（凹陷态/分隔提示，仅比 surface 深一点点）
  final Color surfaceAlt;

  /// 分隔线色（比 surfaceAlt 更重，用于 Divider 等需要明确分界的场景）
  final Color divider;

  // ============ 文字 ============
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  // ============ 强调色（水墨风） ============
  /// 浓墨：用于主 CTA、激活态、关键图标
  final Color inkPrimary;

  /// 淡墨：用于次级强调、hover 边描
  final Color inkSecondary;

  /// 水墨晕染：用于进度条、选中态背景
  final Color inkWash;

  // ============ 语义色（低饱和，符合安静氛围） ============
  final Color success;
  final Color warning;
  final Color error;

  // ============ 阴影 ============
  /// 亮阴影色（光源色，左上方向）
  final Color lightShadow;

  /// 暗阴影色（背光色，右下方向）
  final Color darkShadow;

  /// 阴影偏移量（亮阴影取负值即左上，暗阴影取正值即右下）
  final double shadowOffset;

  /// 阴影模糊半径
  final double shadowBlur;

  /// 阴影扩散
  final double shadowSpread;

  // ============ 圆角 ============
  final double radiusSmall;   // 8
  final double radiusMedium;  // 12
  final double radiusLarge;   // 16
  final double radiusXLarge;  // 24

  // ============ 间距 ============
  final double spaceXs;  // 4
  final double spaceSm;  // 8
  final double spaceMd;  // 16
  final double spaceLg;  // 24
  final double spaceXl;  // 32
  final double spaceXxl; // 48

  /// 亮色模式令牌
  ///
  /// 背景 #E8E8E8 中性浅灰，与水墨黑形成柔和对比。
  /// 阴影：亮=近白，暗=中灰，光源左上。
  static const NeumorphicTokens light = NeumorphicTokens(
    brightness: Brightness.light,
    surface: Color(0xFFE8E8E8),
    surfaceAlt: Color(0xFFDCDCDC),
    divider: Color(0xFFBEBEBE),
    textPrimary: Color(0xFF2A2A2A),
    textSecondary: Color(0xFF5C5C5C),
    textHint: Color(0xFF9A9A9A),
    inkPrimary: Color(0xFF1C1C1E),
    inkSecondary: Color(0xFF3A3A3C),
    inkWash: Color(0xFF6A6A6C),
    success: Color(0xFF4A7C59),
    warning: Color(0xFFB8860B),
    error: Color(0xFFA04040),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFBEBEBE),
    shadowOffset: 4,
    shadowBlur: 8,
    shadowSpread: 0,
    radiusSmall: 8,
    radiusMedium: 12,
    radiusLarge: 16,
    radiusXLarge: 24,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 16,
    spaceLg: 24,
    spaceXl: 32,
    spaceXxl: 48,
  );

  /// 暗色模式令牌
  ///
  /// 背景 #2C2C2C 中性深灰，阴影色反转。
  /// 水墨黑在暗色下需提亮为浅墨以保证可读性。
  static const NeumorphicTokens dark = NeumorphicTokens(
    brightness: Brightness.dark,
    surface: Color(0xFF2C2C2C),
    surfaceAlt: Color(0xFF333333),
    divider: Color(0xFF4A4A4A),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFFB0B0B0),
    textHint: Color(0xFF7A7A7A),
    inkPrimary: Color(0xFFE8E8E8),   // 暗色下墨色反转，"浓墨"变为高亮
    inkSecondary: Color(0xFFC0C0C0),
    inkWash: Color(0xFF8A8A8A),
    success: Color(0xFF6FA67E),
    warning: Color(0xFFD4A04A),
    error: Color(0xFFC86060),
    lightShadow: Color(0xFF3A3A3A),  // 暗色下"亮阴影"为稍亮的灰
    darkShadow: Color(0xFF1A1A1A),  // 暗色下"暗阴影"为更深的黑
    shadowOffset: 4,
    shadowBlur: 8,
    shadowSpread: 0,
    radiusSmall: 8,
    radiusMedium: 12,
    radiusLarge: 16,
    radiusXLarge: 24,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 16,
    spaceLg: 24,
    spaceXl: 32,
    spaceXxl: 48,
  );

  /// 根据亮度获取对应令牌
  static NeumorphicTokens of(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// 根据 BuildContext 获取当前主题令牌
  static NeumorphicTokens ofContext(BuildContext context) {
    return of(Theme.of(context).brightness);
  }
}

/// 软质容器形态
enum NeumorphicShape {
  /// 凸起（默认）：双向外阴影
  convex,

  /// 凹陷（按下态/输入框）：反向阴影模拟内壁
  concave,

  /// 平整：仅背景色，无阴影
  flat,
}

/// 阴影强度（用于 hover/pressed 等状态微调）
enum NeumorphicIntensity {
  /// 标准
  normal,

  /// 加深（hover）
  strong,

  /// 减弱（移动端小屏，避免显脏）
  subtle,
}

/// 根据令牌与形态构建 BoxDecoration
///
/// 凸起：亮阴影左上 + 暗阴影右下（外阴影）
/// 凹陷：暗阴影左上 + 亮阴影右下（反向，模拟内壁暗影）
/// 平整：无阴影
///
/// 注意：Flutter 的 BoxShadow 不支持真正的 inset，
/// 凹陷态采用"四向外阴影 + 背景色加深"的成熟模拟方案，
/// 四向偏移确保四边均有阴影定义，避免两侧与背景相融，
/// 视觉效果接近 inset 且稳定无渲染问题。
List<BoxShadow> buildNeumorphicShadows({
  required NeumorphicTokens tokens,
  required NeumorphicShape shape,
  NeumorphicIntensity intensity = NeumorphicIntensity.normal,
}) {
  if (shape == NeumorphicShape.flat) {
    return const [];
  }

  // 根据强度调整阴影参数
  double offset = tokens.shadowOffset;
  double blur = tokens.shadowBlur;
  switch (intensity) {
    case NeumorphicIntensity.strong:
      offset = tokens.shadowOffset * 1.3;
      blur = tokens.shadowBlur * 1.4;
    case NeumorphicIntensity.subtle:
      offset = tokens.shadowOffset * 0.6;
      blur = tokens.shadowBlur * 0.7;
    case NeumorphicIntensity.normal:
      break;
  }

  final lightOffset = Offset(-offset, -offset);
  final darkOffset = Offset(offset, offset);

  if (shape == NeumorphicShape.convex) {
    // 凸起：四向阴影，亮在左上，暗在右下
    // 对角线阴影提供立体感，轴向阴影补强四边边界
    return [
      // 对角线：亮（左上）
      BoxShadow(
        color: tokens.lightShadow,
        offset: lightOffset,
        blurRadius: blur,
        spreadRadius: tokens.shadowSpread,
      ),
      // 对角线：暗（右下）
      BoxShadow(
        color: tokens.darkShadow,
        offset: darkOffset,
        blurRadius: blur,
        spreadRadius: tokens.shadowSpread,
      ),
      // 轴向补强：上边亮影
      BoxShadow(
        color: tokens.lightShadow,
        offset: Offset(0, -offset * 0.5),
        blurRadius: blur * 0.7,
        spreadRadius: tokens.shadowSpread,
      ),
      // 轴向补强：左边亮影
      BoxShadow(
        color: tokens.lightShadow,
        offset: Offset(-offset * 0.5, 0),
        blurRadius: blur * 0.7,
        spreadRadius: tokens.shadowSpread,
      ),
      // 轴向补强：下边暗影
      BoxShadow(
        color: tokens.darkShadow,
        offset: Offset(0, offset * 0.5),
        blurRadius: blur * 0.7,
        spreadRadius: tokens.shadowSpread,
      ),
      // 轴向补强：右边暗影
      BoxShadow(
        color: tokens.darkShadow,
        offset: Offset(offset * 0.5, 0),
        blurRadius: blur * 0.7,
        spreadRadius: tokens.shadowSpread,
      ),
    ];
  }

  // 凹陷：四向阴影模拟内壁，暗在左上，亮在右下
  // 对角线阴影提供凹陷立体感，轴向阴影补强确保两侧边界清晰
  return [
    // 对角线：暗（左上）
    BoxShadow(
      color: tokens.darkShadow,
      offset: lightOffset,
      blurRadius: blur * 0.8,
      spreadRadius: tokens.shadowSpread,
    ),
    // 对角线：亮（右下）
    BoxShadow(
      color: tokens.lightShadow,
      offset: darkOffset,
      blurRadius: blur * 0.8,
      spreadRadius: tokens.shadowSpread,
    ),
    // 轴向补强：上边暗影（背光面）
    BoxShadow(
      color: tokens.darkShadow,
      offset: Offset(0, -offset * 0.5),
      blurRadius: blur * 0.6,
      spreadRadius: tokens.shadowSpread,
    ),
    // 轴向补强：左边暗影（背光面）
    BoxShadow(
      color: tokens.darkShadow,
      offset: Offset(-offset * 0.5, 0),
      blurRadius: blur * 0.6,
      spreadRadius: tokens.shadowSpread,
    ),
    // 轴向补强：下边亮影（受光面）
    BoxShadow(
      color: tokens.lightShadow,
      offset: Offset(0, offset * 0.5),
      blurRadius: blur * 0.6,
      spreadRadius: tokens.shadowSpread,
    ),
    // 轴向补强：右边亮影（受光面）
    BoxShadow(
      color: tokens.lightShadow,
      offset: Offset(offset * 0.5, 0),
      blurRadius: blur * 0.6,
      spreadRadius: tokens.shadowSpread,
    ),
  ];
}
