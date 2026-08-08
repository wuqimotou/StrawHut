import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 软质按钮
///
/// 默认凸起，按下时切换为凹陷态——这是 Neumorphism 的核心交互反馈：
/// 不靠变色，而靠体积翻转。
///
/// 按钮类型：
/// - [NeumorphicButtonStyle.primary]：水墨强调态，表面填充墨色，文字反白
/// - [NeumorphicButtonStyle.secondary]：标准软质态，表面同背景色
/// - [NeumorphicButtonStyle.flat]：平整无阴影，仅点击时凹陷
///
/// 平台适配：
/// - 桌面：hover 时阴影加深（intensity → strong）
/// - 移动：保持 subtle 强度，避免小屏阴影显脏；触摸目标 ≥48dp
///
/// 用法：
/// ```dart
/// NeumorphicButton(
///   label: '发布知识卡片',
///   icon: StrawIcons.plusCircle,
///   style: NeumorphicButtonStyle.primary,
///   onPressed: () => ...,
/// )
/// ```
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.style = NeumorphicButtonStyle.secondary,
    this.padding,
    this.minimumSize,
    this.expanded = false,
    this.iconSpacing = 8,
  }) : assert(
          label != null || icon != null,
          '至少需要 label 或 icon 之一',
        );

  /// 按钮文本
  final String? label;

  /// 图标 SVG body（来自 [StrawIcons]）
  final String? icon;

  /// 点击回调；为 null 时按钮禁用
  final VoidCallback? onPressed;

  /// 按钮样式
  final NeumorphicButtonStyle style;

  /// 自定义内边距
  final EdgeInsetsGeometry? padding;

  /// 最小尺寸（用于满足触摸目标）
  final Size? minimumSize;

  /// 是否撑满父级宽度
  final bool expanded;

  /// 图标与文字间距
  final double iconSpacing;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
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
    final isPrimary = widget.style == NeumorphicButtonStyle.primary;

    // 形态决策
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
      shape = widget.style == NeumorphicButtonStyle.flat
          ? NeumorphicShape.flat
          : NeumorphicShape.convex;
      intensity = _isMobile
          ? NeumorphicIntensity.subtle
          : NeumorphicIntensity.normal;
    }

    // 颜色决策
    final Color surfaceColor;
    final Color contentColor;
    if (isPrimary && !_isDisabled) {
      // 主按钮：墨色填充，文字反白
      surfaceColor = _isPressed ? tokens.inkSecondary : tokens.inkPrimary;
      contentColor = tokens.brightness == Brightness.dark
          ? tokens.surface
          : const Color(0xFFF5F5F5);
    } else if (_isDisabled) {
      surfaceColor = tokens.surface;
      contentColor = tokens.textHint;
    } else {
      surfaceColor = tokens.surface;
      contentColor = tokens.textPrimary;
    }

    // 默认内边距与最小尺寸
    final defaultPadding = widget.label != null && widget.icon != null
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
        : widget.label != null
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
            : const EdgeInsets.all(12);
    final padding = widget.padding ?? defaultPadding;
    final minSize = widget.minimumSize ??
        Size(_isMobile ? 48.0 : 40.0, _isMobile ? 48.0 : 40.0);

    // 内容
    var content = _buildContent(contentColor);

    // 包裹最小尺寸
    content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize.width,
        minHeight: minSize.height,
      ),
      child: Padding(
        padding: padding,
        child: content,
      ),
    );

    // 容器
    Widget button = NeumorphicContainer(
      shape: shape,
      intensity: intensity,
      color: surfaceColor,
      padding: EdgeInsets.zero,
      child: content,
    );

    // expanded
    if (widget.expanded) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // 交互
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

  Widget _buildContent(Color color) {
    // 响应式字号：窄屏（< 500）缩小，确保中文按钮文字不溢出容器
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 500
        ? 13.0
        : screenWidth < 800
            ? 14.0
            : 15.0;

    if (widget.label != null && widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NeumorphicIcon(widget.icon!, size: 18, color: color),
          SizedBox(width: widget.iconSpacing),
          // Flexible + FittedBox 兜底：文字超长时自动等比缩小，永不溢出
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label!,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (widget.label != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.label!,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return NeumorphicIcon(widget.icon!, size: 20, color: color);
  }
}

/// 按钮样式枚举
enum NeumorphicButtonStyle {
  /// 主按钮：墨色填充，反白文字
  primary,

  /// 次按钮：软质凸起，同背景色
  secondary,

  /// 平整：无阴影，点击时凹陷
  flat,
}

/// 圆形软质图标按钮
///
/// 用于 AppBar 操作、工具栏等场景。
/// 默认凸起，按下凹陷。
///
/// 用法：
/// ```dart
/// NeumorphicIconButton(
///   icon: StrawIcons.help,
///   onPressed: () => ...,
/// )
/// ```
class NeumorphicIconButton extends StatefulWidget {
  const NeumorphicIconButton({
    required this.icon, super.key,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.tooltip,
    this.color,
    this.circular = false,
  });

  /// 图标 SVG body
  final String icon;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 按钮整体尺寸（圆形直径）
  final double size;

  /// 图标尺寸
  final double iconSize;

  /// 长按提示
  final String? tooltip;

  /// 自定义图标颜色
  final Color? color;

  /// 是否使用圆形形状（默认 false，使用圆角矩形）
  final bool circular;

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton> {
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
    final iconColor = widget.color ?? tokens.textPrimary;

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

    final effectiveIconColor =
        _isDisabled ? tokens.textHint : iconColor;

    Widget button = SizedBox(
      width: widget.size,
      height: widget.size,
      child: NeumorphicContainer(
        shape: shape,
        intensity: intensity,
        borderRadius: widget.circular ? widget.size / 2 : tokens.radiusMedium,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        child: NeumorphicIcon(
          widget.icon,
          size: widget.iconSize,
          color: effectiveIconColor,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip,
        child: button,
      );
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
