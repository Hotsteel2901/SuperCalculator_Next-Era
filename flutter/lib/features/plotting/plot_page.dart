import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../core/plot/interactive_plot_view.dart';
import '../../core/presets/preset_catalog.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import 'calculator_controller.dart';
import 'plot_fullscreen_page.dart';
import 'plot_surface.dart';
import 'quick_input_panel.dart';

class _PlotPreset {
  const _PlotPreset(
    this.label,
    this.expression, [
    this.secondary,
    this.start = 0,
    this.end = 2 * 3.141592653589793,
  ]);

  final String label;
  final String expression;
  final String? secondary;
  final double start;
  final double end;
}

const _plotPresets = <String, List<_PlotPreset>>{
  'function': <_PlotPreset>[
    _PlotPreset('sin(x)', 'sin(x)'),
    _PlotPreset('cos(x)', 'cos(x)'),
    _PlotPreset('tan(x)', 'tan(x)'),
    _PlotPreset('x²', 'x^2'),
    _PlotPreset('x³', 'x^3'),
    _PlotPreset('sqrt(x)', 'sqrt(x)'),
    _PlotPreset('ln(x)', 'ln(x)'),
    _PlotPreset('log10(x)', 'log(x)'),
    _PlotPreset('exp(x)', 'exp(x)'),
    _PlotPreset('1/x', '1/x'),
    _PlotPreset('abs(x)', 'abs(x)'),
    _PlotPreset('sin(x)+cos(x)', 'sin(x)+cos(x)'),
    _PlotPreset('x·sin(x)', 'x*sin(x)'),
    _PlotPreset('damped sine', 'exp(-x)*sin(2*pi*x)'),
    _PlotPreset('x²/2-cos(x)', 'x^2/2-cos(x)'),
    _PlotPreset('factorial', 'x!'),
    _PlotPreset('floor(x)', 'floor(x)'),
    _PlotPreset('ceil(x)', 'ceil(x)'),
    _PlotPreset('x mod 1', 'x mod 1'),
    _PlotPreset('sin(x) mod 1', 'sin(x) mod 1'),
    _PlotPreset('3D paraboloid', 'x^2+y^2'),
    _PlotPreset('3D wave', 'sin(x)*cos(y)'),
    _PlotPreset('3D radial wave', 'sin(sqrt(x^2+y^2))'),
    _PlotPreset('FFT two tones', 'sin(2*pi*x)+0.5*sin(6*pi*x)'),
    _PlotPreset('FFT mixed tones', 'sin(5*x)+cos(10*x)'),
  ],
  'parametric': <_PlotPreset>[
    _PlotPreset('Circle', 'cos(x)', 'sin(x)'),
    _PlotPreset('Ellipse', '2*cos(x)', 'sin(x)'),
    _PlotPreset('Lissajous', 'sin(3*x+pi/2)', 'sin(2*x)'),
    _PlotPreset('Spiral', 'x*cos(x)', 'x*sin(x)', 0, 6 * 3.141592653589793),
    _PlotPreset('Cardioid', '2*cos(x)-cos(2*x)', '2*sin(x)-sin(2*x)'),
    _PlotPreset(
      'Heart',
      '16*sin(x)^3',
      '13*cos(x)-5*cos(2*x)-2*cos(3*x)-cos(4*x)',
    ),
    _PlotPreset('Astroid', '4*cos(x)^3', '4*sin(x)^3'),
    _PlotPreset('Hypotrochoid', '2*cos(x)+cos(2*x)', '2*sin(x)-sin(2*x)'),
    _PlotPreset(
      'Butterfly seed',
      'sin(x)*(exp(cos(x))-2*cos(4*x)-sin(x/12)^5)',
      'cos(x)*(exp(cos(x))-2*cos(4*x)-sin(x/12)^5)',
      0,
      12 * 3.141592653589793,
    ),
    _PlotPreset('Rose', 'cos(4*x)*cos(x)', 'cos(4*x)*sin(x)'),
  ],
  'polar': <_PlotPreset>[
    _PlotPreset('Circle', '1', null),
    _PlotPreset('Cardioid', '1+cos(x)', null),
    _PlotPreset('Rose 3', 'cos(3*x)', null),
    _PlotPreset('Rose 4', 'sin(4*x)', null),
    _PlotPreset('Clover', 'cos(2*x)', null),
    _PlotPreset('Spiral', 'x/(2*pi)', null, 0, 6 * 3.141592653589793),
    _PlotPreset('Archimedean spiral', 'x', null, 0, 6 * 3.141592653589793),
    _PlotPreset('Lemniscate', 'sqrt(abs(cos(2*x)))', null),
    _PlotPreset('Limacon', '1+0.5*cos(x)', null),
    _PlotPreset('Conchoid seed', '1/cos(x)', null),
    _PlotPreset('Butterfly', 'exp(sin(x))-2*cos(4*x)+sin((2*x-pi)/24)^5', null),
    _PlotPreset('Fermat spiral', 'sqrt(x)', null),
  ],
  'implicit': <_PlotPreset>[
    _PlotPreset('Circle', 'x^2+y^2-4'),
    _PlotPreset('Ellipse', 'x^2/9+y^2/4-1'),
    _PlotPreset('Hyperbola', 'x^2/4-y^2/4-1'),
    _PlotPreset('Parabola', 'y-x^2'),
    _PlotPreset('Saddle', 'x^2-y^2'),
    _PlotPreset('Astroid', 'x^2+y^2-1'),
    _PlotPreset('Lemniscate', '(x^2+y^2)^2-2*(x^2-y^2)'),
    _PlotPreset('Folium seed', 'x^3+y^3-3*x*y'),
  ],
  'surface': <_PlotPreset>[
    _PlotPreset('Paraboloid', 'x^2+y^2'),
    _PlotPreset('Saddle', 'x^2-y^2'),
    _PlotPreset('Gaussian', 'exp(-(x^2+y^2))'),
  ],
  'contour': <_PlotPreset>[
    _PlotPreset('Circle levels', 'x^2+y^2'),
    _PlotPreset('Paraboloid', 'x^2+y^2'),
    _PlotPreset('Saddle', 'x^2-y^2'),
    _PlotPreset('Gaussian', 'exp(-(x^2+y^2))'),
    _PlotPreset('Peaks seed', 'sin(x)*cos(y)'),
  ],
  'direction': <_PlotPreset>[
    _PlotPreset('Exponential growth', 'y'),
    _PlotPreset('Logistic', 'y*(1-y)'),
    _PlotPreset('Damped oscillator', 'y-x'),
    _PlotPreset('Lotka seed', 'x-y'),
    _PlotPreset('Slope field', 'sin(x)+cos(y)'),
    _PlotPreset('Linear field', 'x+y'),
    _PlotPreset('Cubic field', 'x^3-y'),
    _PlotPreset('Van der Pol seed', '(1-y^2)*x-y'),
  ],
  'vector': <_PlotPreset>[
    _PlotPreset('Rotation', '-y', 'x'),
    _PlotPreset('Sink', '-x', '-y'),
    _PlotPreset('Source', 'x', 'y'),
    _PlotPreset('Saddle', 'x', '-y'),
    _PlotPreset('Nonlinear swirl', 'y', '-x+x^3'),
  ],
};

/// Plot modes, in the order they are offered in the mode strip.
const _plotModes = <String>[
  'function',
  'multi',
  'parametric',
  'polar',
  'implicit',
  'surface',
  'contour',
  'direction',
  'vector',
];

IconData _modeIcon(String mode) => switch (mode) {
  'function' => Icons.timeline_rounded,
  'multi' => Icons.multiline_chart_rounded,
  'parametric' => Icons.animation_rounded,
  'polar' => Icons.radar_rounded,
  'implicit' => Icons.gesture_rounded,
  'surface' => Icons.terrain_rounded,
  'contour' => Icons.layers_rounded,
  'direction' => Icons.linear_scale_rounded,
  _ => Icons.explore_rounded,
};

class PlotPage extends ConsumerStatefulWidget {
  const PlotPage({super.key});

  @override
  ConsumerState<PlotPage> createState() => _PlotPageState();
}

class _PlotPageState extends ConsumerState<PlotPage> {
  late final TextEditingController _expressionController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _xController;
  late final TextEditingController _parameterStartController;
  late final TextEditingController _parameterEndController;
  final Map<String, TextEditingController> _parameterControllers =
      <String, TextEditingController>{};
  final GlobalKey<InteractivePlotViewState> _plotViewKey =
      GlobalKey<InteractivePlotViewState>();
  List<String> _curveExpressions = <String>[];
  String? _selectedPreset;
  Map<String, List<_PlotPreset>> _availablePresets = _plotPresets;
  Timer? _autoEvaluateTimer;

  List<String> _splitCurves(String expression) => expression
      .split(RegExp(r'[;\n]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  void _syncParameterControllers(CalculatorState state, List<String> names) {
    final retained = names.toSet();
    final removed = _parameterControllers.keys
        .where((name) => !retained.contains(name))
        .toList(growable: false);
    for (final name in removed) {
      _parameterControllers.remove(name)?.dispose();
    }
    for (final name in names) {
      _parameterControllers.putIfAbsent(
        name,
        () => TextEditingController(
          text: (state.parameters[name] ?? 1).toString(),
        ),
      );
    }
  }

  /// Re-evaluates shortly after typing stops, when the user enabled
  /// auto-evaluation. Keeping it debounced avoids evaluating every keystroke on
  /// slower native backends.
  void _scheduleAutoEvaluate(CalculatorController controller) {
    if (!ref.read(appSettingsProvider).autoEvaluate) return;
    _autoEvaluateTimer?.cancel();
    _autoEvaluateTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      unawaited(controller.evaluate());
    });
  }

  void _addCurve(CalculatorController controller) {
    final expression = _expressionController.text.trim();
    if (expression.isEmpty) return;
    final curves = <String>[..._curveExpressions];
    if (!curves.contains(expression)) curves.add(expression);
    setState(() {
      _curveExpressions = curves;
      _expressionController.clear();
    });
    controller.setExpression(curves.join(';'));
    unawaited(controller.evaluate());
  }

  Future<void> _openQuickInput({
    required TextEditingController target,
    required ValueChanged<String> onChanged,
    required VoidCallback onSubmit,
  }) async {
    final layout = ref.read(appSettingsProvider).quickPanelLayout;
    await QuickInputPanel.show(
      context: context,
      target: target,
      onChanged: onChanged,
      onSubmit: onSubmit,
      layout: layout,
    );
  }

  void _removeCurve(String expression, CalculatorController controller) {
    final curves = <String>[..._curveExpressions]..remove(expression);
    setState(() => _curveExpressions = curves);
    controller.setExpression(curves.join(';'));
    unawaited(controller.evaluate());
  }

  void _updateParameterRange(CalculatorController controller) {
    final start = double.tryParse(_parameterStartController.text.trim());
    final end = double.tryParse(_parameterEndController.text.trim());
    if (start != null && end != null) {
      controller.setParameterRange(start, end);
    }
  }

  Future<void> _clearForm(CalculatorController controller) async {
    final settings = ref.read(appSettingsProvider);
    final current = ref.read(calculatorControllerProvider);
    if (settings.confirmReset && current.hasCurve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          icon: const Icon(Icons.restart_alt_rounded),
          title: Text(nextEraText(dialogContext, 'Clear the plot?', '清空绘图？')),
          content: Text(
            nextEraText(
              dialogContext,
              'The current expression, curves and markers will be reset.',
              '当前的表达式、曲线与标记都会被重置。',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(nextEraText(dialogContext, 'Keep', '保留')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(nextEraText(dialogContext, 'Reset', '重置')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    controller.clear();
    for (final parameterController in _parameterControllers.values) {
      parameterController.dispose();
    }
    if (!mounted) return;
    setState(() {
      _curveExpressions = <String>[];
      _selectedPreset = null;
      _expressionController.text = 'sin(x)';
      _secondaryController.text = 'cos(x)';
      _xController.text = '0';
      _parameterStartController.text = '0.0';
      _parameterEndController.text = (2 * math.pi).toString();
      _parameterControllers.clear();
    });
    _plotViewKey.currentState?.resetView();
  }

  void _resetPlotView() {
    _plotViewKey.currentState?.resetView();
  }

  void _openFullscreenPlot() {
    final view = _plotViewKey.currentState;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlotFullscreenPage(
          initialViewport: view?.viewport,
          initialZoom: view?.zoom ?? 1,
          initialPan: view?.pan ?? Offset.zero,
          initialYaw: view?.yaw ?? -.65,
          initialPitch: view?.pitch ?? .55,
        ),
      ),
    );
  }

  void _applyPreset(_PlotPreset preset, CalculatorController controller) {
    _expressionController.text = preset.expression;
    controller.setExpression(preset.expression);
    if (preset.secondary != null) {
      _secondaryController.text = preset.secondary!;
      controller.setSecondaryExpression(preset.secondary!);
    }
    _parameterStartController.text = preset.start.toString();
    _parameterEndController.text = preset.end.toString();
    controller.setParameterRange(preset.start, preset.end);
    setState(() => _selectedPreset = preset.label);
    unawaited(controller.evaluate());
  }

  @override
  void initState() {
    super.initState();
    final initial = ref.read(calculatorControllerProvider);
    _expressionController = TextEditingController(text: initial.expression);
    _secondaryController = TextEditingController(
      text: initial.secondaryExpression,
    );
    _xController = TextEditingController(text: initial.xText);
    _parameterStartController = TextEditingController(
      text: initial.parameterStart.toString(),
    );
    _parameterEndController = TextEditingController(
      text: initial.parameterEnd.toString(),
    );
    _loadPresetCatalog();
    // The page opens with a usable default expression; sampling it immediately
    // avoids an empty canvas on the first visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(calculatorControllerProvider);
      if (current.hasCurve || current.isCalculating) return;
      unawaited(ref.read(calculatorControllerProvider.notifier).evaluate());
    });
  }

  Future<void> _loadPresetCatalog() async {
    try {
      final definitions = await PresetCatalog.load();
      final loaded = <String, List<_PlotPreset>>{};
      for (final entry in definitions.entries) {
        loaded[entry.key] = entry.value
            .map(
              (preset) => _PlotPreset(
                preset.label,
                preset.expression,
                preset.secondary,
                preset.start,
                preset.end,
              ),
            )
            .toList(growable: false);
      }
      if (mounted && loaded.isNotEmpty) {
        setState(() => _availablePresets = loaded);
      }
    } on FormatException {
      // The checked-in fallback keeps the plot page usable if an asset is
      // unavailable in a restricted embedding or during a partial install.
    } on FlutterError {
      // Same compatibility fallback for a missing asset bundle.
    }
  }

  @override
  void dispose() {
    _autoEvaluateTimer?.cancel();
    _expressionController.dispose();
    _secondaryController.dispose();
    _xController.dispose();
    _parameterStartController.dispose();
    _parameterEndController.dispose();
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _expressionLabel(BuildContext context, String mode) {
    return switch (mode) {
      'parametric' => nextEraText(context, 'x(t)', 'x(t)'),
      'polar' => nextEraText(context, 'r(t)', 'r(t)'),
      'implicit' || 'surface' || 'contour' || 'direction' => nextEraText(
        context,
        'f(x, y)',
        'f(x, y)',
      ),
      'vector' => nextEraText(context, 'P(x, y)', 'P(x, y)'),
      _ => AppLocalizations.of(context).expression,
    };
  }

  String? _hintForMode(String mode) => switch (mode) {
    'parametric' => 'cos(x)',
    'polar' => '1 + cos(x)',
    'implicit' => 'x^2 + y^2 - 4',
    'surface' || 'contour' => 'x^2 + y^2',
    'direction' => 'y * (1 - y)',
    'vector' => '-y',
    _ => 'sin(x)',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = SuperCalcDesignTokens.of(context);
    final settings = ref.watch(appSettingsProvider);
    final state = ref.watch(calculatorControllerProvider);
    final controller = ref.read(calculatorControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final presets = _availablePresets[state.mode] ?? const <_PlotPreset>[];
    final parameterNames = controller.parameterNames(
      expression: state.expression,
      secondary: state.mode == 'parametric' || state.mode == 'vector'
          ? state.secondaryExpression
          : '',
    );
    _syncParameterControllers(state, parameterNames);
    final screen = MediaQuery.sizeOf(context);
    final plotHeight = (screen.height * .44).clamp(240.0, 560.0).toDouble();
    final totalCount = state.points.length;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ModeStrip(
          mode: state.mode,
          onChanged: (String value) {
            final curves = value == 'multi'
                ? (_splitCurves(state.expression).isEmpty
                      ? <String>[state.expression.trim()]
                      : _splitCurves(state.expression))
                : _curveExpressions;
            final expressionForMode = value == 'multi'
                ? curves.join(';')
                : state.mode == 'multi' && curves.isNotEmpty
                ? curves.first
                : state.expression;
            setState(() {
              _selectedPreset = null;
              if (value == 'multi') {
                _curveExpressions = curves;
                _expressionController.clear();
              } else {
                _curveExpressions = <String>[];
                _expressionController.text = expressionForMode;
              }
            });
            controller.setMode(value);
            controller.setExpression(expressionForMode);
            unawaited(controller.evaluate());
          },
        ),
        SizedBox(height: tokens.cardGap),
        FeatureCard(
          title: nextEraText(context, 'Expression', '表达式'),
          icon: Icons.functions_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (state.mode != 'function' && state.mode != 'multi') ...<
                Widget
              >[
                Text(
                  _expressionLabel(context, state.mode),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (state.mode == 'multi')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final entry in _curveExpressions.asMap().entries)
                      InputChip(
                        avatar: CircleAvatar(
                          radius: 7,
                          backgroundColor: scheme.primary,
                        ),
                        label: Text(entry.value),
                        onDeleted: () => _removeCurve(entry.value, controller),
                      ),
                  ],
                )
              else
                _ExpressionField(
                  controller: _expressionController,
                  hint: _hintForMode(state.mode),
                  onChanged: (String value) {
                    if (state.mode != 'multi') controller.setExpression(value);
                    _scheduleAutoEvaluate(controller);
                  },
                  onSubmitted: controller.evaluate,
                  onQuickInput: () => _openQuickInput(
                    target: _expressionController,
                    onChanged: controller.setExpression,
                    onSubmit: controller.evaluate,
                  ),
                ),
              if (state.mode == 'multi') ...<Widget>[
                const SizedBox(height: 8),
                _ExpressionField(
                  controller: _expressionController,
                  hint: _hintForMode(state.mode),
                  onChanged: (String value) => _scheduleAutoEvaluate(controller),
                  onSubmitted: () => _addCurve(controller),
                  onQuickInput: () => _openQuickInput(
                    target: _expressionController,
                    onChanged: (_) {},
                    onSubmit: () => _addCurve(controller),
                  ),
                  trailing: IconButton.filledTonal(
                    tooltip: nextEraText(context, 'Add curve', '添加曲线'),
                    onPressed: () => _addCurve(controller),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
              if (state.mode == 'parametric' || state.mode == 'vector') ...<
                Widget
              >[
                const SizedBox(height: 10),
                _ExpressionField(
                  controller: _secondaryController,
                  hint: 'sin(x)',
                  label: nextEraText(context, 'y(t)', 'y(t)'),
                  onChanged: controller.setSecondaryExpression,
                  onSubmitted: controller.evaluate,
                  onQuickInput: () => _openQuickInput(
                    target: _secondaryController,
                    onChanged: controller.setSecondaryExpression,
                    onSubmit: controller.evaluate,
                  ),
                ),
              ],
              if (parameterNames.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                SectionHeader(
                  title: nextEraText(context, 'Free parameters', '自由参数'),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: tokens.controlGap,
                  runSpacing: tokens.controlGap,
                  children: <Widget>[
                    for (final name in parameterNames)
                      SizedBox(
                        width: 148,
                        child: TextField(
                          controller: _parameterControllers[name],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          onChanged: (String value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null && parsed.isFinite) {
                              controller.setParameter(name, parsed);
                              _scheduleAutoEvaluate(controller);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: name,
                            isDense: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (state.mode == 'parametric' || state.mode == 'polar') ...<
                Widget
              >[
                const SizedBox(height: 10),
                FormRow(
                  children: <Widget>[
                    TextField(
                      controller: _parameterStartController,
                      onChanged: (_) => _updateParameterRange(controller),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: nextEraText(
                          context,
                          'Parameter start',
                          '参数起点',
                        ),
                        isDense: true,
                      ),
                    ),
                    TextField(
                      controller: _parameterEndController,
                      onChanged: (_) => _updateParameterRange(controller),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: nextEraText(
                          context,
                          'Parameter end',
                          '参数终点',
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ],
              if (state.mode == 'function') ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller: _xController,
                  onChanged: controller.setX,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.argumentX,
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.isCalculating
                          ? null
                          : controller.evaluate,
                      icon: state.isCalculating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_graph_rounded),
                      label: Text(l10n.evaluate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: l10n.clear,
                    onPressed: () => _clearForm(controller),
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.cardGap),
        FeatureCard(
          title: l10n.plotPreview,
          icon: Icons.show_chart_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                label: l10n.accessibilityPlotSummary(totalCount, state.expression),
                child: SizedBox(
                  height: plotHeight,
                  child: PlotSurface(
                    viewKey: _plotViewKey,
                    borderRadius: BorderRadius.circular(tokens.cornerMedium),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  StatusPill(
                    icon: Icons.timeline_rounded,
                    label: state.contours.isNotEmpty
                        ? '${state.contours.length} ${nextEraText(context, 'levels', '条等值线')}'
                        : l10n.plotPoints(totalCount),
                  ),
                  if (state.sampleBudget > 0)
                    StatusPill(
                      icon: Icons.speed_rounded,
                      label: nextEraText(
                        context,
                        '${state.sampleCount}/${state.sampleBudget} samples',
                        '${state.sampleCount}/${state.sampleBudget} 采样点',
                      ),
                    ),
                  if (state.intersectionPoints.isNotEmpty)
                    StatusPill(
                      icon: Icons.radar_rounded,
                      label:
                          '${nextEraText(context, 'Intersections', '交点')}: '
                          '${state.intersectionPoints.length}',
                    ),
                  AppTooltip(
                    message: nextEraText(context, 'Zoom out', '缩小'),
                    child: IconButton.filledTonal(
                      onPressed: () => _plotViewKey.currentState?.zoomBy(1 / 1.25),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                  ),
                  AppTooltip(
                    message: nextEraText(context, 'Zoom in', '放大'),
                    child: IconButton.filledTonal(
                      onPressed: () => _plotViewKey.currentState?.zoomBy(1.25),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                  AppTooltip(
                    message: nextEraText(context, 'Fit to curve', '适配曲线'),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        final fit = state.suggestedViewport;
                        if (fit != null) {
                          _plotViewKey.currentState?.setViewport(fit);
                        } else {
                          _resetPlotView();
                        }
                      },
                      icon: const Icon(Icons.fit_screen_rounded),
                    ),
                  ),
                  AppTooltip(
                    message: nextEraText(context, 'Reset view', '重置视图'),
                    child: IconButton.filledTonal(
                      onPressed: _resetPlotView,
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openFullscreenPlot,
                    icon: const Icon(Icons.fullscreen_rounded),
                    label: Text(nextEraText(context, 'Full screen', '全屏')),
                  ),
                  if (state.mode == 'multi')
                    TextButton.icon(
                      onPressed: state.isCalculating
                          ? null
                          : controller.findIntersections,
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(
                        nextEraText(context, 'Find intersections', '查找交点'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                nextEraText(
                  context,
                  'Drag to pan, pinch or scroll to zoom. '
                      '${settings.tapToMark ? 'Tap to add a marker; long press to remove one. ' : ''}'
                      'The curve is re-sampled for the visible range when auto-resampling is on.',
                  '拖动画布平移，双指缩放或滚动滚轮缩放。'
                      '${settings.tapToMark ? '点击添加标记，长按删除最近的标记。' : ''}'
                      '开启“平移重采样”后，曲线会按可见范围重新采样。',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.cardGap),
        ResultCard(
          label: l10n.result,
          value: state.isCalculating
              ? l10n.computing
              : state.error ??
                    (state.value == null
                        ? l10n.noResult
                        : formatNumber(
                            state.value!,
                            precision: settings.numberPrecision.digits,
                          )),
          error: state.error,
          onCopy: state.value == null
              ? null
              : () => copyToClipboard(
                  context,
                  formatNumber(
                    state.value!,
                    precision: settings.numberPrecision.digits,
                  ),
                ),
        ),
        SizedBox(height: tokens.cardGap),
        if (presets.isNotEmpty)
          FeatureCard(
            title: nextEraText(context, 'Presets', '预设'),
            icon: Icons.auto_awesome_rounded,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final preset in presets)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: _selectedPreset == preset.label,
                    onSelected: (_) => _applyPreset(preset, controller),
                  ),
              ],
            ),
          ),
        SizedBox(height: tokens.cardGap),
        if (state.markedPoints.isNotEmpty)
          FeatureCard(
            title: nextEraText(context, 'Markers', '标记'),
            icon: Icons.place_rounded,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final entry in state.markedPoints.asMap().entries)
                  Chip(
                    label: Text(
                      'M${entry.key + 1}: '
                      '(${entry.value.x.toStringAsPrecision(6)}, '
                      '${entry.value.y.toStringAsPrecision(6)})',
                    ),
                    onDeleted: () => controller.removeNearestMarkedPoint(
                      entry.value,
                      tolerance: double.infinity,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
          _openQuickInput(
            target: _expressionController,
            onChanged: (String value) {
              if (state.mode != 'multi') controller.setExpression(value);
            },
            onSubmit: state.mode == 'multi'
                ? () => _addCurve(controller)
                : controller.evaluate,
          ),
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
          _openQuickInput(
            target: _expressionController,
            onChanged: (String value) {
              if (state.mode != 'multi') controller.setExpression(value);
            },
            onSubmit: state.mode == 'multi'
                ? () => _addCurve(controller)
                : controller.evaluate,
          ),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          controller.evaluate,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true):
          controller.evaluate,
      const SingleActivator(LogicalKeyboardKey.keyR, control: true):
          _resetPlotView,
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
          _plotViewKey.currentState?.zoomBy(1.25),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
          _plotViewKey.currentState?.zoomBy(1 / 1.25),
    };

    final page = FeaturePageFrame(
      title: l10n.plotting,
      icon: Icons.insights_rounded,
      subtitle: nextEraText(
        context,
        'Nine plot modes with adaptive sampling, complete curves and the same interaction on touch, mouse and keyboard.',
        '九种绘图模式，自适应采样与完整曲线；触控、鼠标与键盘拥有一致交互。',
      ),
      child: body,
    );

    if (!settings.keyboardShortcuts) return page;
    return CallbackShortcuts(bindings: shortcuts, child: page);
  }
}

/// Horizontally scrollable mode selector.
///
/// Nine modes do not fit a `SegmentedButton` on a phone, and the adaptive
/// Material 3 Expressive chips keep every mode one tap away with a visible icon
/// instead of hiding them behind an overflow menu.
class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = <String, String>{
      'function': nextEraText(context, 'y = f(x)', 'y = f(x)'),
      'multi': nextEraText(context, 'Multi-curve', '多曲线'),
      'parametric': nextEraText(context, 'Parametric', '参数曲线'),
      'polar': nextEraText(context, 'Polar', '极坐标'),
      'implicit': nextEraText(context, 'Implicit', '隐式曲线'),
      'surface': nextEraText(context, '3D surface', '三维曲面'),
      'contour': nextEraText(context, 'Contour', '等高线'),
      'direction': nextEraText(context, 'Direction field', '方向场'),
      'vector': nextEraText(context, 'Vector field', '向量场'),
    };
    final chips = <Widget>[
      for (final value in _plotModes)
        ChoiceChip(
          avatar: Icon(
            _modeIcon(value),
            size: 18,
            color: value == mode
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          label: Text(labels[value] ?? value),
          selected: value == mode,
          showCheckmark: false,
          onSelected: (_) => onChanged(value),
        ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Wide windows show every mode at once; narrow ones scroll instead of
        // wrapping into a tall stack that pushes the plot off-screen.
        if (constraints.maxWidth >= 900) {
          return Wrap(spacing: 8, runSpacing: 8, children: chips);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: <Widget>[
              for (final chip in chips) ...<Widget>[chip, const SizedBox(width: 8)],
            ],
          ),
        );
      },
    );
  }
}

/// Monospace expression field with a quick-input affordance.
class _ExpressionField extends StatelessWidget {
  const _ExpressionField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onQuickInput,
    this.hint,
    this.label,
    this.trailing,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onQuickInput;
  final String? hint;
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: nextEraText(context, 'Quick input', '快捷输入'),
              onPressed: onQuickInput,
              icon: const Icon(Icons.dialpad_rounded),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
