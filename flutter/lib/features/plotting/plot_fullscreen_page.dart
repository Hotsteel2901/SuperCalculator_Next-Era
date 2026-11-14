import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../core/plot/interactive_plot_view.dart';
import '../../core/plot/plot_viewport.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/feature_widgets.dart';
import 'calculator_controller.dart';
import 'plot_surface.dart';

/// Secondary, immersive plot page.
///
/// Mirrors the native full-screen plot activity: the inline preview stays in
/// the scrollable form, and this page is opened explicitly to enlarge the plot
/// and keep interacting with it (markers, pinch zoom, pan, 3D rotation).
///
/// It embeds the same [PlotSurface] as the inline preview, so zooming in here
/// never loses the settings-driven behaviour (grid, stroke width, draw-in
/// animation, auto-resampling) or the marker interactions.
class PlotFullscreenPage extends ConsumerStatefulWidget {
  const PlotFullscreenPage({
    super.key,
    this.initialViewport,
    this.initialZoom = 1,
    this.initialPan = Offset.zero,
    this.initialYaw = -.65,
    this.initialPitch = .55,
  });

  final PlotViewport? initialViewport;
  final double initialZoom;
  final Offset initialPan;
  final double initialYaw;
  final double initialPitch;

  @override
  ConsumerState<PlotFullscreenPage> createState() => _PlotFullscreenPageState();
}

class _PlotFullscreenPageState extends ConsumerState<PlotFullscreenPage> {
  final GlobalKey<InteractivePlotViewState> _viewKey =
      GlobalKey<InteractivePlotViewState>();
  bool _showDetails = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(nextEraText(context, 'Full-screen plot', '全屏绘图')),
        actions: <Widget>[
          AppTooltip(
            message: nextEraText(
              context,
              _showDetails ? 'Hide details' : 'Show details',
              _showDetails ? '隐藏信息' : '显示信息',
            ),
            child: IconButton(
              onPressed: () => setState(() => _showDetails = !_showDetails),
              icon: Icon(
                _showDetails
                    ? Icons.info_outline_rounded
                    : Icons.info_rounded,
              ),
            ),
          ),
          IconButton(
            tooltip: nextEraText(context, 'Zoom out', '缩小'),
            onPressed: () => _viewKey.currentState?.zoomBy(1 / 1.25),
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            tooltip: nextEraText(context, 'Zoom in', '放大'),
            onPressed: () => _viewKey.currentState?.zoomBy(1.25),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: nextEraText(context, 'Reset view', '重置视图'),
            onPressed: () => _viewKey.currentState?.resetView(),
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.pagePadding / 2),
          child: Column(
            children: <Widget>[
              Expanded(
                child: PlotSurface(
                  viewKey: _viewKey,
                  borderRadius: BorderRadius.circular(tokens.cornerLarge),
                  initialViewport: widget.initialViewport,
                  initialZoom: widget.initialZoom,
                  initialPan: widget.initialPan,
                  initialYaw: widget.initialYaw,
                  initialPitch: widget.initialPitch,
                ),
              ),
              if (_showDetails) ...<Widget>[
                SizedBox(height: tokens.controlGap),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    StatusPill(
                      icon: Icons.functions_rounded,
                      label: state.mode,
                    ),
                    StatusPill(
                      icon: Icons.timeline_rounded,
                      label: state.contours.isNotEmpty
                          ? '${state.contours.length} ${nextEraText(context, 'levels', '条等值线')}'
                          : nextEraText(
                              context,
                              '${state.sampleCount} samples',
                              '${state.sampleCount} 采样点',
                            ),
                    ),
                    StatusPill(
                      icon: Icons.texture_rounded,
                      label: nextEraText(
                        context,
                        '${_resolutionLabel(context, settings.plotResolution)} · '
                            '${_meshLabel(context, settings.meshDensity)} mesh',
                        '${_resolutionLabel(context, settings.plotResolution)} · '
                            '${_meshLabel(context, settings.meshDensity)}网格',
                      ),
                    ),
                    StatusPill(
                      icon: Icons.place_rounded,
                      label:
                          '${nextEraText(context, 'Markers', '标记')}: '
                          '${state.markedPoints.length}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _resolutionLabel(BuildContext context, PlotResolution value) =>
    switch (value) {
      PlotResolution.adaptive => nextEraText(context, 'Adaptive', '自适应'),
      PlotResolution.balanced => nextEraText(context, 'Balanced', '均衡'),
      PlotResolution.high => nextEraText(context, 'High', '高'),
      PlotResolution.ultra => nextEraText(context, 'Ultra', '超高'),
    };

String _meshLabel(BuildContext context, MeshDensity value) =>
    switch (value) {
      MeshDensity.low => nextEraText(context, 'Low', '低密度'),
      MeshDensity.medium => nextEraText(context, 'Medium', '中密度'),
      MeshDensity.high => nextEraText(context, 'High', '高密度'),
    };
