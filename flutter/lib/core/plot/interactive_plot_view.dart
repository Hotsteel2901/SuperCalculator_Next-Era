import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../settings/app_settings.dart';
import 'function_plot_painter.dart';
import 'marching_squares.dart';
import 'plot_point.dart';
import 'plot_viewport.dart';

/// Interactive, self-clipping plot surface shared by the inline preview and the
/// full-screen plot page.
///
/// A two-dimensional drag updates the visible data-coordinate range instead of
/// sliding a finite grid bitmap. The painter then lays out fresh grid lines and
/// tick labels across the whole viewport, just as the native chart does.
///
/// Every interaction is optional so the same widget serves a read-only preview
/// and a full editor without branching in the call sites: `tapToMark`,
/// `doubleTapZoom` and the draw-in animation all come from the user settings.
class InteractivePlotView extends StatefulWidget {
  const InteractivePlotView({
    required this.points,
    required this.mode,
    required this.scheme,
    this.intersectionPoints = const <PlotPoint>[],
    this.markedPoints = const <PlotPoint>[],
    this.onMarkPoint,
    this.onRemoveMarkPoint,
    this.borderRadius,
    this.initialViewport,
    this.initialZoom = 1,
    this.initialPan = Offset.zero,
    this.initialYaw = -.65,
    this.initialPitch = .55,
    this.contours = const <ContourLevel>[],
    this.strokeWidth = 2.4,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.background = PlotBackgroundStyle.surface,
    this.animateDraw = true,
    this.reduceMotion = false,
    this.motionScale = 1,
    this.tapToMark = true,
    this.doubleTapZoom = true,
    this.haptics = true,
    this.lockAspect = false,
    this.onViewportChanged,
    this.palette,
    super.key,
  });

  final List<PlotPoint> points;
  final String mode;
  final ColorScheme scheme;
  final List<PlotPoint> intersectionPoints;
  final List<PlotPoint> markedPoints;
  final ValueChanged<PlotPoint>? onMarkPoint;
  final ValueChanged<PlotPoint>? onRemoveMarkPoint;
  final BorderRadius? borderRadius;

  /// Initial 2D data range, also used to transfer the inline view to fullscreen.
  final PlotViewport? initialViewport;

  /// Initial camera values for the projected 3D surface mode.
  final double initialZoom;
  final Offset initialPan;
  final double initialYaw;
  final double initialPitch;

  /// Pre-computed iso-lines for implicit and contour plots.
  final List<ContourLevel> contours;

  /// Curve stroke width in logical pixels.
  final double strokeWidth;

  /// Whether grid lines are painted.
  final bool showGrid;

  /// Whether numeric tick labels are painted.
  final bool showAxisLabels;

  /// Plot background treatment.
  final PlotBackgroundStyle background;

  /// Whether a freshly sampled curve is revealed with a draw-in animation.
  final bool animateDraw;

  /// Disables the draw-in animation and haptics when the platform asks for it.
  final bool reduceMotion;

  /// Motion multiplier from the motion-speed setting.
  final double motionScale;

  /// Whether tapping adds a coordinate marker.
  final bool tapToMark;

  /// Whether double tapping zooms.
  final bool doubleTapZoom;

  /// Whether gesture feedback uses haptic pulses.
  final bool haptics;

  /// Keeps one data unit the same length on both axes.
  ///
  /// Curves that are circular in data space (implicit rings, polar roses,
  /// parametric circles) would otherwise be drawn as ellipses whenever the plot
  /// area is not square.
  final bool lockAspect;

  /// Reports the visible range after a pan or zoom settles, so the caller can
  /// resample the curve for the new domain.
  final ValueChanged<PlotViewport>? onViewportChanged;

  /// Optional curve palette.
  final List<Color>? palette;

  @override
  State<InteractivePlotView> createState() => InteractivePlotViewState();
}

class InteractivePlotViewState extends State<InteractivePlotView>
    with SingleTickerProviderStateMixin {
  late double _zoom = widget.initialZoom;
  late Offset _pan = widget.initialPan;
  late double _yaw = widget.initialYaw;
  late double _pitch = widget.initialPitch;
  late PlotViewport _viewport = _startingViewport;
  double _gestureZoomStart = 1;
  Offset _gestureFocalStart = Offset.zero;
  Offset _doubleTapFocalPoint = Offset.zero;
  late double _gestureYawStart = widget.initialYaw;
  late double _gesturePitchStart = widget.initialPitch;
  late PlotViewport _gestureViewportStart = _startingViewport;
  Rect _plotRect = Rect.zero;
  Size _aspectSize = Size.zero;
  Timer? _settleTimer;
  Timer? _wheelTimer;
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: _drawDuration,
    value: 1,
  );

  Duration get _drawDuration {
    final scale = widget.motionScale <= 0 ? 1.0 : widget.motionScale;
    final milliseconds = (560 / scale).round().clamp(180, 1400);
    return Duration(milliseconds: milliseconds);
  }

  PlotViewport get _startingViewport {
    final candidate = widget.initialViewport;
    return candidate != null && candidate.isValid
        ? candidate
        : PlotViewport.initial;
  }

  /// Current horizontal/vertical translation for the projected 3D surface.
  Offset get pan => _pan;

  /// Current camera zoom for the projected 3D surface.
  ///
  /// In 2D mode this reports the zoom relative to the standard 20-unit range.
  double get zoom => widget.mode == 'surface'
      ? _zoom
      : (PlotViewport.initial.xSpan / _viewport.xSpan);

  /// Current 2D visible data-coordinate bounds.
  PlotViewport get viewport => _viewport;

  /// Current 3D surface yaw.
  double get yaw => _yaw;

  /// Current 3D surface pitch.
  double get pitch => _pitch;

  @override
  void initState() {
    super.initState();
    _startDrawAnimation();
  }

  @override
  void didUpdateWidget(covariant InteractivePlotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameCurve =
        identical(oldWidget.points, widget.points) &&
        identical(oldWidget.contours, widget.contours);
    if (!sameCurve) _startDrawAnimation();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _wheelTimer?.cancel();
    _draw.dispose();
    super.dispose();
  }

  void _startDrawAnimation() {
    final hasContent = widget.points.isNotEmpty || widget.contours.isNotEmpty;
    if (!widget.animateDraw || widget.reduceMotion || !hasContent) {
      _draw.value = 1;
      return;
    }
    _draw.duration = _drawDuration;
    _draw
      ..stop()
      ..value = 0
      ..forward();
  }

  /// Expands the shorter axis so one data unit covers the same number of pixels
  /// horizontally and vertically. Runs after layout, once per size change.
  void _applyAspectLock(Size size) {
    if (!widget.lockAspect) return;
    final rect = _plotRect;
    if (rect.width <= 1 || rect.height <= 1 || !_viewport.isValid) {
      return;
    }
    final targetYSpan = _viewport.xSpan * rect.height / rect.width;
    if (!targetYSpan.isFinite || targetYSpan <= 0) {
      return;
    }
    if ((targetYSpan - _viewport.ySpan).abs() <= _viewport.ySpan * 0.005) {
      return;
    }
    final centre = (_viewport.yMin + _viewport.yMax) / 2;
    final next = PlotViewport(
      xMin: _viewport.xMin,
      xMax: _viewport.xMax,
      yMin: centre - targetYSpan / 2,
      yMax: centre + targetYSpan / 2,
    );
    if (!next.isValid) return;
    setState(() => _viewport = next);
    _scheduleViewportReport();
  }

  void _pulse() {
    if (widget.haptics && !widget.reduceMotion) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  /// Throttles viewport reporting so a fling or a wheel burst only triggers one
  /// resample after the gesture settles.
  void _scheduleViewportReport() {
    final callback = widget.onViewportChanged;
    if (callback == null) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      callback(_viewport);
    });
  }

  /// Restores the 2D axes or the 3D camera to its standard starting view.
  void resetView() {
    final start = _startingViewport;
    if (_viewport == start &&
        _zoom == widget.initialZoom &&
        _pan == Offset.zero) {
      return;
    }
    setState(() {
      _viewport = start;
      _zoom = widget.initialZoom;
      _pan = widget.initialPan;
      _yaw = widget.initialYaw;
      _pitch = widget.initialPitch;
    });
    _pulse();
    _scheduleViewportReport();
  }

  /// Sets the visible data range, for range dialogs and external controls.
  void setViewport(PlotViewport viewport) {
    if (!viewport.isValid || viewport == _viewport) return;
    setState(() => _viewport = viewport);
  }

  /// Zooms around a local chart position. A null focus zooms around center.
  void zoomBy(double factor, {Offset? focalPoint}) {
    if (!factor.isFinite || factor <= 0) return;
    setState(() {
      if (widget.mode == 'surface') {
        _zoom = (_zoom * factor).clamp(.5, 4.0).toDouble();
      } else {
        _viewport = _viewport.zoomAt(
          factor,
          focalPoint ?? _plotRect.center,
          _plotRect,
        );
      }
    });
    _scheduleViewportReport();
  }

  PlotPoint? _dataPointFromLocal(Offset local) {
    if (!_plotRect.contains(local)) return null;
    return _viewport.screenToData(local, _plotRect);
  }

  void _mark(Offset local) {
    if (widget.mode == 'surface' || !widget.tapToMark) return;
    final callback = widget.onMarkPoint;
    if (callback == null) return;
    final point = _dataPointFromLocal(local);
    if (point != null && point.isFinite) {
      callback(point);
      _pulse();
    }
  }

  void _remove(Offset local) {
    if (widget.mode == 'surface') return;
    final callback = widget.onRemoveMarkPoint;
    if (callback == null) return;
    final point = _dataPointFromLocal(local);
    if (point != null && point.isFinite) {
      callback(point);
      _pulse();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !_plotRect.contains(event.localPosition)) {
      return;
    }

    // Registering at the plot's hit-test position gives it priority over the
    // surrounding scroll view, so a wheel over the graph zooms the graph rather
    // than unexpectedly scrolling the form beneath it.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!mounted || resolved is! PointerScrollEvent) return;
      final delta = resolved.scrollDelta;
      // Trackpad pinch arrives as ctrl-modified scroll; treat it as zoom too.
      final zoomIntent = delta.dy.abs() >= delta.dx.abs();
      if (widget.mode == 'surface' || zoomIntent) {
        final factor = math.exp(-delta.dy * .0015).clamp(.25, 4.0).toDouble();
        zoomBy(factor, focalPoint: resolved.localPosition);
      } else {
        setState(() {
          _viewport = _viewport.panByPixels(Offset(-delta.dx, 0), _plotRect);
        });
        _scheduleViewportReport();
      }
      _wheelTimer?.cancel();
      _wheelTimer = Timer(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        widget.onViewportChanged?.call(_viewport);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _plotRect = PlotLayout.plotRectFor(size);
        if (size != _aspectSize) {
          _aspectSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyAspectLock(size);
          });
        }
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: widget.doubleTapZoom
                ? (details) {
                    _doubleTapFocalPoint = details.localPosition;
                  }
                : null,
            onDoubleTap: widget.doubleTapZoom
                ? () {
                    if (_plotRect.contains(_doubleTapFocalPoint)) {
                      zoomBy(1.5, focalPoint: _doubleTapFocalPoint);
                      _pulse();
                    }
                  }
                : null,
            onTapUp: widget.tapToMark
                ? (details) => _mark(details.localPosition)
                : null,
            onLongPressStart: (details) => _remove(details.localPosition),
            onScaleStart: (details) {
              _gestureZoomStart = _zoom;
              _gestureFocalStart = details.localFocalPoint;
              _gestureYawStart = _yaw;
              _gesturePitchStart = _pitch;
              _gestureViewportStart = _viewport;
            },
            onScaleUpdate: (details) {
              final focalPoint = details.localFocalPoint;
              setState(() {
                if (widget.mode == 'surface') {
                  final delta = focalPoint - _gestureFocalStart;
                  _zoom = (_gestureZoomStart * details.scale)
                      .clamp(.5, 4.0)
                      .toDouble();
                  _yaw = _gestureYawStart + delta.dx * .01;
                  _pitch = (_gesturePitchStart - delta.dy * .01)
                      .clamp(-1.35, 1.35)
                      .toDouble();
                } else {
                  _viewport = _viewport.transformGesture(
                    startViewport: _gestureViewportStart,
                    startFocalPoint: _gestureFocalStart,
                    currentFocalPoint: focalPoint,
                    scale: details.scale,
                    plotRect: _plotRect,
                  );
                }
              });
            },
            onScaleEnd: (details) {
              if (widget.mode != 'surface') _scheduleViewportReport();
            },
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _draw,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: FunctionPlotPainter(
                      points: widget.points,
                      scheme: widget.scheme,
                      mode: widget.mode,
                      intersectionPoints: widget.intersectionPoints,
                      markedPoints: widget.markedPoints,
                      viewport: _viewport,
                      zoom: _zoom,
                      pan: _pan,
                      yaw: _yaw,
                      pitch: _pitch,
                      strokeWidth: widget.strokeWidth,
                      showGrid: widget.showGrid,
                      showTickLabels: widget.showAxisLabels,
                      background: widget.background,
                      contours: widget.contours,
                      progress: _draw.value,
                      palette: widget.palette,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    final radius = widget.borderRadius;
    return radius == null
        ? ClipRect(clipBehavior: Clip.hardEdge, child: surface)
        : ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.hardEdge,
            child: surface,
          );
  }
}
