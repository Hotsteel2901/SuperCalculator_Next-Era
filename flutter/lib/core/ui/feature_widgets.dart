import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/design_tokens.dart';
import '../plot/plot_point.dart';
import 'expressive/expressive_widgets.dart';
import 'expressive/motion.dart';

String nextEraText(BuildContext context, String english, String chinese) {
  return Localizations.localeOf(context).languageCode == 'zh'
      ? chinese
      : english;
}

double? parseMathNumber(String text) {
  final normalized = text.trim().toLowerCase();
  if (normalized == 'pi') {
    return 3.141592653589793;
  }
  if (normalized == '-pi') {
    return -3.141592653589793;
  }
  if (normalized == 'e') {
    return 2.718281828459045;
  }
  return double.tryParse(normalized);
}

/// Shared page scaffold for the tool pages.
///
/// The large title collapses into a pinned bar while the content scrolls, which
/// matches the expressive "hero to app bar" pattern on phones and keeps desktop
/// windows compact.
class FeaturePageFrame extends StatelessWidget {
  const FeaturePageFrame({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.actions,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = SuperCalcDesignTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitleText = subtitle;
    return CustomScrollView(
      slivers: <Widget>[
        // A plain SliverAppBar with a FlexibleSpaceBar title is used instead of
        // `SliverAppBar.large`: supplying a custom flexible space to the `.large`
        // variant silently drops the collapsing title, which left pages with a
        // subtitle (most of them) without a visible heading.
        SliverAppBar(
          pinned: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(icon, color: scheme.primary),
          ),
          actions: actions,
          expandedHeight: subtitleText == null ? 132 : 172,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.5,
            titlePadding: EdgeInsetsDirectional.only(
              start: 60,
              // The toolbar keeps 56dp of height; the subtitle needs its own row
              // underneath the expanded title.
              bottom: subtitleText == null ? 14 : 44,
              end: 16,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            background: subtitleText == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 62,
                        bottom: 20,
                        end: 24,
                      ),
                      child: Text(
                        subtitleText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
            4,
            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
            tokens.pagePadding + 24,
          ),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}

/// Grouped content surface with an icon + title header.
class FeatureCard extends StatelessWidget {
  const FeatureCard({required this.child, super.key, this.title, this.icon});

  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (title != null) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Result surface with an animated value and a copy affordance.
class ResultCard extends StatelessWidget {
  const ResultCard({
    required this.value,
    this.error,
    this.label,
    this.onCopy,
    super.key,
  });

  final String value;
  final String? error;
  final String? label;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final foreground = hasError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    final copy = onCopy;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: ShapeDecoration(
          color: hasError ? scheme.errorContainer : scheme.secondaryContainer,
          shape: SuperCalcDesignTokens.of(context).surfaceShape(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              hasError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (label != null)
                    Text(
                      label!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  AnimatedNumberText(
                    value: error ?? value,
                    alignment: Alignment.centerLeft,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
            if (copy != null)
              IconButton(
                tooltip: nextEraText(context, 'Copy', '复制'),
                onPressed: copy,
                icon: Icon(Icons.copy_rounded, color: foreground, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class FormRow extends StatelessWidget {
  const FormRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(growable: false),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (child) => Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: child,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// Full-screen host for a static [CustomPainter] chart.
class ChartFullscreenPage extends StatelessWidget {
  const ChartFullscreenPage({
    required this.painter,
    required this.title,
    super.key,
  });

  final CustomPainter painter;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: tokens.surfaceShape()),
            child: CustomPaint(
              painter: painter,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clipped chart preview with a corner button that opens [ChartFullscreenPage].
class ExpandableChart extends StatelessWidget {
  const ExpandableChart({
    required this.title,
    required this.painter,
    this.height = 360,
    this.semanticsLabel,
    super.key,
  });

  final String title;
  final CustomPainter painter;
  final double height;
  final String? semanticsLabel;

  void _openFullScreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      ExpressivePageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ChartFullscreenPage(painter: painter, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    Widget chart = CustomPaint(
      painter: painter,
      child: const SizedBox.expand(),
    );
    if (semanticsLabel != null) {
      chart = Semantics(label: semanticsLabel, child: chart);
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: tokens.surfaceShape()),
                child: chart,
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: AppTooltip(
              message: nextEraText(context, 'Full screen', '全屏'),
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.86),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  onPressed: () => _openFullScreen(context),
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LineSeriesPainter extends CustomPainter {
  const LineSeriesPainter({required this.series, required this.scheme});

  final List<List<PlotPoint>> series;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainerLowest,
    );
    final points = series
        .expand((item) => item)
        .where((item) {
          return item.x.isFinite && item.y.isFinite;
        })
        .toList(growable: false);
    if (points.isEmpty || size.width <= 1 || size.height <= 1) {
      return;
    }
    var minX = points.map((point) => point.x).reduce((a, b) => a < b ? a : b);
    var maxX = points.map((point) => point.x).reduce((a, b) => a > b ? a : b);
    var minY = points.map((point) => point.y).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((point) => point.y).reduce((a, b) => a > b ? a : b);
    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final xPadding = (maxX - minX) * .05;
    final yPadding = (maxY - minY) * .08;
    minX -= xPadding;
    maxX += xPadding;
    minY -= yPadding;
    maxY += yPadding;
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final dx = size.width * i / 5;
      final dy = size.height * i / 5;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }
    final colors = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final paint = Paint()
        ..color = colors[seriesIndex % colors.length]
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var hasPoint = false;
      for (final point in series[seriesIndex]) {
        if (!point.x.isFinite || !point.y.isFinite) {
          hasPoint = false;
          continue;
        }
        final offset = Offset(
          (point.x - minX) / (maxX - minX) * size.width,
          (maxY - point.y) / (maxY - minY) * size.height,
        );
        if (hasPoint) {
          path.lineTo(offset.dx, offset.dy);
        } else {
          path.moveTo(offset.dx, offset.dy);
        }
        hasPoint = true;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LineSeriesPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.scheme != scheme;
}

/// Copies a value to the clipboard and confirms with a snack bar.
Future<void> copyToClipboard(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(nextEraText(context, 'Copied to clipboard', '已复制到剪贴板')),
      duration: const Duration(milliseconds: 1400),
    ),
  );
}

/// Keeps numeric keys aligned when values use different digit counts.
class TabularText extends StatelessWidget {
  const TabularText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Small helper that formats a double without trailing zeros.
String formatNumber(double value, {int? precision}) {
  if (!value.isFinite) return value.isNaN ? 'NaN' : '∞';
  if (precision != null) return value.toStringAsPrecision(precision);
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  final magnitude = value.abs();
  if (magnitude >= 1e9 || (magnitude > 0 && magnitude < 1e-4)) {
    return value.toStringAsExponential(4);
  }
  final text = value.toStringAsPrecision(10);
  return text.contains('e') ? text : _trimZeros(text);
}

String _trimZeros(String value) {
  if (!value.contains('.')) return value;
  return value.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Clamps [value] to a symmetric range used by plot accent heights.
double normalized(double value, double min, double max) {
  if (!value.isFinite || max <= min) return 0;
  return ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
}

/// Rounds to a whole logical pixel, which keeps 1px strokes crisp.
double pixelSnap(double value) => (value * 1).roundToDouble();

/// Keeps a scrollable list from rebuilding every row when only the head grows.
int estimateVisibleRows(double extent, double itemExtent) =>
    math.max(1, (extent / itemExtent).ceil() + 2);
