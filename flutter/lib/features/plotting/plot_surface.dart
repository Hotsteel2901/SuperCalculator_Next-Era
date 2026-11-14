import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/monet.dart';
import '../../core/plot/interactive_plot_view.dart';
import '../../core/plot/plot_viewport.dart';
import '../../core/settings/app_settings.dart';
import 'calculator_controller.dart';

/// Settings-aware plot surface.
///
/// Both the inline preview and the full-screen page embed this widget, so every
/// plotting preference (stroke width, grid, tick labels, background, draw-in
/// animation, tap-to-mark, double-tap zoom, haptics) and the auto-resample
/// handshake with the controller live in exactly one place.
class PlotSurface extends ConsumerWidget {
  const PlotSurface({
    required this.viewKey,
    this.borderRadius,
    this.initialViewport,
    this.initialZoom = 1,
    this.initialPan = Offset.zero,
    this.initialYaw = -.65,
    this.initialPitch = .55,
    super.key,
  });

  final GlobalKey<InteractivePlotViewState> viewKey;
  final BorderRadius? borderRadius;
  final PlotViewport? initialViewport;
  final double initialZoom;
  final Offset initialPan;
  final double initialYaw;
  final double initialPitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final state = ref.watch(calculatorControllerProvider);
    final controller = ref.read(calculatorControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final platformReduceMotion = MediaQuery.disableAnimationsOf(context);
    final reduceMotion = settings.shouldReduceMotion(platformReduceMotion);

    // A freshly sampled curve reports the range that fits it; applying it once,
    // after the frame, keeps parametric circles round and asymptotic curves
    // inside the canvas instead of off-screen.
    ref.listen<PlotViewport?>(
      calculatorControllerProvider.select(
        (CalculatorState value) => value.suggestedViewport,
      ),
      (PlotViewport? previous, PlotViewport? next) {
        if (next == null || !next.isValid) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewKey.currentState?.setViewport(next);
        });
      },
    );

    return InteractivePlotView(
      key: viewKey,
      points: state.points,
      mode: state.mode,
      scheme: scheme,
      contours: state.contours,
      intersectionPoints: state.intersectionPoints,
      markedPoints: state.markedPoints,
      onMarkPoint: controller.addMarkedPoint,
      onRemoveMarkPoint: (point) =>
          controller.removeNearestMarkedPoint(point),
      borderRadius: borderRadius,
      initialViewport: initialViewport,
      initialZoom: initialZoom,
      initialPan: initialPan,
      initialYaw: initialYaw,
      initialPitch: initialPitch,
      strokeWidth: settings.curveThickness,
      showGrid: settings.showGrid,
      showAxisLabels: settings.showAxisLabels,
      background: settings.plotBackground,
      animateDraw: settings.animatePlotDraw,
      reduceMotion: reduceMotion,
      motionScale: settings.motionSpeed.scale,
      tapToMark: settings.tapToMark,
      doubleTapZoom: settings.doubleTapZoom,
      haptics: settings.haptics,
      // Shapes that are round in data space (implicit rings, polar roses,
      // parametric circles) must not be stretched into ellipses by a wide
      // window.
      lockAspect:
          state.mode == 'implicit' ||
          state.mode == 'contour' ||
          state.mode == 'parametric' ||
          state.mode == 'polar',
      palette: PlotPalette.fromScheme(scheme).colors,
      onViewportChanged: (PlotViewport viewport) =>
          controller.syncSamplingRange(viewport),
    );
  }
}
