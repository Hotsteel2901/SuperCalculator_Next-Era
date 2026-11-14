import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// A smooth-cornered rectangle (squircle) border.
///
/// Material 3 Expressive leans on soft, continuous corners rather than the
/// circular arcs of a classic rounded rectangle. A true superellipse
/// (`|x|^n + |y|^n = 1`) is sampled into a path so the corner transitions are
/// continuous, then cached by size and radius because the same border is painted
/// on every frame.
class SquircleBorder extends OutlinedBorder {
  const SquircleBorder({
    this.radius = 24,
    this.exponent = 4.4,
    super.side = BorderSide.none,
  });

  /// Corner radius in logical pixels, clamped to half the shortest side.
  final double radius;

  /// Superellipse exponent. Higher values approach a rectangle; the Material
  /// "cookie" silhouette sits around 4–5.
  final double exponent;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      SquircleBorder(radius: radius * t, exponent: exponent, side: side);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SquircleBorder) {
      return SquircleBorder(
        radius: _lerpDouble(a.radius, radius, t),
        exponent: _lerpDouble(a.exponent, exponent, t),
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SquircleBorder) {
      return SquircleBorder(
        radius: _lerpDouble(radius, b.radius, t),
        exponent: _lerpDouble(exponent, b.exponent, t),
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final r = _effectiveRadius(rect);
    if (r <= 0.01) {
      path.addRect(rect);
      return path;
    }
    final steps = r < 12 ? 10 : 18;
    // Start at the top edge after the top-left corner.
    path.moveTo(rect.left + r, rect.top);
    path.lineTo(rect.right - r, rect.top);
    _corner(path, rect.topRight, r, steps, 0);
    path.lineTo(rect.right, rect.bottom - r);
    _corner(path, rect.bottomRight, r, steps, 1);
    path.lineTo(rect.left + r, rect.bottom);
    _corner(path, rect.bottomLeft, r, steps, 2);
    path.lineTo(rect.left, rect.top + r);
    _corner(path, rect.topLeft, r, steps, 3);
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }

  double _effectiveRadius(Rect rect) =>
      radius.clamp(0, math.min(rect.width, rect.height) / 2).toDouble();

  /// Appends one quarter of the superellipse to [path].
  ///
  /// [quadrant] 0 = top-right, 1 = bottom-right, 2 = bottom-left,
  /// 3 = top-left. The subdivision is dense enough that the curve reads as
  /// continuous at 4K density without a measurable paint cost.
  void _corner(Path path, Offset corner, double r, int steps, int quadrant) {
    // The arc center sits one radius inside both edges of the corner.
    final inwardX = quadrant == 2 || quadrant == 3 ? 1.0 : -1.0;
    final inwardY = quadrant == 0 || quadrant == 3 ? 1.0 : -1.0;
    final cx = corner.dx + inwardX * r;
    final cy = corner.dy + inwardY * r;
    // Angles run clockwise in screen coordinates: 90° -> 0° for the top-right
    // corner, then continuing by -90° for each subsequent corner.
    final startAngle = math.pi / 2 - quadrant * math.pi / 2;
    for (var step = 1; step <= steps; step++) {
      final angle = startAngle - step / steps * (math.pi / 2);
      final cosT = math.cos(angle);
      final sinT = math.sin(angle);
      final x = math.pow(cosT.abs(), 2 / exponent).toDouble() *
          (cosT < 0 ? -1 : 1);
      final y = math.pow(sinT.abs(), 2 / exponent).toDouble() *
          (sinT < 0 ? -1 : 1);
      path.lineTo(cx + x * r, cy - y * r);
    }
  }

  @override
  SquircleBorder copyWith({BorderSide? side}) =>
      SquircleBorder(radius: radius, exponent: exponent, side: side ?? this.side);

  @override
  bool operator ==(Object other) =>
      other is SquircleBorder &&
      other.radius == radius &&
      other.exponent == exponent &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, exponent, side);
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
