import 'package:flutter/material.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';

/// Neumorphism 软质容器
///
/// 通过双向阴影模拟凸起/凹陷体积感。元素表面色与背景同色，
/// 仅靠光影定义边界——这是 Neumorphism 的核心。
///
/// 形态说明：
/// - [NeumorphicShape.convex]（凸起）：亮阴影在左上，暗阴影在右下
/// - [NeumorphicShape.concave]（凹陷）：阴影方向反转，模拟内壁
/// - [NeumorphicShape.flat]（平整）：仅背景色，无阴影
///
/// 设计原则：
/// - 不使用边框（border），完全靠阴影定义边界
/// - 表面色与父级背景同色，确保"从背景挤压出来"的视觉
/// - 圆角统一，避免视觉碎片
///
/// 用法：
/// ```dart
/// NeumorphicContainer(
///   shape: NeumorphicShape.convex,
///   padding: EdgeInsets.all(16),
///   child: Text('软质卡片'),
/// )
/// ```
class NeumorphicContainer extends StatelessWidget {
  const NeumorphicContainer({
    super.key,
    required this.child,
    this.shape = NeumorphicShape.convex,
    this.intensity = NeumorphicIntensity.normal,
    this.borderRadius,
    this.radiusKey,
    this.padding,
    this.margin,
    this.color,
    this.alignment,
    this.width,
    this.height,
    this.constraints,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  }) : assert(
          radiusKey == null || borderRadius == null,
          '只能指定 borderRadius 或 radiusKey 之一',
        );

  /// 子内容
  final Widget child;

  /// 软质形态
  final NeumorphicShape shape;

  /// 阴影强度
  final NeumorphicIntensity intensity;

  /// 自定义圆角半径
  final double? borderRadius;

  /// 使用令牌中的圆角档位（small/medium/large/xLarge）
  ///
  /// 与 [borderRadius] 互斥。
  final _RadiusKey? radiusKey;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 自定义表面色（默认取令牌 surface）
  final Color? color;

  /// 子内容对齐
  final AlignmentGeometry? alignment;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 约束
  final BoxConstraints? constraints;

  /// 形态切换动画时长
  final Duration duration;

  /// 形态切换动画曲线
  final Curve curve;

  /// 使用 small 圆角（8）
  const NeumorphicContainer.small({
    super.key,
    required this.child,
    this.shape = NeumorphicShape.convex,
    this.intensity = NeumorphicIntensity.normal,
    this.padding,
    this.margin,
    this.color,
    this.alignment,
    this.width,
    this.height,
    this.constraints,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  })  : borderRadius = null,
        radiusKey = _RadiusKey.small;

  /// 使用 large 圆角（16）
  const NeumorphicContainer.large({
    super.key,
    required this.child,
    this.shape = NeumorphicShape.convex,
    this.intensity = NeumorphicIntensity.normal,
    this.padding,
    this.margin,
    this.color,
    this.alignment,
    this.width,
    this.height,
    this.constraints,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  })  : borderRadius = null,
        radiusKey = _RadiusKey.large;

  /// 使用 xLarge 圆角（24）
  const NeumorphicContainer.xLarge({
    super.key,
    required this.child,
    this.shape = NeumorphicShape.convex,
    this.intensity = NeumorphicIntensity.normal,
    this.padding,
    this.margin,
    this.color,
    this.alignment,
    this.width,
    this.height,
    this.constraints,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  })  : borderRadius = null,
        radiusKey = _RadiusKey.xLarge;

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    final radius = borderRadius ?? _resolveRadius(tokens, radiusKey);
    final surfaceColor = color ?? tokens.surface;

    // 凹陷态背景色稍深，增强"被按下"的视觉
    final effectiveColor = shape == NeumorphicShape.concave
        ? tokens.surfaceAlt
        : surfaceColor;

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: buildNeumorphicShadows(
          tokens: tokens,
          shape: shape,
          intensity: intensity,
        ),
      ),
      child: child,
    );
  }

  double _resolveRadius(NeumorphicTokens tokens, _RadiusKey? key) {
    switch (key) {
      case _RadiusKey.small:
        return tokens.radiusSmall;
      case _RadiusKey.medium:
        return tokens.radiusMedium;
      case _RadiusKey.large:
        return tokens.radiusLarge;
      case _RadiusKey.xLarge:
        return tokens.radiusXLarge;
      case null:
        return tokens.radiusMedium;
    }
  }
}

/// 圆角档位枚举（内部使用，避免暴露 API 复杂度）
enum _RadiusKey {
  small,
  medium,
  large,
  xLarge,
}

/// 凹陷式容器（输入框/拖拽区/选中态）
///
/// 等价于 [NeumorphicContainer] 的 [NeumorphicShape.concave] 形态，
/// 提供语义化构造器。
class NeumorphicInset extends NeumorphicContainer {
  NeumorphicInset({
    super.key,
    required super.child,
    NeumorphicIntensity intensity = NeumorphicIntensity.normal,
    super.borderRadius,
    super.padding,
    super.margin,
    super.color,
    super.alignment,
    super.width,
    super.height,
    super.constraints,
  }) : super(
          shape: NeumorphicShape.concave,
          intensity: intensity,
        );
}
