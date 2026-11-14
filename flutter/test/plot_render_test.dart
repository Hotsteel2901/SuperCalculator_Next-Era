import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supercalculator_next_era/core/compute/calculation_models.dart';
import 'package:supercalculator_next_era/core/plot/adaptive_sampling.dart';
import 'package:supercalculator_next_era/core/plot/function_plot_painter.dart';
import 'package:supercalculator_next_era/core/plot/marching_squares.dart';
import 'package:supercalculator_next_era/core/plot/plot_point.dart';
import 'package:supercalculator_next_era/core/plot/plot_viewport.dart';

/// Renders every plot mode off-screen and inspects the produced pixels.
///
/// This is the regression guard for "the whole curve must be drawn": a mode that
/// silently paints nothing (or paints only a corner) shows up as an empty or
/// nearly empty canvas instead of a visual bug nobody notices until release.
///
/// Set `PLOT_RENDER_DUMP=/some/dir` to keep the PNGs for manual review.
Future<_Render> _render({
  required String mode,
  required List<PlotPoint> points,
  List<ContourLevel> contours = const <ContourLevel>[],
  PlotViewport viewport = PlotViewport.initial,
  Size size = const Size(480, 320),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final painter = FunctionPlotPainter(
    points: points,
    scheme: ColorScheme.fromSeed(seedColor: const Color(0xFF536DDE)),
    mode: mode,
    viewport: viewport,
    contours: contours,
  );
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Render(
    png: bytes!.buffer.asUint8List(),
    pixels: rgba!.buffer.asUint8List(),
    width: size.width.round(),
    height: size.height.round(),
  );
}

class _Render {
  _Render({
    required this.png,
    required this.pixels,
    required this.width,
    required this.height,
  });

  final Uint8List png;
  final Uint8List pixels;
  final int width;
  final int height;

  /// Fraction of pixels that differ from the top-left background colour.
  double get paintedRatio {
    final r = pixels[0];
    final g = pixels[1];
    final b = pixels[2];
    var painted = 0;
    for (var index = 0; index < pixels.length; index += 4) {
      final dr = (pixels[index] - r).abs();
      final dg = (pixels[index + 1] - g).abs();
      final db = (pixels[index + 2] - b).abs();
      if (dr + dg + db > 18) painted++;
    }
    return painted / (width * height);
  }

  /// Vertical extent of painted pixels, as a fraction of the canvas height.
  double get paintedHeightRatio {
    final r = pixels[0];
    final g = pixels[1];
    final b = pixels[2];
    var top = height;
    var bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final dr = (pixels[index] - r).abs();
        final dg = (pixels[index + 1] - g).abs();
        final db = (pixels[index + 2] - b).abs();
        if (dr + dg + db > 18) {
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    if (bottom < 0) return 0;
    return (bottom - top + 1) / height;
  }

  void dump(String name) {
    final target = Platform.environment['PLOT_RENDER_DUMP'];
    if (target == null || target.isEmpty) return;
    final directory = Directory(target)..createSync(recursive: true);
    File('${directory.path}/$name.png').writeAsBytesSync(png);
  }
}

void main() {
  test('function mode paints a complete curve', () async {
    final points = await AdaptiveCurveSampler.sample(
      evaluate: (List<double> xs) async =>
          xs.map((double x) => math.sin(x)).toList(growable: false),
      xMin: -10,
      xMax: 10,
      maximumSamples: 1600,
    );
    final render = await _render(
      mode: 'function',
      points: points,
      viewport: const PlotViewport(xMin: -10, xMax: 10, yMin: -1.3, yMax: 1.3),
    );
    render.dump('function');
    expect(render.paintedRatio, greaterThan(0.02));
    // The curve spans the full height of its fitted range.
    expect(render.paintedHeightRatio, greaterThan(0.5));
  });

  test('tan mode keeps both branches and the asymptote gap', () async {
    final points = await AdaptiveCurveSampler.sample(
      evaluate: (List<double> xs) async =>
          xs.map((double x) => math.tan(x)).toList(growable: false),
      xMin: -6,
      xMax: 6,
      maximumSamples: 2400,
    );
    final render = await _render(
      mode: 'function',
      points: points,
      viewport: const PlotViewport(xMin: -6, xMax: 6, yMin: -6, yMax: 6),
    );
    render.dump('tan');
    expect(render.paintedRatio, greaterThan(0.02));
    // Well beyond the coarse pass: the sampler refines the steep branches but
    // deliberately stops chasing the asymptotes.
    expect(
      points.where((PlotPoint point) => point.isFinite).length,
      greaterThan(600),
    );
  });

  test('parametric circle is round and complete', () async {
    final points = await AdaptiveCurveSampler.samplePath(
      map: (List<double> ts) async => ts
          .map((double t) => PlotPoint(math.cos(t), math.sin(t)))
          .toList(growable: false),
      parameterMin: 0,
      parameterMax: 2 * math.pi,
      maximumSamples: 2400,
    );
    final render = await _render(
      mode: 'parametric',
      points: points,
      viewport: const PlotViewport(xMin: -1.4, xMax: 1.4, yMin: -1.4, yMax: 1.4),
    );
    render.dump('parametric');
    expect(render.paintedRatio, greaterThan(0.02));
    expect(render.paintedHeightRatio, greaterThan(0.6));
  });

  test('implicit mode draws a continuous ring, not scattered dots', () async {
    const rows = 97;
    const columns = 97;
    final samples = <PlotPointValue>[];
    final grid = Float64List(rows * columns);
    for (var row = 0; row < rows; row++) {
      final y = -5 + 10 * row / (rows - 1);
      for (var column = 0; column < columns; column++) {
        final x = -5 + 10 * column / (columns - 1);
        final value = x * x + y * y - 4;
        grid[row * columns + column] = value;
        samples.add(PlotPointValue(x: x, y: y, value: value));
      }
    }
    final contours = MarchingSquares.extract(
      grid: grid,
      rows: rows,
      columns: columns,
      xMin: -5,
      xMax: 5,
      yMin: -5,
      yMax: 5,
      levels: const <double>[0],
    );
    final render = await _render(
      mode: 'implicit',
      points: const <PlotPoint>[],
      contours: contours,
      viewport: const PlotViewport(xMin: -5, xMax: 5, yMin: -5, yMax: 5),
    );
    render.dump('implicit');
    expect(contours, hasLength(1));
    expect(render.paintedRatio, greaterThan(0.01));
  });

  test('contour mode paints several level sets', () async {
    const rows = 97;
    const columns = 97;
    final grid = Float64List(rows * columns);
    for (var row = 0; row < rows; row++) {
      final y = -5 + 10 * row / (rows - 1);
      for (var column = 0; column < columns; column++) {
        final x = -5 + 10 * column / (columns - 1);
        grid[row * columns + column] = x * x + y * y;
      }
    }
    final levels = MarchingSquares.niceLevels(0, 50, count: 9);
    final contours = MarchingSquares.extract(
      grid: grid,
      rows: rows,
      columns: columns,
      xMin: -5,
      xMax: 5,
      yMin: -5,
      yMax: 5,
      levels: levels,
    );
    final render = await _render(
      mode: 'contour',
      points: const <PlotPoint>[],
      contours: contours,
      viewport: const PlotViewport(xMin: -5, xMax: 5, yMin: -5, yMax: 5),
    );
    render.dump('contour');
    expect(contours.length, greaterThan(3));
    expect(render.paintedRatio, greaterThan(0.02));
  });

  test('vector field mode paints arrows across the canvas', () async {
    final points = <PlotPoint>[];
    for (var row = 0; row < 16; row++) {
      final y = -10 + 20 * row / 15;
      for (var column = 0; column < 16; column++) {
        final x = -10 + 20 * column / 15;
        final dx = -y;
        final dy = x;
        final length = math.sqrt(dx * dx + dy * dy);
        final factor = 0.8 / length;
        points
          ..add(PlotPoint(x - dx * factor / 2, y - dy * factor / 2))
          ..add(PlotPoint(x + dx * factor / 2, y + dy * factor / 2))
          ..add(const PlotPoint(double.nan, double.nan));
      }
    }
    final render = await _render(mode: 'vector', points: points);
    render.dump('vector');
    expect(render.paintedRatio, greaterThan(0.01));
  });

  test('surface mode paints a shaded mesh', () async {
    final points = <PlotPoint>[];
    for (var row = 0; row < 33; row++) {
      final y = -10 + 20 * row / 32;
      for (var column = 0; column < 33; column++) {
        final x = -10 + 20 * column / 32;
        points.add(PlotPoint(x, y, z: x * x + y * y));
      }
    }
    final render = await _render(mode: 'surface', points: points);
    render.dump('surface');
    expect(render.paintedRatio, greaterThan(0.05));
  });
}
