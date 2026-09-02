import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// The one card surface of the minimal-premium design: flat, a hairline
/// border for definition, and a single barely-there shadow — no glow, no
/// gradient sheen, no tinted lift. Depth comes from spacing and typography,
/// not from decorating every card. A tap still gets a small scale "squish"
/// (via [onTap]) so interaction feels acknowledged without adding visual
/// noise to the surface itself.
///
/// Pass [color] for a tinted tile (e.g. a macro card); the border adapts
/// to the active light/dark palette either way.
class AppCard extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool bordered;

  const AppCard({
    super.key,
    this.child,
    this.color,
    this.borderRadius = Dimens.radiusL,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final radius = BorderRadius.circular(borderRadius);
    final tile = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
        border: bordered
            ? Border.all(color: palette.border, width: Dimens.hairline)
            : null,
        boxShadow: [
          BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return tile;
    return _PressableCard(radius: radius, onTap: onTap!, child: tile);
  }
}

/// Adds a small tap-down scale (0.97x) to whatever card it wraps, on top of
/// the usual ink ripple — the tactile "squish" that makes a tap feel
/// acknowledged rather than just clicked. Kept even in the flat/minimal
/// treatment: this is an interaction cue, not a decorative one.
class _PressableCard extends StatefulWidget {
  const _PressableCard({
    required this.child,
    required this.radius,
    required this.onTap,
  });
  final Widget child;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _setPressed(true),
    onTapCancel: () => _setPressed(false),
    onTapUp: (_) => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.radius,
        child: InkWell(
          borderRadius: widget.radius,
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    ),
  );
}
