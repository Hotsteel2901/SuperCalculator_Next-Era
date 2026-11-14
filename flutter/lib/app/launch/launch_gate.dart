import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/squircle_border.dart';

/// Startup animation shown while the first frame settles.
///
/// Google's platform splash (Android 12+ `windowSplashScreenAnimatedIcon`,
/// including the extended APK launch animation on newer releases) hands over to
/// this in-app brand moment. It is deliberately short (≈1 s), skippable on tap,
/// and collapses to a plain fade when the platform asks for reduced motion.
class LaunchGate extends StatefulWidget {
  const LaunchGate({required this.child, this.reduceMotion = false, super.key});

  final Widget child;
  final bool reduceMotion;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> with TickerProviderStateMixin {
  late final AnimationController _mark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _handover;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _mark.value = 1;
      _handover = Timer(const Duration(milliseconds: 180), _dismiss);
    } else {
      _mark.forward();
      _sheen.forward();
      _handover = Timer(const Duration(milliseconds: 1080), _dismiss);
    }
  }

  @override
  void dispose() {
    _handover?.cancel();
    _mark.dispose();
    _exit.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _exit.forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        widget.child,
        AnimatedBuilder(
          animation: _exit,
          builder: (context, child) {
            final exit = _exit.value;
            if (exit >= 1) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Opacity(
                  opacity: 1 - Curves.easeInCubic.transform(exit),
                  child: Transform.scale(
                    scale: 1 + exit * 0.06,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                      child: _LaunchBackdrop(
                        scheme: scheme,
                        progress: _mark,
                        sheen: _sheen,
                        reduceMotion: widget.reduceMotion,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LaunchBackdrop extends StatelessWidget {
  const _LaunchBackdrop({
    required this.scheme,
    required this.progress,
    required this.sheen,
    required this.reduceMotion,
  });

  final ColorScheme scheme;
  final AnimationController progress;
  final AnimationController sheen;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.2, -0.4),
          radius: 1.2,
          colors: <Color>[
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.surface,
          ],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[progress, sheen]),
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(progress.value);
            final scale = reduceMotion ? 1.0 : 0.82 + 0.18 * t;
            // A small opacity floor keeps the very first frame from looking
            // like a blank screen before the mark starts drawing.
            final opacity = reduceMotion
                ? 1.0
                : (0.32 + 0.68 * (t * 1.6).clamp(0.0, 1.0));
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _BrandMark(
                      scheme: scheme,
                      progress: t,
                      sheen: sheen.value,
                      reduceMotion: reduceMotion,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'SuperCalculator',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next Era',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.scheme,
    required this.progress,
    required this.sheen,
    required this.reduceMotion,
  });

  final ColorScheme scheme;
  final double progress;
  final double sheen;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    // The mark starts as a circle and settles into the app's squircle, a nod to
    // the expressive shape-morph language used throughout the UI.
    final radius = 34 + 20 * (1 - progress);
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                colors: <Color>[scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: SquircleBorder(radius: radius),
              shadows: <BoxShadow>[
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const SizedBox(width: 108, height: 108),
          ),
          CustomPaint(
            size: const Size(56, 56),
            painter: _MarkPainter(
              color: scheme.onPrimary,
              progress: progress,
              sheen: sheen,
              reduceMotion: reduceMotion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a stylised keypad: a wide "display" bar and four rounded keys, with a
/// sheen that sweeps once during launch.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.color,
    required this.progress,
    required this.sheen,
    required this.reduceMotion,
  });

  final Color color;
  final double progress;
  final double sheen;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.92);
    final soft = Paint()..color = color.withValues(alpha: 0.38);
    final w = size.width;
    final h = size.height;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * 0.2),
      Radius.circular(h * 0.09),
    );
    canvas.drawRRect(bar, soft);

    const cols = 4;
    final keySize = w / cols * 0.62;
    final gap = (w - keySize * cols) / (cols + 1);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < cols; col++) {
        final reveal = reduceMotion
            ? 1.0
            : (progress * 2.4 - (row * cols + col) * 0.12).clamp(0.0, 1.0);
        if (reveal <= 0) continue;
        final left = gap + col * (keySize + gap);
        final top = h * 0.36 + row * (keySize + gap);
        final rect = Rect.fromLTWH(
          left,
          top,
          keySize,
          keySize * (0.5 + 0.5 * reveal),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(keySize * 0.3)),
          paint,
        );
      }
    }

    if (!reduceMotion) {
      final sweep = (sheen * 1.8 - 0.4).clamp(-0.2, 1.4);
      final x = w * sweep;
      final gradient = LinearGradient(
        colors: <Color>[
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(x - w * 0.2, 0, w * 0.4, h));
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
        Rect.fromLTWH(x - w * 0.2, 0, w * 0.4, h),
        Paint()..shader = gradient,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.sheen != sheen ||
      oldDelegate.color != color;
}
