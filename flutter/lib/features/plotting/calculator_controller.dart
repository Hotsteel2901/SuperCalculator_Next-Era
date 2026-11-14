import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/calc_backend.dart';
import '../../core/backend/providers.dart';
import '../../core/history/history_repository.dart';
import '../../core/plot/adaptive_sampling.dart';
import '../../core/plot/marching_squares.dart';
import '../../core/plot/plot_point.dart';
import '../../core/plot/plot_viewport.dart';
import '../../core/settings/app_settings.dart';

final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
      CalculatorController.new,
    );

/// Immutable plotting/calculation state shared by the plot page, the
/// full-screen view and the home widgets.
///
/// Sampling results live here (not in the widget) so panning, zooming and
/// rotating never re-run the evaluator; only an explicit resample or a new
/// expression does.
class CalculatorState {
  const CalculatorState({
    required this.expression,
    required this.secondaryExpression,
    required this.xText,
    required this.mode,
    required this.backend,
    this.parameterStart = 0,
    this.parameterEnd = 2 * math.pi,
    this.value,
    this.error,
    this.isCalculating = false,
    this.points = const <PlotPoint>[],
    this.contours = const <ContourLevel>[],
    this.intersectionPoints = const <PlotPoint>[],
    this.markedPoints = const <PlotPoint>[],
    this.parameters = const <String, double>{},
    this.suggestedViewport,
    this.sampleRange = PlotViewport.initial,
    this.sampleCount = 0,
    this.sampleBudget = 0,
  });

  const CalculatorState.initial()
    : expression = 'sin(x)',
      secondaryExpression = 'cos(x)',
      xText = '0',
      mode = 'function',
      backend = 'Dart fallback',
      parameterStart = 0,
      parameterEnd = 2 * math.pi,
      value = null,
      error = null,
      isCalculating = false,
      points = const <PlotPoint>[],
      contours = const <ContourLevel>[],
      intersectionPoints = const <PlotPoint>[],
      markedPoints = const <PlotPoint>[],
      parameters = const <String, double>{},
      suggestedViewport = null,
      sampleRange = PlotViewport.initial,
      sampleCount = 0,
      sampleBudget = 0;

  final String expression;
  final String secondaryExpression;
  final String xText;
  final String mode;
  final String backend;
  final double parameterStart;
  final double parameterEnd;
  final double? value;
  final String? error;
  final bool isCalculating;
  final List<PlotPoint> points;

  /// Iso-lines for implicit and contour modes. Empty for every other mode.
  final List<ContourLevel> contours;

  final List<PlotPoint> intersectionPoints;
  final List<PlotPoint> markedPoints;
  final Map<String, double> parameters;

  /// Data range that fits the freshly sampled curve, or null when the current
  /// viewport should be kept (surface, vector field, contour grids).
  final PlotViewport? suggestedViewport;

  /// The data range the current samples were evaluated over.
  final PlotViewport sampleRange;

  /// Number of finite samples in [points].
  final int sampleCount;

  /// Sampling budget that produced [sampleCount].
  final int sampleBudget;

  bool get hasCurve => points.length > 1 || contours.isNotEmpty;

  CalculatorState copyWith({
    String? expression,
    String? secondaryExpression,
    String? xText,
    String? mode,
    String? backend,
    double? parameterStart,
    double? parameterEnd,
    double? value,
    bool clearValue = false,
    String? error,
    bool clearError = false,
    bool? isCalculating,
    List<PlotPoint>? points,
    List<ContourLevel>? contours,
    List<PlotPoint>? intersectionPoints,
    List<PlotPoint>? markedPoints,
    Map<String, double>? parameters,
    PlotViewport? suggestedViewport,
    bool clearSuggestedViewport = false,
    PlotViewport? sampleRange,
    int? sampleCount,
    int? sampleBudget,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      secondaryExpression: secondaryExpression ?? this.secondaryExpression,
      xText: xText ?? this.xText,
      mode: mode ?? this.mode,
      backend: backend ?? this.backend,
      parameterStart: parameterStart ?? this.parameterStart,
      parameterEnd: parameterEnd ?? this.parameterEnd,
      value: clearValue ? null : value ?? this.value,
      error: clearError ? null : error ?? this.error,
      isCalculating: isCalculating ?? this.isCalculating,
      points: points ?? this.points,
      contours: contours ?? this.contours,
      intersectionPoints: intersectionPoints ?? this.intersectionPoints,
      markedPoints: markedPoints ?? this.markedPoints,
      parameters: parameters ?? this.parameters,
      suggestedViewport: clearSuggestedViewport
          ? null
          : suggestedViewport ?? this.suggestedViewport,
      sampleRange: sampleRange ?? this.sampleRange,
      sampleCount: sampleCount ?? this.sampleCount,
      sampleBudget: sampleBudget ?? this.sampleBudget,
    );
  }
}

class CalculatorController extends Notifier<CalculatorState> {
  Timer? _resampleTimer;

  @override
  CalculatorState build() {
    ref.onDispose(() => _resampleTimer?.cancel());
    return const CalculatorState.initial();
  }

  AppSettings get _settings => ref.read(appSettingsProvider);

  void setExpression(String value) {
    state = state.copyWith(
      expression: value,
      clearError: true,
      clearSuggestedViewport: true,
      intersectionPoints: const <PlotPoint>[],
    );
  }

  void setSecondaryExpression(String value) {
    state = state.copyWith(
      secondaryExpression: value,
      clearError: true,
      clearSuggestedViewport: true,
      intersectionPoints: const <PlotPoint>[],
    );
  }

  void setParameter(String name, double value) {
    if (name.isEmpty || !value.isFinite) return;
    final parameters = <String, double>{...state.parameters, name: value};
    state = state.copyWith(
      parameters: parameters,
      clearError: true,
      clearSuggestedViewport: true,
    );
  }

  List<String> parameterNames({String? expression, String? secondary}) {
    final source =
        '${expression ?? state.expression} ${secondary ?? state.secondaryExpression}';
    final known = <String>{
      'x',
      'y',
      't',
      'theta',
      'pi',
      'e',
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'atan2',
      'sinh',
      'cosh',
      'tanh',
      'asinh',
      'acosh',
      'atanh',
      'sqrt',
      'cbrt',
      'abs',
      'exp',
      'ln',
      'log',
      'log10',
      'log2',
      'floor',
      'ceil',
      'round',
      'sign',
      'min',
      'max',
      'mod',
      'pow',
      'gamma',
      'erf',
      'ncr',
      'npr',
    };
    final names = <String>{};
    for (final match in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(source)) {
      final name = match.group(0)!;
      if (!known.contains(name.toLowerCase())) names.add(name);
    }
    final result = names.toList()..sort();
    return result;
  }

  String _withParameters(String expression) {
    var result = expression;
    final names = parameterNames(expression: expression, secondary: '');
    for (final name in names) {
      final value = state.parameters[name] ?? 1.0;
      if (!value.isFinite) continue;
      result = result.replaceAll(
        RegExp(r'\b' + RegExp.escape(name) + r'\b'),
        '(${value.toStringAsPrecision(15)})',
      );
    }
    return result;
  }

  String _withPlotVariable(String expression) {
    return expression.replaceAll(RegExp(r'\b(?:t|theta)\b'), 'x');
  }

  void setX(String value) {
    state = state.copyWith(xText: value, clearError: true);
  }

  void setParameterRange(double start, double end) {
    if (!start.isFinite || !end.isFinite || start >= end) {
      state = state.copyWith(
        error: 'The parameter range must be finite and increasing.',
      );
      return;
    }
    state = state.copyWith(
      parameterStart: start,
      parameterEnd: end,
      clearError: true,
      clearSuggestedViewport: true,
    );
  }

  void setMode(String value) {
    state = state.copyWith(
      mode: value,
      clearError: true,
      clearSuggestedViewport: true,
      points: const <PlotPoint>[],
      contours: const <ContourLevel>[],
      intersectionPoints: const <PlotPoint>[],
    );
  }

  /// Re-samples the current plot for a new visible data range.
  ///
  /// Called by [InteractivePlotView] after a pan or zoom ends when the
  /// `autoResample` setting is on. The range is only accepted when it moved far
  /// enough to matter, and the resample is debounced so a fling does not queue
  /// dozens of evaluations.
  void syncSamplingRange(PlotViewport viewport, {bool force = false}) {
    if (!viewport.isValid) return;
    final current = state.sampleRange;
    final shiftedX =
        (viewport.xMin - current.xMin).abs() > current.xSpan * 0.02;
    final zoomedX = (viewport.xSpan / current.xSpan - 1).abs() > 0.02;
    final shiftedY =
        (viewport.yMin - current.yMin).abs() > current.ySpan * 0.02 ||
        (viewport.ySpan / current.ySpan - 1).abs() > 0.02;
    final needsBoth = _usesPlanarSampling(state.mode);
    if (!force && !shiftedX && !zoomedX && !(needsBoth && shiftedY)) return;
    if (!force && !_settings.autoResample) return;
    state = state.copyWith(
      sampleRange: _usesPlanarSampling(state.mode)
          ? viewport
          : PlotViewport(
              xMin: viewport.xMin,
              xMax: viewport.xMax,
              yMin: current.yMin,
              yMax: current.yMax,
            ),
    );
    _resampleTimer?.cancel();
    _resampleTimer = Timer(const Duration(milliseconds: 180), () {
      if (!ref.mounted) return;
      unawaited(evaluate(preserveViewport: true));
    });
  }

  static int _finiteCount(List<PlotPoint> points) =>
      points.where((point) => point.isFinite).length;

  static bool _usesPlanarSampling(String mode) =>
      mode == 'implicit' ||
      mode == 'surface' ||
      mode == 'contour' ||
      mode == 'direction' ||
      mode == 'vector';

  Future<void> evaluate({bool preserveViewport = false}) async {
    final settings = _settings;
    final backend = ref.read(calcBackendProvider);
    final mode = state.mode;
    final rawExpression = state.expression.trim();
    final rawSecondary = state.secondaryExpression.trim();
    final parameterizedExpression = _withParameters(rawExpression);
    final parameterizedSecondary = _withParameters(rawSecondary);
    final expression = mode == 'parametric' || mode == 'polar'
        ? _withPlotVariable(parameterizedExpression)
        : parameterizedExpression;
    final secondary = mode == 'parametric'
        ? _withPlotVariable(parameterizedSecondary)
        : parameterizedSecondary;
    final parsedX = double.tryParse(state.xText.trim());
    final x = parsedX ?? 0;
    if (rawExpression.isEmpty) {
      state = state.copyWith(
        error: 'Expression cannot be empty.',
        clearValue: true,
      );
      return;
    }
    if (mode == 'function' && (parsedX == null || !parsedX.isFinite)) {
      state = state.copyWith(
        error: 'The x argument must be a finite number.',
        clearValue: true,
      );
      return;
    }

    state = state.copyWith(
      backend: backend.name,
      isCalculating: true,
      clearError: true,
      clearValue: true,
      points: const <PlotPoint>[],
      contours: const <ContourLevel>[],
      intersectionPoints: const <PlotPoint>[],
      clearSuggestedViewport: true,
    );

    try {
      if (mode == 'function') {
        final result = await backend.evaluate(expression, x);
        final points = await _sampleFunction(
          backend,
          expression,
          settings: settings,
        );
        if (!ref.mounted) return;
        state = state.copyWith(
          backend: result.backend,
          value: result.value,
          error: result.error,
          isCalculating: false,
          points: points,
          sampleCount: _finiteCount(points),
          sampleBudget: settings.plotResolution.maximumSamples,
          suggestedViewport: preserveViewport
              ? null
              : _fitFunction(points, state.sampleRange),
        );
        if (result.value != null) {
          _recordHistory(
            expression: rawExpression,
            result: _formatValue(result.value!, settings),
            backend: result.backend,
          );
        }
        return;
      }

      final sampled = await _sampleMode(
        backend,
        mode,
        expression,
        secondary,
        settings: settings,
      );
      if (!ref.mounted) return;
      var intersectionPoints = const <PlotPoint>[];
      if (mode == 'multi') {
        try {
          intersectionPoints = await _intersectionPoints(
            backend,
            expression,
            state.sampleRange,
          );
        } on FormatException {
          // Keep valid curves visible even when one invalid curve cannot
          // participate in the intersection query.
        }
      }
      final fitted = preserveViewport ? null : _fitMode(sampled.points, mode);
      state = state.copyWith(
        backend: backend.name,
        isCalculating: false,
        points: sampled.points,
        contours: sampled.contours,
        intersectionPoints: intersectionPoints,
        error: sampled.isEmpty
            ? (rawExpression.isEmpty
                  ? null
                  : 'The plot could not be evaluated in the visible range.')
            : null,
        sampleCount: _finiteCount(sampled.points),
        sampleBudget: settings.plotResolution.maximumSamples,
        suggestedViewport: fitted,
      );
      if (!sampled.isEmpty) {
        _recordHistory(
          expression: '$mode: $rawExpression',
          result: sampled.contours.isNotEmpty
              ? '${sampled.contours.length} contour levels'
              : '${_finiteCount(sampled.points)} plotted points',
          backend: backend.name,
        );
      }
    } on FormatException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isCalculating: false,
        error: error.message,
        clearValue: true,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isCalculating: false,
        error: 'The expression could not be evaluated.',
        clearValue: true,
      );
    }
  }

  String _formatValue(double value, AppSettings settings) {
    final digits = settings.numberPrecision.digits;
    if (digits != null) return value.toStringAsPrecision(digits);
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsPrecision(12);
  }

  void _recordHistory({
    required String expression,
    required String result,
    required String backend,
  }) {
    if (!_settings.autoSaveHistory) return;
    ref
        .read(calculationHistoryProvider.notifier)
        .add(expression: expression, result: result, backend: backend);
  }

  /// Samples `y = f(x)` across the whole visible x range.
  ///
  /// The budget comes from the sampling-precision setting; adaptive sampling is
  /// only disabled when the user explicitly asks for uniform sampling, which is
  /// useful for diagnosing dense periodic curves.
  Future<List<PlotPoint>> _sampleFunction(
    CalcBackend backend,
    String expression, {
    required AppSettings settings,
  }) {
    final range = state.sampleRange;
    // Without auto-resampling the samples must outlive a few pans, so the
    // domain is evaluated three times wider than the visible range. The curve
    // stays complete while the evaluator is not re-run mid-gesture.
    final padding = settings.autoResample ? 0.0 : range.xSpan;
    return AdaptiveCurveSampler.sample(
      evaluate: (List<double> xs) => backend.evaluateArray(expression, xs),
      xMin: range.xMin - padding,
      xMax: range.xMax + padding,
      maximumSamples: settings.plotResolution.maximumSamples,
      adaptive: settings.adaptiveSampling,
    );
  }

  Future<_ModeSample> _sampleMode(
    CalcBackend backend,
    String mode,
    String expression,
    String secondary, {
    required AppSettings settings,
  }) async {
    final range = state.sampleRange;
    final budget = settings.plotResolution.maximumSamples;
    switch (mode) {
      case 'multi':
        final expressions = splitCurveExpressions(expression);
        if (expressions.isEmpty) return const _ModeSample.empty();
        final points = <PlotPoint>[];
        for (final item in expressions) {
          final curve = await AdaptiveCurveSampler.sample(
            evaluate: (List<double> xs) => backend.evaluateArray(item, xs),
            xMin: range.xMin,
            xMax: range.xMax,
            maximumSamples: budget,
            adaptive: settings.adaptiveSampling,
          );
          if (!curve.any((point) => point.isFinite)) continue;
          points
            ..addAll(curve)
            ..add(curveSeparator);
        }
        return _ModeSample(points: points);

      case 'parametric':
        final points = await AdaptiveCurveSampler.samplePath(
          map: (List<double> ts) =>
              _parametricPoints(backend, expression, secondary, ts),
          parameterMin: state.parameterStart,
          parameterMax: state.parameterEnd,
          maximumSamples: budget * 2,
          adaptive: settings.adaptiveSampling,
        );
        return _ModeSample(points: points);

      case 'polar':
        final points = await AdaptiveCurveSampler.samplePath(
          map: (List<double> ts) => _polarPoints(backend, expression, ts),
          parameterMin: state.parameterStart,
          parameterMax: state.parameterEnd,
          maximumSamples: budget * 2,
          adaptive: settings.adaptiveSampling,
        );
        return _ModeSample(points: points);

      case 'surface':
        final divisions = settings.meshDensity.divisions;
        final samples = await backend.sampleSurface(
          expression,
          range.xMin,
          range.xMax,
          range.yMin,
          range.yMax,
          rows: divisions,
          columns: divisions,
        );
        // Preserve all three coordinates. The painter applies an interactive
        // projection so the same sampled surface can be rotated and zoomed on
        // touch, pointer and keyboard-driven desktop layouts.
        return _ModeSample(
          points: samples
              .map((sample) => PlotPoint(sample.x, sample.y, z: sample.value))
              .toList(growable: false),
        );

      case 'contour':
        final contours = await _contours(
          backend,
          expression,
          range,
          resolution: math.max(72, settings.meshDensity.divisions * 2),
        );
        return _ModeSample(contours: contours);

      case 'implicit':
        final contours = await _contours(
          backend,
          expression,
          range,
          resolution: math.max(96, settings.meshDensity.divisions * 3),
          fixedLevels: const <double>[0],
        );
        return _ModeSample(contours: contours);

      case 'direction':
      case 'vector':
        final rows = (settings.meshDensity.divisions / 2).round().clamp(12, 36);
        final vectors = mode == 'direction'
            ? await backend.sampleDirectionField(
                expression,
                range.xMin,
                range.xMax,
                range.yMin,
                range.yMax,
                rows: rows,
                columns: rows,
              )
            : await backend.sampleVectorField(
                expression,
                secondary,
                range.xMin,
                range.xMax,
                range.yMin,
                range.yMax,
                rows: rows,
                columns: rows,
              );
        final points = <PlotPoint>[];
        final diagonal = math.sqrt(
          range.xSpan * range.xSpan + range.ySpan * range.ySpan,
        );
        final scale = (diagonal / rows) * 0.42;
        for (final vector in vectors) {
          if (!vector.dx.isFinite || !vector.dy.isFinite) continue;
          final length = math.sqrt(
            vector.dx * vector.dx + vector.dy * vector.dy,
          );
          if (!length.isFinite || length <= 1e-12) continue;
          final factor = scale / length;
          points
            ..add(
              PlotPoint(
                vector.x - vector.dx * factor * .5,
                vector.y - vector.dy * factor * .5,
              ),
            )
            ..add(
              PlotPoint(
                vector.x + vector.dx * factor * .5,
                vector.y + vector.dy * factor * .5,
              ),
            )
            ..add(const PlotPoint(double.nan, double.nan));
        }
        return _ModeSample(points: points);
    }
    return const _ModeSample.empty();
  }

  Future<List<PlotPoint>> _parametricPoints(
    CalcBackend backend,
    String expression,
    String secondary,
    List<double> ts,
  ) async {
    final xs = await backend.evaluateArray(expression, ts);
    final ys = await backend.evaluateArray(secondary, ts);
    return List<PlotPoint>.generate(ts.length, (index) {
      final x = index < xs.length ? xs[index] : null;
      final y = index < ys.length ? ys[index] : null;
      return x != null && y != null && x.isFinite && y.isFinite
          ? PlotPoint(x, y)
          : const PlotPoint(double.nan, double.nan);
    }, growable: false);
  }

  Future<List<PlotPoint>> _polarPoints(
    CalcBackend backend,
    String expression,
    List<double> ts,
  ) async {
    final radii = await backend.evaluateArray(expression, ts);
    return List<PlotPoint>.generate(ts.length, (index) {
      final radius = index < radii.length ? radii[index] : null;
      if (radius == null || !radius.isFinite) {
        return const PlotPoint(double.nan, double.nan);
      }
      // `r` may legitimately be negative: that mirrors the point through the
      // origin, which is what polar plotting is expected to show.
      return PlotPoint(
        radius * math.cos(ts[index]),
        radius * math.sin(ts[index]),
      );
    }, growable: false);
  }

  /// Builds continuous iso-lines over the visible range with marching squares.
  ///
  /// `fixedLevels` is used by implicit plots (`f(x, y) = 0`); contour plots ask
  /// for evenly spaced levels across the sampled value range.
  Future<List<ContourLevel>> _contours(
    CalcBackend backend,
    String expression,
    PlotViewport range, {
    required int resolution,
    List<double>? fixedLevels,
  }) async {
    final samples = await backend.sampleSurface(
      expression,
      range.xMin,
      range.xMax,
      range.yMin,
      range.yMax,
      rows: resolution,
      columns: resolution,
    );
    if (samples.isEmpty) return const <ContourLevel>[];
    final grid = MarchingSquares.buildGrid(
      samples: samples,
      xMin: range.xMin,
      xMax: range.xMax,
      yMin: range.yMin,
      yMax: range.yMax,
      rows: resolution,
      columns: resolution,
    );
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final newValue in grid) {
      if (!newValue.isFinite) continue;
      if (newValue < low) low = newValue;
      if (newValue > high) high = newValue;
    }
    if (!low.isFinite || !high.isFinite) return const <ContourLevel>[];
    final levels =
        fixedLevels ?? MarchingSquares.niceLevels(low, high, count: 9);
    return MarchingSquares.extract(
      grid: grid,
      rows: resolution,
      columns: resolution,
      xMin: range.xMin,
      xMax: range.xMax,
      yMin: range.yMin,
      yMax: range.yMax,
      levels: levels,
    );
  }

  Future<List<PlotPoint>> _intersectionPoints(
    CalcBackend backend,
    String expression,
    PlotViewport range,
  ) async {
    final expressions = splitCurveExpressions(expression);
    if (expressions.length < 2) return const <PlotPoint>[];

    final result = <PlotPoint>[];
    for (var left = 0; left < expressions.length - 1; left++) {
      for (var right = left + 1; right < expressions.length; right++) {
        final roots = await backend.intersections(
          expressions[left],
          expressions[right],
          range.xMin,
          range.xMax,
          samples: 512,
          tolerance: 1e-7,
        );
        if (roots.isEmpty) continue;
        final ys = await backend.evaluateArray(expressions[left], roots);
        for (var index = 0; index < roots.length; index++) {
          final x = roots[index];
          final y = index < ys.length ? ys[index] : null;
          if (!x.isFinite || y == null || !y.isFinite) continue;
          final point = PlotPoint(x, y);
          final duplicate = result.any(
            (existing) =>
                (existing.x - x).abs() < 1e-6 && (existing.y - y).abs() < 1e-6,
          );
          if (!duplicate) result.add(point);
        }
      }
    }
    result.sort((a, b) => a.x.compareTo(b.x));
    return result;
  }

  Future<void> findIntersections() async {
    final backend = ref.read(calcBackendProvider);
    final expression = _withParameters(state.expression.trim());
    if (state.mode != 'multi') {
      state = state.copyWith(
        error: 'Choose multi-curve mode to query intersections.',
      );
      return;
    }
    state = state.copyWith(isCalculating: true, clearError: true);
    try {
      final points = await _intersectionPoints(
        backend,
        expression,
        state.sampleRange,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        isCalculating: false,
        intersectionPoints: points,
        error: points.isEmpty ? 'No finite intersections were found.' : null,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isCalculating: false,
        error: 'The intersections could not be evaluated.',
      );
    }
  }

  /// Fits the y range of a function plot so the whole sampled curve is visible.
  ///
  /// Robust percentiles keep a single asymptote (`tan`, `1/x`) from flattening
  /// the interesting part of the curve into a horizontal line.
  PlotViewport? _fitFunction(List<PlotPoint> points, PlotViewport range) {
    final values = points
        .where((point) => point.isFinite)
        .map((point) => point.y)
        .toList(growable: false);
    if (values.length < 3) return null;
    values.sort();
    final lowIndex = (values.length * 0.02).floor();
    final highIndex = (values.length * 0.98).ceil().clamp(0, values.length - 1);
    var low = values[lowIndex];
    var high = values[highIndex];
    if (!low.isFinite || !high.isFinite) return null;
    if (high - low < 1e-9) {
      final centre = (high + low) / 2;
      low = centre - 1;
      high = centre + 1;
    }
    final span = high - low;
    final padded = span * 0.12;
    return PlotViewport(
      xMin: range.xMin,
      xMax: range.xMax,
      yMin: low - padded,
      yMax: high + padded,
    );
  }

  /// Fits the viewport to a path-based plot (parametric and polar), keeping the
  /// aspect ratio square so circles stay circular.
  PlotViewport? _fitMode(List<PlotPoint> points, String mode) {
    if (mode != 'parametric' && mode != 'polar') return null;
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
    if (!lowX.isFinite || !highX.isFinite) return null;
    if (!lowY.isFinite || !highY.isFinite) return null;
    var spanX = math.max(highX - lowX, 1e-6);
    var spanY = math.max(highY - lowY, 1e-6);
    final span = math.max(spanX, spanY) * 1.16;
    spanX = span;
    spanY = span;
    final centreX = (lowX + highX) / 2;
    final centreY = (lowY + highY) / 2;
    final candidate = PlotViewport(
      xMin: centreX - spanX / 2,
      xMax: centreX + spanX / 2,
      yMin: centreY - spanY / 2,
      yMax: centreY + spanY / 2,
    );
    return candidate.isValid ? candidate : null;
  }

  void addMarkedPoint(PlotPoint point) {
    if (!point.isFinite) return;
    final duplicate = state.markedPoints.any(
      (existing) =>
          (existing.x - point.x).abs() < 1e-6 &&
          (existing.y - point.y).abs() < 1e-6,
    );
    if (duplicate) return;
    state = state.copyWith(
      markedPoints: <PlotPoint>[...state.markedPoints, point],
    );
  }

  void removeNearestMarkedPoint(PlotPoint point, {double tolerance = .5}) {
    if (state.markedPoints.isEmpty) return;
    var nearest = -1;
    var distance = double.infinity;
    for (var index = 0; index < state.markedPoints.length; index++) {
      final current = state.markedPoints[index];
      final dx = current.x - point.x;
      final dy = current.y - point.y;
      final candidate = math.sqrt(dx * dx + dy * dy);
      if (candidate < distance) {
        distance = candidate;
        nearest = index;
      }
    }
    if (nearest < 0 || distance > tolerance) return;
    final points = [...state.markedPoints]..removeAt(nearest);
    state = state.copyWith(markedPoints: points);
  }

  void clearMarkedPoints() {
    if (state.markedPoints.isEmpty) return;
    state = state.copyWith(markedPoints: const <PlotPoint>[]);
  }

  void clear() {
    state = const CalculatorState.initial();
  }
}

/// Sampling result for a non-function plot mode.
class _ModeSample {
  const _ModeSample({
    this.points = const <PlotPoint>[],
    this.contours = const <ContourLevel>[],
  });

  const _ModeSample.empty() : this();

  final List<PlotPoint> points;
  final List<ContourLevel> contours;

  bool get isEmpty =>
      !points.any((point) => point.isFinite) && contours.isEmpty;
}
