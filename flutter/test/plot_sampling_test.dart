import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supercalculator_next_era/core/compute/calculation_models.dart';
import 'package:supercalculator_next_era/core/plot/adaptive_sampling.dart';
import 'package:supercalculator_next_era/core/plot/marching_squares.dart';
import 'package:supercalculator_next_era/core/plot/plot_point.dart';

void main() {
  group('adaptive curve sampling', () {
    test('keeps the whole domain and hits the sampling budget', () async {
      final points = await AdaptiveCurveSampler.sample(
        evaluate: (List<double> xs) async =>
            xs.map((double x) => math.sin(x)).toList(growable: false),
        xMin: -10,
        xMax: 10,
        maximumSamples: 2000,
      );

      // Adaptive sampling is a budget, not a quota: a smooth sine is already
      // accurate with the coarse pass, so far fewer than 2000 points are used.
      expect(points.length, greaterThan(300));
      expect(points.length, lessThanOrEqualTo(2001));
      expect(points.first.x, -10);
      expect(points.last.x, 10);
      // The x coordinates stay strictly increasing: the painter relies on that
      // to build a single continuous path.
      for (var index = 1; index < points.length; index++) {
        expect(points[index].x, greaterThan(points[index - 1].x));
      }
    });

    test('spends more samples where the curve bends', () async {
      // A flat line on [-10, 0] and a fast oscillation on [0, 10].
      double value(double x) => x <= 0 ? 0 : math.sin(x * 12);
      final points = await AdaptiveCurveSampler.sample(
        evaluate: (List<double> xs) async =>
            xs.map(value).toList(growable: false),
        xMin: -10,
        xMax: 10,
        maximumSamples: 3000,
      );

      final flat = points.where((PlotPoint p) => p.x < -0.5).length;
      final busy = points.where((PlotPoint p) => p.x > 0.5).length;
      expect(busy, greaterThan(flat));
    });

    test('marks undefined samples instead of dropping the curve', () async {
      // `sqrt` of a negative argument is undefined, so half of the domain has
      // no value; the sampled list must keep placeholders there so the painter
      // breaks the path instead of connecting across the gap.
      final points = await AdaptiveCurveSampler.sample(
        evaluate: (List<double> xs) async => xs
            .map((double x) => x < 0 ? double.nan : math.sqrt(x))
            .toList(growable: false),
        xMin: -2,
        xMax: 2,
        maximumSamples: 800,
      );

      expect(points.any((PlotPoint p) => !p.isFinite), isTrue);
      final finite = points.where((PlotPoint p) => p.isFinite).toList();
      expect(finite.length, greaterThan(50));
      expect(finite.every((PlotPoint p) => p.x >= 0), isTrue);
    });

    test('uniform mode returns the requested grid', () async {
      final points = await AdaptiveCurveSampler.sample(
        evaluate: (List<double> xs) async =>
            xs.map((double x) => x * x).toList(growable: false),
        xMin: 0,
        xMax: 1,
        maximumSamples: 64,
        adaptive: false,
      );

      expect(points.length, 65);
    });
  });

  group('adaptive path sampling', () {
    test('closes a parametric circle without gaps', () async {
      final points = await AdaptiveCurveSampler.samplePath(
        map: (List<double> ts) async => ts
            .map((double t) => PlotPoint(math.cos(t), math.sin(t)))
            .toList(growable: false),
        parameterMin: 0,
        parameterMax: 2 * math.pi,
        maximumSamples: 4000,
      );

      expect(points.length, greaterThan(500));
      for (final point in points) {
        expect(
          math.sqrt(point.x * point.x + point.y * point.y),
          closeTo(1, 1e-9),
        );
      }
      final first = points.first;
      final last = points.last;
      expect((first.x - last.x).abs(), lessThan(1e-6));
      expect((first.y - last.y).abs(), lessThan(1e-6));
    });
  });

  group('marching squares', () {
    test('reconstructs a continuous zero level set', () {
      const rows = 81;
      const columns = 81;
      const radius = 4.0;
      final grid = Float64List(rows * columns);
      final samples = <PlotPointValue>[];
      for (var row = 0; row < rows; row++) {
        final y = -10 + 20 * row / (rows - 1);
        for (var column = 0; column < columns; column++) {
          final x = -10 + 20 * column / (columns - 1);
          final value = x * x + y * y - radius * radius;
          grid[row * columns + column] = value;
          samples.add(PlotPointValue(x: x, y: y, value: value));
        }
      }

      final levels = MarchingSquares.extract(
        grid: grid,
        rows: rows,
        columns: columns,
        xMin: -10,
        xMax: 10,
        yMin: -10,
        yMax: 10,
        levels: const <double>[0],
      );

      expect(levels, hasLength(1));
      final contour = levels.single;
      expect(contour.points.length, greaterThan(100));
      // Every emitted vertex lies on the circle.
      for (final point in contour.points) {
        if (!point.isFinite) continue;
        final distance = math.sqrt(point.x * point.x + point.y * point.y);
        expect(distance, closeTo(radius, 0.03));
      }
    });

    test('nice levels stay inside the sampled range', () {
      final levels = MarchingSquares.niceLevels(-3, 7, count: 8);
      expect(levels, isNotEmpty);
      for (final level in levels) {
        expect(level, greaterThan(-3));
        expect(level, lessThan(7));
      }
      expect(levels, orderedEquals(levels.toList()..sort()));
    });

    test('build grid round-trips sample coordinates into cells', () {
      final samples = <PlotPointValue>[
        const PlotPointValue(x: -1, y: -1, value: 1),
        const PlotPointValue(x: 0, y: 0, value: 2),
        const PlotPointValue(x: 1, y: 1, value: 3),
      ];
      final grid = MarchingSquares.buildGrid(
        samples: samples,
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        rows: 3,
        columns: 3,
      );
      expect(grid.length, 9);
      expect(grid[0], 1);
      expect(grid[4], 2);
      expect(grid[8], 3);
    });
  });

  group('multi-curve markers', () {
    test('curve separators are infinite so the painter restarts the path', () {
      expect(curveSeparator.x, double.infinity);
      expect(curveSeparator.isFinite, isFalse);
      expect(splitCurveExpressions('sin(x); cos(x)\n tan(x)'), <String>[
        'sin(x)',
        'cos(x)',
        'tan(x)',
      ]);
    });

    test('decimate drops duplicate coordinates but keeps separators', () {
      final points = <PlotPoint>[
        const PlotPoint(0, 0),
        const PlotPoint(0, 0),
        const PlotPoint(1, 1),
        curveSeparator,
        const PlotPoint(2, 2),
      ];
      final result = decimate(points, minDistance: 0.01);
      expect(result.length, lessThan(points.length));
      expect(result.where((PlotPoint p) => p.x.isFinite).length, 3);
    });
  });
}
