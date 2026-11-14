import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../compute/calculation_models.dart';
import 'plot_point.dart';

/// One iso-line produced by [MarchingSquares].
@immutable
class ContourLevel {
  const ContourLevel({
    required this.level,
    required this.points,
    required this.normalized,
  });

  /// The iso value this line represents.
  final double level;

  /// A flat polyline list: each pair of points is a segment, separated by NaN
  /// markers so the painter can stroke them as one path without connecting
  /// unrelated cells.
  final List<PlotPoint> points;

  /// Position of [level] in the sampled range (0 = minimum, 1 = maximum).
  final double normalized;
}

/// Marching-squares contour extraction.
///
/// The implicit/contour plot used to draw isolated dots where `|f|` happened to
/// be small, which reads as a dotted sketch rather than a curve. This class
/// reconstructs the full sampled grid and extracts continuous iso-lines, so the
/// rendered result is the complete curve on every platform.
abstract final class MarchingSquares {
  /// Rebuilds a row-major grid from sparse samples.
  ///
  /// `sampleSurface` omits non-finite cells, so the grid is filled by rounding
  /// each sample's coordinate back to its cell. Missing cells stay NaN and are
  /// skipped by the contour walk.
  static Float64List buildGrid({
    required List<PlotPointValue> samples,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
    required int rows,
    required int columns,
  }) {
    final grid = Float64List(rows * columns);
    for (var index = 0; index < grid.length; index++) {
      grid[index] = double.nan;
    }
    if (rows < 2 || columns < 2 || xMax <= xMin || yMax <= yMin) return grid;
    final xSpan = xMax - xMin;
    final ySpan = yMax - yMin;
    for (final sample in samples) {
      final column = ((sample.x - xMin) / xSpan * (columns - 1)).round();
      final row = ((sample.y - yMin) / ySpan * (rows - 1)).round();
      if (row < 0 || row >= rows || column < 0 || column >= columns) continue;
      grid[row * columns + column] = sample.value;
    }
    return grid;
  }

  /// Extracts the iso-lines for [levels].
  static List<ContourLevel> extract({
    required Float64List grid,
    required int rows,
    required int columns,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
    required List<double> levels,
  }) {
    if (rows < 2 || columns < 2 || levels.isEmpty) return const <ContourLevel>[];
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final value in grid) {
      if (!value.isFinite) continue;
      if (value < low) low = value;
      if (value > high) high = value;
    }
    if (!low.isFinite || !high.isFinite || high <= low) {
      return const <ContourLevel>[];
    }
    final span = high - low;
    final dx = (xMax - xMin) / (columns - 1);
    final dy = (yMax - yMin) / (rows - 1);
    final result = <ContourLevel>[];
    for (final level in levels) {
      if (!level.isFinite || level < low || level > high) continue;
      final points = <PlotPoint>[];
      for (var row = 0; row < rows - 1; row++) {
        for (var column = 0; column < columns - 1; column++) {
          final a = grid[row * columns + column];
          final b = grid[row * columns + column + 1];
          final c = grid[(row + 1) * columns + column + 1];
          final d = grid[(row + 1) * columns + column];
          if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
            continue;
          }
          final caseIndex =
              (a > level ? 1 : 0) |
              (b > level ? 2 : 0) |
              (c > level ? 4 : 0) |
              (d > level ? 8 : 0);
          if (caseIndex == 0 || caseIndex == 15) continue;

          final x0 = xMin + column * dx;
          final x1 = x0 + dx;
          final y0 = yMin + row * dy;
          final y1 = y0 + dy;

          PlotPoint onBottom() => _interpolate(
            level,
            a,
            b,
            PlotPoint(x0, y0),
            PlotPoint(x1, y0),
          );
          PlotPoint onRight() => _interpolate(
            level,
            b,
            c,
            PlotPoint(x1, y0),
            PlotPoint(x1, y1),
          );
          PlotPoint onTop() => _interpolate(
            level,
            d,
            c,
            PlotPoint(x0, y1),
            PlotPoint(x1, y1),
          );
          PlotPoint onLeft() => _interpolate(
            level,
            a,
            d,
            PlotPoint(x0, y0),
            PlotPoint(x0, y1),
          );

          void segment(PlotPoint first, PlotPoint second) {
            if (!first.isFinite || !second.isFinite) return;
            points
              ..add(first)
              ..add(second);
          }

          switch (caseIndex) {
            case 1:
            case 14:
              segment(onLeft(), onBottom());
              break;
            case 2:
            case 13:
              segment(onBottom(), onRight());
              break;
            case 3:
            case 12:
              segment(onLeft(), onRight());
              break;
            case 4:
            case 11:
              segment(onRight(), onTop());
              break;
            case 6:
            case 9:
              segment(onBottom(), onTop());
              break;
            case 7:
            case 8:
              segment(onLeft(), onTop());
              break;
            case 5:
              // Ambiguous saddle: resolve with the cell average.
              if ((a + b + c + d) / 4 > level) {
                segment(onLeft(), onTop());
                segment(onBottom(), onRight());
              } else {
                segment(onLeft(), onBottom());
                segment(onRight(), onTop());
              }
              break;
            case 10:
              if ((a + b + c + d) / 4 > level) {
                segment(onLeft(), onBottom());
                segment(onRight(), onTop());
              } else {
                segment(onLeft(), onTop());
                segment(onBottom(), onRight());
              }
              break;
          }
        }
      }
      if (points.length < 2) continue;
      result.add(
        ContourLevel(
          level: level,
          points: _withSeparators(points),
          normalized: ((level - low) / span).clamp(0.0, 1.0).toDouble(),
        ),
      );
    }
    return result;
  }

  /// Splits a flat segment list into individual polylines separated by NaN.
  static List<PlotPoint> _withSeparators(List<PlotPoint> segments) {
    final points = <PlotPoint>[];
    for (var index = 0; index < segments.length; index += 2) {
      points
        ..add(segments[index])
        ..add(segments[index + 1])
        ..add(const PlotPoint(double.nan, double.nan));
    }
    return points;
  }

  static PlotPoint _interpolate(
    double level,
    double firstValue,
    double secondValue,
    PlotPoint first,
    PlotPoint second,
  ) {
    final delta = secondValue - firstValue;
    if (!delta.isFinite || delta.abs() < 1e-12) {
      return PlotPoint(
        (first.x + second.x) / 2,
        (first.y + second.y) / 2,
      );
    }
    final t = ((level - firstValue) / delta).clamp(0.0, 1.0).toDouble();
    return PlotPoint(
      first.x + (second.x - first.x) * t,
      first.y + (second.y - first.y) * t,
    );
  }

  /// Picks readable contour levels between [low] and [high].
  static List<double> niceLevels(
    double low,
    double high, {
    int count = 9,
  }) {
    if (!low.isFinite || !high.isFinite || high <= low || count < 1) {
      return const <double>[];
    }
    final rawStep = (high - low) / (count + 1);
    final exponent = (math.log(rawStep) / math.ln10).floor();
    final magnitude = math.pow(10, exponent).toDouble();
    final normalized = rawStep / magnitude;
    final multiplier = normalized < 1.5
        ? 1.0
        : normalized < 3.5
        ? 2.0
        : normalized < 7.5
        ? 5.0
        : 10.0;
    final step = multiplier * magnitude;
    final levels = <double>[];
    var value = (low / step).ceilToDouble() * step;
    var guard = 0;
    while (value < high && guard < count + 4) {
      // Skip the exact extremes: they produce degenerate zero-length lines.
      if ((value - low).abs() > step * 0.25 &&
          (high - value).abs() > step * 0.25) {
        levels.add(value);
      }
      value += step;
      guard++;
    }
    return levels;
  }
}
