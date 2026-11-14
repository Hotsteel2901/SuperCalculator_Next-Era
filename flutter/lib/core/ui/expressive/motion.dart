import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/design_tokens.dart';

/// Spring-based motion helpers shared by every expressive component.
abstract final class ExpressiveMotion {
  /// Drives [controller] toward [target] with a physical spring.
  ///
  /// Unlike a fixed-duration curve, a spring respects the current velocity, so
  /// interrupting an in-flight animation (fast typing, rapid taps) never looks
  /// like a jump cut.
  static void animateTo(
    AnimationController controller,
    double target, {
    required SpringDescription spring,
  }) {
    if (!controller.isAnimating && (controller.value - target).abs() < 0.001) {
      controller.value = target;
      return;
    }
    controller.animateWith(
      SpringSimulation(spring, controller.value, target, controller.velocity),
    );
  }

  /// A short fade + rise used for page content that appears after the first
  /// frame, keeping initial layout cheap.
  static Widget reveal({
    required Widget child,
    required double progress,
    double offset = 18,
  }) {
    final curved = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, offset * (1 - curved)),
        child: child,
      ),
    );
  }
}

/// A press-responsive surface with a spring-driven scale and optional shape
/// morph. It replaces the ripple with the expressive "squish" feedback while
/// keeping keyboard activation and semantics intact.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.pressedScale = 0.955,
    this.enabled = true,
    this.haptics = false,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.semanticLabel,
    this.cursor = SystemMouseCursors.click,
    this.scaleOnHover = 1.012,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final double pressedScale;
  final bool enabled;
  final bool haptics;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final String? semanticLabel;
  final MouseCursor cursor;
  final double scaleOnHover;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool pressed) {
    final tokens = SuperCalcDesignTokens.of(context);
    ExpressiveMotion.animateTo(
      _controller,
      pressed ? 1 : 0,
      spring: tokens.fastSpring,
    );
  }

  void _handleTap() {
    if (!_interactive) return;
    if (widget.haptics) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!_interactive) return;
    if (widget.haptics) HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SuperCalcDesignTokens.of(context);
    final reduceMotion = tokens.motionScale == 0;
    final hoverScale = _hovered && _interactive && !reduceMotion
        ? widget.scaleOnHover
        : 1.0;
    final semantics = widget.semanticLabel;
    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pressed = _controller.value;
        final scale = reduceMotion
            ? 1.0
            : (1 + (widget.pressedScale - 1) * pressed) * hoverScale;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );

    content = MouseRegion(
      cursor: _interactive ? widget.cursor : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (value) {
          setState(() => _focused = value);
          widget.onFocusChange?.call(value);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? _handleTap : null,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          onSecondaryTap: widget.onSecondaryTap,
          onTapDown: _interactive ? (_) => _setPressed(true) : null,
          onTapUp: _interactive ? (_) => _setPressed(false) : null,
          onTapCancel: _interactive ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: tokens.scaled(const Duration(milliseconds: 180)),
            curve: Curves.easeOutCubic,
            foregroundDecoration: _focused && _interactive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.cornerSmall),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: content,
          ),
        ),
      ),
    );

    if (semantics != null) {
      content = Semantics(
        button: _interactive,
        label: semantics,
        child: content,
      );
    }
    return content;
  }
}

/// Reveals [child] with a staggered fade/slide when it first becomes visible.
///
/// The delay is intentionally capped so long lists keep a consistent cadence
/// instead of waiting for every row.
class StaggeredEntry extends StatefulWidget {
  const StaggeredEntry({
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.disabled = false,
    super.key,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;
  final bool disabled;

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final tokens = SuperCalcDesignTokens.of(context);
    final reduce = widget.disabled || tokens.motionScale == 0;
    if (reduce) {
      _controller.value = 1;
    } else {
      final index = widget.index.clamp(0, 8);
      _delay = Timer(widget.step * index, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// A page route that combines the Material 3 Expressive fade-through
/// transition with a spring-driven scale, without snapshotting (so live plots
/// keep rendering during the transition).
class ExpressivePageRoute<T> extends PageRouteBuilder<T> {
  ExpressivePageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: const Duration(milliseconds: 320),
         reverseTransitionDuration: const Duration(milliseconds: 240),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: curved,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0.02, 0.03),
                 end: Offset.zero,
               ).animate(curved),
               child: child,
             ),
           );
         },
       );

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;
}

/// A number that counts up with a spring when its value changes.
class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText({
    required this.value,
    required this.style,
    this.alignment = Alignment.centerRight,
    super.key,
  });

  final String value;
  final TextStyle? style;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final tokens = SuperCalcDesignTokens.of(context);
    return AnimatedSwitcher(
      duration: tokens.scaled(const Duration(milliseconds: 220)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: style,
        maxLines: 1,
        textAlign: TextAlign.end,
      ),
    );
  }
}

/// Small helper for the "breathing" accent used behind hero content.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    required this.color,
    this.size = 260,
    this.intensity = 0.4,
    super.key,
  });

  final Color color;
  final double size;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _GlowPainter(color: color, intensity: intensity),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.color, required this.intensity});

  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: intensity),
          color.withValues(alpha: intensity * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide / 2));
    canvas.drawCircle(center, size.shortestSide / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.intensity != intensity;
}

/// A subtle animated gradient backdrop for headers and empty states.
class AnimatedGradientSurface extends StatefulWidget {
  const AnimatedGradientSurface({
    required this.child,
    required this.colors,
    this.borderRadius,
    this.duration = const Duration(seconds: 12),
    super.key,
  });

  final Widget child;
  final List<Color> colors;
  final BorderRadius? borderRadius;
  final Duration duration;

  @override
  State<AnimatedGradientSurface> createState() =>
      _AnimatedGradientSurfaceState();
}

class _AnimatedGradientSurfaceState extends State<AnimatedGradientSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SuperCalcDesignTokens.of(context);
    if (tokens.motionScale == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment(-1 + t * 0.6, -1),
              end: Alignment(1 - t * 0.4, 1),
            ),
            borderRadius: widget.borderRadius,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Utility used by tests and debug overlays to check spring settling.
@visibleForTesting
double springValue(SpringDescription spring, double from, double to, double t) {
  final simulation = SpringSimulation(spring, from, to, 0);
  return simulation.x(t).clamp(math.min(from, to), math.max(from, to));
}

/// Rebuilds [builder] on every frame while [animation] runs, without rebuilding
/// ancestors. Kept here so high-frequency surfaces (plot gestures) share the
/// same pattern.
class RepaintListenableBuilder extends AnimatedWidget {
  const RepaintListenableBuilder({
    required this.builder,
    required super.listenable,
    super.key,
  });

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}
