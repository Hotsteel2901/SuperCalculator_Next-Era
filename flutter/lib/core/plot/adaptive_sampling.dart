import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'plot_point.dart';

/// Adaptive curve sampling for `y = f(x)` style plots.
///
/// Uniform sampling either misses spikes (when sparse) or wastes thousands of
/// points on straight segments (when dense). This sampler starts coarse, then
/// only subdivides intervals whose midpoint deviates from the chord, which keeps
/// the whole visible curve smooth at a fraction of the sample budget.
///
/// The evaluator is async and batched: one `evaluateArray` call per refinement
/// pass, so a native FFI backend or a WebAssembly build pays the same round-trip
/// cost as the Dart fallback.
class AdaptiveCurveSampler {
  const AdaptiveCurveSampler._();

  static const int _passes = 5;

  static Future<List<PlotPoint>> sample({
    required Future<List<double?>> Function(List<double> xs) evaluate,
    required double xMin,
    required double xMax,
    required int maximumSamples,
    bool adaptive = true,
  }) async {
    if (!xMin.isFinite ||
        !xMax.isFinite ||
        xMax <= xMin ||
        maximumSamples < 8) {
      return const <PlotPoint>[];
    }
    final budget = maximumSamples.clamp(16, 20000).toInt();
    final initialCount = adaptive
        ? (budget ~/ 6).clamp(64, 640).toInt()
        : budget;
    var xs = List<double>.generate(
      initialCount + 1,
      (index) => xMin + (xMax - xMin) * index / initialCount,
      growable: false,
    );
    var ys = await evaluate(xs);

    if (!adaptive) {
      return _toPoints(xs, ys);
    }

    for (var pass = 0; pass < _passes; pass++) {
      if (xs.length >= budget) break;
      final midpoints = <double>[];
      final midIndices = <int>[];
      for (var index = 0; index < xs.length - 1; index++) {
        final y0 = ys[index];
        final y1 = ys[index + 1];
        if (y0 == null || y1 == null || !y0.isFinite || !y1.isFinite) {
          continue;
        }
        final mid = (xs[index] + xs[index + 1]) / 2;
        if (mid <= xs[index] || mid >= xs[index + 1]) continue;
        midpoints.add(mid);
        midIndices.add(index);
        if (xs.length + midpoints.length >= budget) break;
      }
      if (midpoints.isEmpty) break;

      final midYs = await evaluate(midpoints);
      final mergedX = <double>[];
      final mergedY = <double?>[];
      var cursor = 0;
      for (var index = 0; index < xs.length; index++) {
        mergedX.add(xs[index]);
        mergedY.add(ys[index]);
        if (cursor < midIndices.length && midIndices[cursor] == index) {
          final midY = midYs[cursor];
          if (_shouldRefine(
            ys[index]!,
            midY,
            ys[index + 1]!,
          )) {
            mergedX.add(midpoints[cursor]);
            mergedY.add(midY);
          }
          cursor++;
        }
      }
      xs = mergedX;
      ys = mergedY;
    }
    return _toPoints(xs, ys);
  }

  /// Adaptive sampling for parametric and polar curves.
  ///
  /// The evaluator maps a parameter list to a list of points (the same length),
  /// so `x(t), y(t)` and `r(θ)` both go through one code path. Refinement keeps
  /// a point when it deviates from the chord by more than 2% of the curve size,
  /// which closes the gaps uniform sampling leaves on loops, cusps and spirals
  /// while still spending most of the budget on the curved parts.
  static Future<List<PlotPoint>> samplePath({
    required Future<List<PlotPoint>> Function(List<double> parameters) map,
    required double parameterMin,
    required double parameterMax,
    required int maximumSamples,
    bool adaptive = true,
  }) async {
    if (!parameterMin.isFinite ||
        !parameterMax.isFinite ||
        parameterMax <= parameterMin ||
        maximumSamples < 8) {
      return const <PlotPoint>[];
    }
    final budget = maximumSamples.clamp(16, 40000).toInt();
    final initialCount = adaptive
        ? (budget ~/ 3).clamp(256, 1024).toInt()
        : budget;
    var parameters = List<double>.generate(
      initialCount + 1,
      (index) =>
          parameterMin +
          (parameterMax - parameterMin) * index / initialCount,
      growable: false,
    );
    var points = await map(parameters);
    if (!adaptive) return points;

    for (var pass = 0; pass < _passes; pass++) {
      if (points.length >= budget) break;
      final spans = _boundingSpan(points);
      if (spans <= 0) break;
      final midParameters = <double>[];
      final midIndices = <int>[];
      for (var index = 0; index < points.length - 1; index++) {
        final first = points[index];
        final second = points[index + 1];
        if (!first.isFinite || !second.isFinite) continue;
        final mid = (parameters[index] + parameters[index + 1]) / 2;
        if (mid <= parameters[index] || mid >= parameters[index + 1]) continue;
        if (!_pathNeedsMidpoint(first, second, spans)) continue;
        midParameters.add(mid);
        midIndices.add(index);
        if (points.length + midParameters.length >= budget) break;
      }
      if (midParameters.isEmpty) break;

      final midPoints = await map(midParameters);
      final mergedParameters = <double>[];
      final mergedPoints = <PlotPoint>[];
      var cursor = 0;
      for (var index = 0; index < points.length; index++) {
        mergedParameters.add(parameters[index]);
        mergedPoints.add(points[index]);
        if (cursor < midIndices.length && midIndices[cursor] == index) {
          final middle = cursor < midPoints.length
              ? midPoints[cursor]
              : const PlotPoint(double.nan, double.nan);
          if (middle.isFinite) {
            mergedParameters.add(midParameters[cursor]);
            mergedPoints.add(middle);
          }
          cursor++;
        }
      }
      parameters = mergedParameters;
      points = mergedPoints;
    }
    return points;
  }

  /// Rough size of the path, used to normalize the deviation test.
  static double _boundingSpan(List<PlotPoint> points) {
    var lowX = double.infinity;
    var highX = double.negativeInfinity;
    var lowY = double.infinity;
    var highY = double.negativeInfinity;
    for (final point in points) {
      if (!point.isFinite) continue;
      if (point.x < lowX) lowX = point.x;
      if (point.x > highX) highX = point.x;
      if (point.y < lowY) lowY = point.y;
      if (point.y > highY) highY = point.y;
    }
    if (!lowX.isFinite || !highX.isFinite) return 0;
    final spanX = highX - lowX;
    final spanY = highY - lowY;
    if (!spanX.isFinite || !spanY.isFinite) return 0;
    final span = math.max(spanX, spanY);
    return span.isFinite ? span : 0;
  }

  /// True when [second]'s interval should be split.
  static bool _pathNeedsMidpoint(
    PlotPoint first,
    PlotPoint second,
    double span,
  ) {
    final dx = second.x - first.x;
    final dy = second.y - first.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (!length.isFinite) return false;
    // Long chords hide cusps; short ones are already smooth enough.
    if (length > span * 0.06) return true;
    return false;
  }

  /// True when the midpoint is far enough from the chord to be worth another
  /// subdivision. Near-vertical jumps are also refined once, but a value that
  /// explodes relative to its neighbours is treated as an asymptote and left
  /// alone so the sampler does not chase `tan(x)` forever.
  static bool _shouldRefine(double y0, double? mid, double y1) {
    if (mid == null || !mid.isFinite) return false;
    final scale = math.max(
      1e-9,
      math.max(y0.abs(), math.max(y1.abs(), mid.abs())),
    );
    final neighbours = math.max(y0.abs(), y1.abs());
    if (mid.abs() > neighbours * 12 + 8) return false;
    final chord = (y0 + y1) / 2;
    final curvature = (mid - chord).abs() / scale;
    final slope = (y1 - y0).abs() / scale;
    return curvature > 0.0035 || slope > 2.2;
  }

  static List<PlotPoint> _toPoints(
    List<double> xs,
    List<double?> ys,
  ) {
    final points = <PlotPoint>[];
    for (var index = 0; index < xs.length; index++) {
      final y = index < ys.length ? ys[index] : null;
      points.add(
        y == null || !y.isFinite
            ? const PlotPoint(double.nan, double.nan)
            : PlotPoint(xs[index], y),
      );
    }
    return points;
  }
}

/// Splits a multi-curve expression into individual expressions.
List<String> splitCurveExpressions(String expression) => expression
    .split(RegExp(r'[;\n]+'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList(growable: false);

/// Marker inserted between curves in multi-curve mode.
///
/// `NaN` means "undefined sample inside this curve", while infinities mean
/// "a new curve starts here", so the painter can pick the next palette color
/// without guessing from coordinates.
const PlotPoint curveSeparator = PlotPoint(
  double.infinity,
  double.infinity,
);

/// Normalizes a plot coordinate for map keys without losing precision.
int quantizeCoordinate(double value, {double scale = 1e6}) =>
    (value * scale).round();

/// Compresses consecutive duplicate points emitted by steep segments.
List<PlotPoint> decimate(List<PlotPoint> points, {double minDistance = 0.35}) {
  if (points.length < 3) return points;
  final result = <PlotPoint>[points.first];
  for (var index = 1; index < points.length - 1; index++) {
    final point = points[index];
    final last = result.last;
    if (!point.isFinite) {
      if (last.isFinite) result.add(point);
      continue;
    }
    if (!last.isFinite) {
      result.add(point);
      continue;
    }
    if ((point.x - last.x).abs() < minDistance &&
        (point.y - last.y).abs() < minDistance) {
      continue;
    }
    result.add(point);
  }
  if (points.last.isFinite) result.add(points.last);
  return result;
}

/// Debug helper used by tests to inspect refinement density.
@visibleForTesting
int finiteSampleCount(List<PlotPoint> points) =>
    points.where((point) => point.isFinite).length;
