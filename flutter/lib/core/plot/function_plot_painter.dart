import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../settings/app_settings.dart';
import 'marching_squares.dart';
import 'plot_point.dart';
import 'plot_viewport.dart';

/// Paints function, multi-curve, parametric, polar, contour and 3D plots.
///
/// Key behaviours:
///  * curves are drawn as one continuous path across the whole sampled domain,
///    and asymptotes are extended to the plot edge instead of leaving a gap;
///  * implicit plots use marching squares, so the rendered shape is a line, not
///    a cloud of dots;
///  * 3D surfaces are filled, depth-sorted quads rather than points;
///  * steady-state painting avoids `Path.computeMetrics`; metrics are only used
///    for the short draw-in animation.
class FunctionPlotPainter extends CustomPainter {
  FunctionPlotPainter({
    required this.points,
    required this.scheme,
    this.mode = 'function',
    this.intersectionPoints = const <PlotPoint>[],
    this.markedPoints = const <PlotPoint>[],
    this.viewport = PlotViewport.initial,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.yaw = -.65,
    this.pitch = .55,
    this.strokeWidth = 2.4,
    this.showGrid = true,
    this.showTickLabels = true,
    this.background = PlotBackgroundStyle.surface,
    this.contours = const <ContourLevel>[],
    this.progress = 1,
    this.palette,
  });

  final List<PlotPoint> points;
  final ColorScheme scheme;
  final String mode;
  final List<PlotPoint> intersectionPoints;
  final List<PlotPoint> markedPoints;
  final PlotViewport viewport;

  /// Camera scale and translation are used only by the 3D surface projection.
  final double zoom;
  final Offset pan;
  final double yaw;
  final double pitch;

  /// Curve stroke width in logical pixels.
  final double strokeWidth;

  /// Whether the coordinate grid is painted.
  final bool showGrid;

  /// Whether numeric tick labels are painted.
  final bool showTickLabels;

  /// Background treatment.
  final PlotBackgroundStyle background;

  /// Pre-computed iso-lines for implicit and contour modes.
  final List<ContourLevel> contours;

  /// Draw-in progress in the range 0..1. `1` paints the complete curve.
  final double progress;

  /// Optional plot palette; falls back to a scheme-derived one.
  final List<Color>? palette;

  static _PathCache? _cache;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    if (size.width <= 1 || size.height <= 1) return;
    if (mode == 'surface') {
      _drawSurface(canvas, size);
      return;
    }
    _draw2d(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final color = switch (background) {
      PlotBackgroundStyle.surface => scheme.surface,
      PlotBackgroundStyle.container => scheme.surfaceContainerLow,
      PlotBackgroundStyle.contrast => scheme.surfaceContainerLowest,
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  List<Color> get _palette =>
      palette ??
      <Color>[
        scheme.primary,
        scheme.tertiary,
        scheme.secondary,
        scheme.error,
        scheme.primaryFixedDim,
        scheme.tertiaryFixedDim,
      ];

  void _draw2d(Canvas canvas, Size size) {
    final plotRect = PlotLayout.plotRectFor(size);
    final visible = viewport.isValid ? viewport : PlotViewport.initial;
    _drawGrid(canvas, size, plotRect, visible);

    canvas.save();
    canvas.clipRect(plotRect);

    if (contours.isNotEmpty) {
      _drawContours(canvas, plotRect, visible);
      _drawMarkers(canvas, plotRect, visible);
      canvas.restore();
      return;
    }

    final finite = points
        .where((point) => point.isFinite)
        .toList(growable: false);
    if (finite.isEmpty) {
      _drawMarkers(canvas, plotRect, visible);
      canvas.restore();
      return;
    }

    if (mode == 'direction' || mode == 'vector') {
      _drawField(canvas, plotRect, visible);
      _drawMarkers(canvas, plotRect, visible);
      canvas.restore();
      return;
    }

    final cache = _pathFor(size, visible, plotRect);
    final colors = _palette;
    for (var index = 0; index < cache.paths.length; index++) {
      final entry = cache.paths[index];
      final path = entry.path;
      final color = colors[entry.curveIndex % colors.length];
      final glow = Paint()
        ..color = color.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final drawable = _withProgress(path, progress);
      canvas.drawPath(drawable, glow);
      canvas.drawPath(drawable, stroke);
    }

    _drawMarkers(canvas, plotRect, visible);
    canvas.restore();
  }

  /// Returns the cached path set, rebuilding only when the inputs that affect
  /// geometry change. Gesture repaints reuse the previous path.
  _PathCache _pathFor(Size size, PlotViewport viewport, Rect plotRect) {
    final key = _PathCacheKey(
      identity: identityHashCode(points),
      length: points.length,
      width: size.width,
      height: size.height,
      viewport: viewport,
      mode: mode,
    );
    final cached = _cache;
    if (cached != null && cached.key == key) return cached;
    final paths = _buildPaths(plotRect, viewport);
    final fresh = _PathCache(key, paths);
    _cache = fresh;
    return fresh;
  }

  List<_CurvePath> _buildPaths(Rect plotRect, PlotViewport visible) {
    final paths = <_CurvePath>[];
    var current = Path();
    var currentPoints = 0;
    Offset? previousScreen;
    PlotPoint? previousData;
    var hasCurrent = false;
    var curveIndex = 0;

    void flush() {
      if (hasCurrent && currentPoints > 1) {
        paths.add(_CurvePath(current, curveIndex));
      }
      current = Path();
      currentPoints = 0;
      hasCurrent = false;
      previousScreen = null;
      previousData = null;
    }

    for (final point in points) {
      if (point.x == double.infinity) {
        flush();
        curveIndex++;
        continue;
      }
      if (!point.isFinite) {
        flush();
        continue;
      }
      var screen = visible.dataToScreen(point, plotRect);
      // Guard against huge off-screen coordinates on steep exponentials.
      screen = Offset(
        screen.dx.clamp(-4e4, 4e4).toDouble(),
        screen.dy.clamp(-4e4, 4e4).toDouble(),
      );
      if (!hasCurrent) {
        current.moveTo(screen.dx, screen.dy);
        hasCurrent = true;
        currentPoints = 1;
        previousScreen = screen;
        previousData = point;
        continue;
      }
      final previous = previousScreen!;
      final delta = screen - previous;
      if (delta.distanceSquared < 0.16) {
        previousScreen = screen;
        previousData = point;
        continue;
      }
      final jump = delta.dy.abs();
      final lastData = previousData;
      final asymptote =
          jump > plotRect.height * 0.9 &&
          lastData != null &&
          (point.y - lastData.y).abs() > visible.ySpan * 0.6;
      if (asymptote) {
        final exit = _clipToRect(previous, screen, plotRect);
        if (exit != null) {
          current.lineTo(exit.dx, exit.dy);
          currentPoints++;
        }
        flush();
        final entry = _clipToRect(screen, previous, plotRect);
        current.moveTo(screen.dx, screen.dy);
        hasCurrent = true;
        currentPoints = 1;
        if (entry != null && (entry - screen).distance > 0.5) {
          current.moveTo(entry.dx, entry.dy);
          current.lineTo(screen.dx, screen.dy);
          currentPoints = 2;
        }
      } else {
        current.lineTo(screen.dx, screen.dy);
        currentPoints++;
      }
      previousScreen = screen;
      previousData = point;
    }
    flush();
    return paths;
  }

  /// Liang–Barsky clip of segment [from]→[to] against [rect], returning the
  /// first boundary crossing at or after [from].
  Offset? _clipToRect(Offset from, Offset to, Rect rect) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    if (dx == 0 && dy == 0) return null;
    var t0 = 0.0;
    var t1 = 1.0;
    double p;
    double q;
    bool clip(double pValue, double qValue) {
      if (pValue == 0) return qValue >= 0;
      final r = qValue / pValue;
      if (pValue < 0) {
        if (r > t1) return false;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return false;
        if (r < t1) t1 = r;
      }
      return true;
    }

    p = -dx;
    q = from.dx - rect.left;
    if (!clip(p, q)) return null;
    p = dx;
    q = rect.right - from.dx;
    if (!clip(p, q)) return null;
    p = -dy;
    q = from.dy - rect.top;
    if (!clip(p, q)) return null;
    p = dy;
    q = rect.bottom - from.dy;
    if (!clip(p, q)) return null;
    if (t1 < 0 || t0 > 1) return null;
    final t = t0.clamp(0.0, 1.0).toDouble();
    if (t == 0) return null;
    return Offset(from.dx + dx * t, from.dy + dy * t);
  }

  Path _withProgress(Path path, double progress) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    if (value >= 0.999) return path;
    if (value <= 0.001) return Path();
    final result = Path();
    for (final metric in path.computeMetrics()) {
      result.addPath(metric.extractPath(0, metric.length * value), Offset.zero);
    }
    return result;
  }

  void _drawContours(Canvas canvas, Rect plotRect, PlotViewport visible) {
    // Implicit mode usually has a single zero level; contour mode has several.
    final multiple = contours.length > 1;
    for (final level in contours) {
      final base = multiple
          ? Color.lerp(scheme.primary, scheme.tertiary, level.normalized)!
          : scheme.primary;
      final paint = Paint()
        ..color = base.withValues(alpha: multiple ? 0.82 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * (multiple ? 0.75 : 1)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var hasPoint = false;
      for (final point in level.points) {
        if (!point.isFinite) {
          hasPoint = false;
          continue;
        }
        final mapped = visible.dataToScreen(point, plotRect);
        if (!hasPoint) {
          path.moveTo(mapped.dx, mapped.dy);
          hasPoint = true;
        } else {
          path.lineTo(mapped.dx, mapped.dy);
        }
      }
      canvas.drawPath(_withProgress(path, progress), paint);
    }
  }

  void _drawField(Canvas canvas, Rect plotRect, PlotViewport visible) {
    final finite = points
        .where((point) => point.isFinite)
        .toList(growable: false);
    if (finite.isEmpty) return;
    final paint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, strokeWidth * 0.65)
      ..strokeCap = StrokeCap.round;
    final arrowHead = Paint()
      ..color = scheme.primary.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    for (var index = 0; index + 1 < finite.length; index += 3) {
      final start = finite[index];
      final end = finite[index + 1];
      final a = visible.dataToScreen(start, plotRect);
      var b = visible.dataToScreen(end, plotRect);
      final delta = b - a;
      if (delta.distanceSquared < 4) continue;
      // Clamp arrow length so a stiff field does not paint across the canvas.
      const maxLength = 26.0;
      if (delta.distance > maxLength) {
        b = a + delta / delta.distance * maxLength;
      }
      canvas.drawLine(a, b, paint);
      final direction = (b - a) / (b - a).distance;
      final normal = Offset(-direction.dy, direction.dx);
      final tip = b;
      final left = tip - direction * 6 + normal * 3;
      final right = tip - direction * 6 - normal * 3;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        arrowHead,
      );
    }
  }

  void _drawMarkers(Canvas canvas, Rect plotRect, PlotViewport visible) {
    final intersectionOuter = Paint()
      ..color = scheme.tertiary
      ..style = PaintingStyle.fill;
    final intersectionInner = Paint()
      ..color = scheme.onTertiary
      ..style = PaintingStyle.fill;
    for (final point in intersectionPoints.where((point) => point.isFinite)) {
      final mapped = visible.dataToScreen(point, plotRect);
      canvas.drawCircle(mapped, 7, intersectionOuter);
      canvas.drawCircle(mapped, 3, intersectionInner);
    }

    final markedOuter = Paint()
      ..color = scheme.error
      ..style = PaintingStyle.fill;
    final markedInner = Paint()
      ..color = scheme.onError
      ..style = PaintingStyle.fill;
    for (final point in markedPoints.where((point) => point.isFinite)) {
      final mapped = visible.dataToScreen(point, plotRect);
      canvas.drawCircle(mapped, 6.5, markedOuter);
      canvas.drawCircle(mapped, 2.6, markedInner);
    }
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    Rect plotRect,
    PlotViewport visible,
  ) {
    if (!showGrid) {
      _drawAxes(canvas, plotRect, visible);
      return;
    }
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .38)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.4;
    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: .86),
      fontSize: 10,
      height: 1,
    );
    final xStep = _niceStep(visible.xSpan, plotRect.width / 76);
    final yStep = _niceStep(visible.ySpan, plotRect.height / 54);

    var xValue = (visible.xMin / xStep).ceilToDouble() * xStep;
    var drawn = 0;
    while (xValue <= visible.xMax && drawn < 120) {
      final x = visible.dataToScreen(PlotPoint(xValue, 0), plotRect).dx;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        grid,
      );
      if (showTickLabels) {
        final label = _tickLabel(xValue, xStep, labelStyle);
        final labelX = (x - label.width / 2)
            .clamp(0.0, math.max(0.0, size.width - label.width).toDouble())
            .toDouble();
        label.paint(canvas, Offset(labelX, plotRect.bottom + 4));
      }
      drawn++;
      final nextValue = xValue + xStep;
      if (!nextValue.isFinite || nextValue <= xValue) break;
      xValue = nextValue;
    }

    var yValue = (visible.yMin / yStep).ceilToDouble() * yStep;
    drawn = 0;
    while (yValue <= visible.yMax && drawn < 120) {
      final y = visible.dataToScreen(PlotPoint(0, yValue), plotRect).dy;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        grid,
      );
      if (showTickLabels) {
        final label = _tickLabel(yValue, yStep, labelStyle);
        final labelX = math
            .max(0.0, plotRect.left - label.width - 4)
            .toDouble();
        final labelY = (y - label.height / 2)
            .clamp(0.0, math.max(0.0, size.height - label.height).toDouble())
            .toDouble();
        label.paint(canvas, Offset(labelX, labelY));
      }
      drawn++;
      final nextValue = yValue + yStep;
      if (!nextValue.isFinite || nextValue <= yValue) break;
      yValue = nextValue;
    }

    // Axes stay visible even when tick labels are hidden.
    _drawAxes(canvas, plotRect, visible, axis: axis);
  }

  void _drawAxes(
    Canvas canvas,
    Rect plotRect,
    PlotViewport visible, {
    Paint? axis,
  }) {
    final paint =
        axis ??
        (Paint()
          ..color = scheme.outline
          ..strokeWidth = 1.4);
    if (visible.xMin <= 0 && visible.xMax >= 0) {
      final x = visible.dataToScreen(const PlotPoint(0, 0), plotRect).dx;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        paint,
      );
    }
    if (visible.yMin <= 0 && visible.yMax >= 0) {
      final y = visible.dataToScreen(const PlotPoint(0, 0), plotRect).dy;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        paint,
      );
    }
  }

  double _niceStep(double span, double targetTickCount) {
    if (!span.isFinite || span <= 0) return 1;
    final count = targetTickCount.clamp(2.0, 14.0).toDouble();
    final raw = span / count;
    final exponent = (math.log(raw) / math.ln10).floor();
    final magnitude = math.pow(10, exponent).toDouble();
    final normalized = raw / magnitude;
    final multiplier = normalized < 1.5
        ? 1.0
        : normalized < 3.5
        ? 2.0
        : normalized < 7.5
        ? 5.0
        : 10.0;
    return multiplier * magnitude;
  }

  TextPainter _tickLabel(double value, double step, TextStyle style) {
    final text = _formatTick(value, step);
    final cached = _labelCache[text];
    if (cached != null &&
        cached.$1 == style.color &&
        cached.$2 == style.fontSize) {
      return cached.$3;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 160);
    if (_labelCache.length > 64) _labelCache.clear();
    _labelCache[text] = (style.color, style.fontSize, painter);
    return painter;
  }

  static final Map<String, (Color?, double?, TextPainter)> _labelCache =
      <String, (Color?, double?, TextPainter)>{};

  String _formatTick(double value, double step) {
    // Ticks are produced as `start + index * step`, so the zero tick often
    // arrives as something like -2.8e-16. Treating that as a real value printed
    // "-2.8e-16" on the axis; snap anything far below one step to zero.
    if (value.abs() < step.abs() * 1e-6 || (step == 0 && value.abs() < 1e-12)) {
      return '0';
    }
    final magnitude = value.abs();
    if (magnitude >= 1e5 || (magnitude > 0 && magnitude < 1e-3)) {
      return value.toStringAsPrecision(2);
    }
    var decimals = 0;
    while (decimals < 8 &&
        ((step * math.pow(10, decimals)) -
                    (step * math.pow(10, decimals)).round())
                .abs() >
            1e-7) {
      decimals++;
    }
    var text = value.toStringAsFixed(decimals);
    if (text.contains('.')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return text == '-0' ? '0' : text;
  }

  // ---------------------------------------------------------------------------
  // 3D surface
  // ---------------------------------------------------------------------------

  void _drawSurface(Canvas canvas, Size size) {
    final finite = points
        .where(
          (point) =>
              point.x.isFinite &&
              point.y.isFinite &&
              point.z != null &&
              point.z!.isFinite,
        )
        .toList(growable: false);
    if (finite.isEmpty) {
      _drawGrid(
        canvas,
        size,
        PlotLayout.plotRectFor(size),
        PlotViewport.initial,
      );
      return;
    }

    final xs = finite.map((point) => point.x).toSet().toList()..sort();
    final ys = finite.map((point) => point.y).toSet().toList()..sort();
    if (xs.length < 2 || ys.length < 2) return;
    final xIndex = <String, int>{
      for (var i = 0; i < xs.length; i++) _coordinateKey(xs[i]): i,
    };
    final yIndex = <String, int>{
      for (var i = 0; i < ys.length; i++) _coordinateKey(ys[i]): i,
    };
    final zMin = finite
        .map((point) => point.z!)
        .reduce((a, b) => math.min(a, b).toDouble());
    final zMax = finite
        .map((point) => point.z!)
        .reduce((a, b) => math.max(a, b).toDouble());
    var zSpan = zMax - zMin;
    if (zSpan.abs() < 1e-9) zSpan = 1;

    final bounds = _SurfaceBounds(
      xCenter: (xs.first + xs.last) / 2,
      xHalf: math.max((xs.last - xs.first) / 2, 1e-9),
      yCenter: (ys.first + ys.last) / 2,
      yHalf: math.max((ys.last - ys.first) / 2, 1e-9),
      zMin: zMin,
      zSpan: zSpan,
    );
    final projected = <String, Offset>{};
    final depths = <String, double>{};
    final heights = <String, double>{};
    for (final point in finite) {
      final key =
          '${xIndex[_coordinateKey(point.x)]}:${yIndex[_coordinateKey(point.y)]}';
      final projection = _projectSurface(point, size, bounds);
      projected[key] = projection.offset;
      depths[key] = projection.depth;
      heights[key] = ((point.z! - zMin) / zSpan).clamp(0.0, 1.0).toDouble();
    }

    final cells = <_SurfaceCell>[];
    for (var row = 0; row < ys.length - 1; row++) {
      for (var column = 0; column < xs.length - 1; column++) {
        final a = projected['$column:$row'];
        final b = projected['${column + 1}:$row'];
        final c = projected['${column + 1}:${row + 1}'];
        final d = projected['$column:${row + 1}'];
        if (a == null || b == null || c == null || d == null) continue;
        final zAvg =
            ((depths['$column:$row'] ?? 0) +
                (depths['${column + 1}:$row'] ?? 0) +
                (depths['${column + 1}:${row + 1}'] ?? 0) +
                (depths['$column:${row + 1}'] ?? 0)) /
            4;
        final zLevel =
            ((heights['$column:$row'] ?? 0) +
                (heights['${column + 1}:$row'] ?? 0) +
                (heights['${column + 1}:${row + 1}'] ?? 0) +
                (heights['$column:${row + 1}'] ?? 0)) /
            4;
        cells.add(
          _SurfaceCell(
            Offset(a.dx, a.dy),
            Offset(b.dx, b.dy),
            Offset(c.dx, c.dy),
            Offset(d.dx, d.dy),
            zAvg,
            zLevel,
          ),
        );
      }
    }
    cells.sort((a, b) => a.depth.compareTo(b.depth));

    // Base plane: a light grid on z = zMin gives the surface a floor to sit on,
    // which reads as 3D far better than floating quads.
    final floorPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const gridSteps = 4;
    for (var step = 0; step <= gridSteps; step++) {
      final fraction = step / gridSteps;
      final x = xs.first + (xs.last - xs.first) * fraction;
      final y = ys.first + (ys.last - ys.first) * fraction;
      final vertical = _projectSurface(
        PlotPoint(x, ys.first, z: zMin),
        size,
        bounds,
      ).offset;
      final verticalEnd = _projectSurface(
        PlotPoint(x, ys.last, z: zMin),
        size,
        bounds,
      ).offset;
      final horizontal = _projectSurface(
        PlotPoint(xs.first, y, z: zMin),
        size,
        bounds,
      ).offset;
      final horizontalEnd = _projectSurface(
        PlotPoint(xs.last, y, z: zMin),
        size,
        bounds,
      ).offset;
      canvas.drawLine(vertical, verticalEnd, floorPaint);
      canvas.drawLine(horizontal, horizontalEnd, floorPaint);
    }

    for (final cell in cells) {
      final color = Color.lerp(scheme.primary, scheme.tertiary, cell.zLevel)!;
      final fill = Paint()
        ..color = color.withValues(alpha: 0.62)
        ..style = PaintingStyle.fill;
      final edge = Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      final path = Path()
        ..moveTo(cell.a.dx, cell.a.dy)
        ..lineTo(cell.b.dx, cell.b.dy)
        ..lineTo(cell.c.dx, cell.c.dy)
        ..lineTo(cell.d.dx, cell.d.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }

    final axisPaint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.2;
    final origin = _projectSurface(
      PlotPoint(bounds.xCenter, bounds.yCenter, z: bounds.zMin),
      size,
      bounds,
    ).offset;
    final riseTop = _projectSurface(
      PlotPoint(bounds.xCenter, bounds.yCenter, z: zMax),
      size,
      bounds,
    ).offset;
    canvas.drawLine(origin, riseTop, axisPaint);
    canvas.drawLine(origin, origin + const Offset(42, 0), axisPaint);
    canvas.drawLine(origin, origin + const Offset(-24, -24), axisPaint);
  }

  /// Projects a surface sample with a two-axis camera rotation. Kept in sync
  /// with the gesture maths in [InteractivePlotView].
  ///
  /// Normalization uses the sampled bounds rather than a hard-coded ±10 range,
  /// so a surface sampled over a different window still fills the canvas
  /// instead of being clipped or shrunk into a corner.
  _ProjectedPoint _projectSurface(
    PlotPoint point,
    Size size,
    _SurfaceBounds bounds,
  ) {
    final nx = (point.x - bounds.xCenter) / bounds.xHalf;
    final ny = (point.y - bounds.yCenter) / bounds.yHalf;
    // The height axis is squashed a little so tall surfaces stay inside the
    // canvas while still reading as three-dimensional.
    final nz =
        (((point.z ?? bounds.zMin) - bounds.zMin) / bounds.zSpan * 2 - 1) * .7;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final rotatedX = nx * cosYaw - ny * sinYaw;
    final rotatedDepth = nx * sinYaw + ny * cosYaw;
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final vertical = nz * cosPitch - rotatedDepth * sinPitch;
    final depth = nz * sinPitch + rotatedDepth * cosPitch;
    final scale = math.min(size.width, size.height).toDouble() * .30 * zoom;
    return _ProjectedPoint(
      Offset(
        size.width / 2 + rotatedX * scale + pan.dx,
        size.height / 2 - vertical * scale + pan.dy,
      ),
      depth,
    );
  }

  String _coordinateKey(double value) => value.toStringAsFixed(7);

  @override
  bool shouldRepaint(covariant FunctionPlotPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scheme != scheme ||
        oldDelegate.mode != mode ||
        oldDelegate.intersectionPoints != intersectionPoints ||
        oldDelegate.markedPoints != markedPoints ||
        oldDelegate.viewport != viewport ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showTickLabels != showTickLabels ||
        oldDelegate.background != background ||
        oldDelegate.contours != contours ||
        oldDelegate.progress != progress ||
        oldDelegate.palette != palette;
  }
}

class _ProjectedPoint {
  const _ProjectedPoint(this.offset, this.depth);

  final Offset offset;
  final double depth;
}

/// Normalization window used by the 3D surface projection.
class _SurfaceBounds {
  const _SurfaceBounds({
    required this.xCenter,
    required this.xHalf,
    required this.yCenter,
    required this.yHalf,
    required this.zMin,
    required this.zSpan,
  });

  final double xCenter;
  final double xHalf;
  final double yCenter;
  final double yHalf;
  final double zMin;
  final double zSpan;
}

class _CurvePath {
  const _CurvePath(this.path, this.curveIndex);

  final Path path;

  /// Which curve of a multi-curve plot this segment belongs to.
  ///
  /// A single function split by asymptotes produces several paths; they must all
  /// keep the same palette colour, otherwise `tan(x)` renders as alternating
  /// blue and red branches.
  final int curveIndex;
}

class _PathCache {
  const _PathCache(this.key, this.paths);

  final _PathCacheKey key;
  final List<_CurvePath> paths;
}

@immutable
class _PathCacheKey {
  const _PathCacheKey({
    required this.identity,
    required this.length,
    required this.width,
    required this.height,
    required this.viewport,
    required this.mode,
  });

  final int identity;
  final int length;
  final double width;
  final double height;
  final PlotViewport viewport;
  final String mode;

  @override
  bool operator ==(Object other) =>
      other is _PathCacheKey &&
      other.identity == identity &&
      other.length == length &&
      other.width == width &&
      other.height == height &&
      other.viewport == viewport &&
      other.mode == mode;

  @override
  int get hashCode =>
      Object.hash(identity, length, width, height, viewport, mode);
}

class _SurfaceCell {
  const _SurfaceCell(this.a, this.b, this.c, this.d, this.depth, this.zLevel);

  final Offset a;
  final Offset b;
  final Offset c;
  final Offset d;
  final double depth;
  final double zLevel;
}
