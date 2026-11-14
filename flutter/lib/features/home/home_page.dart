import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/design_tokens.dart';
import '../../app/theme/monet.dart';
import '../../core/history/history_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/expressive/motion.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';

/// Dashboard that surfaces the most useful entry points, the current theme
/// source and the latest calculation instead of a static feature list.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = SuperCalcDesignTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(calculationHistoryProvider);
    final settings = ref.watch(
      appSettingsProvider.select(
        (AppSettings value) => (
          value.intensity,
          value.monetEnabled,
          value.motionSpeed,
        ),
      ),
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar.large(
          title: Text(l10n.appTitle),
          actions: <Widget>[
            AppTooltip(
              message: l10n.about,
              child: IconButton(
                onPressed: () => context.go('/settings/about'),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ),
            AppTooltip(
              message: l10n.settings,
              child: IconButton(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
            0,
            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
            tokens.pagePadding + 28,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              const StaggeredEntry(index: 0, child: _HeroCard()),
              const SizedBox(height: 14),
              StaggeredEntry(
                index: 1,
                child: _StatusStrip(historyCount: history.length),
              ),
              if (history.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                StaggeredEntry(
                  index: 2,
                  child: _ContinueCard(entry: history.first),
                ),
              ],
              const SizedBox(height: 22),
              SectionHeader(
                title: nextEraText(context, 'Workbenches', '功能工作台'),
                subtitle: nextEraText(
                  context,
                  'Everything runs locally and offline',
                  '全部本地离线运行',
                ),
                icon: Icons.widgets_rounded,
                trailing: StatusPill(
                  label: settings.$1.name,
                  compact: true,
                  color: scheme.tertiary,
                ),
              ),
              _FeatureGrid(tokens: tokens),
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.all(16),
                gradient: <Color>[
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerLow,
                ],
                child: Row(
                  children: <Widget>[
                    Icon(Icons.tips_and_updates_outlined, color: scheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nextEraText(
                          context,
                          'Tip: open the quick input panel with Ctrl+I (⌘I on macOS) while the expression field is focused.',
                          '小技巧：编辑表达式时按 Ctrl+I（macOS 为 ⌘I）可呼出快捷输入面板。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${l10n.migrationStatus} · AGPL-3.0-or-later',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return AppCard(
      padding: const EdgeInsets.all(0),
      gradient: <Color>[
        scheme.primaryContainer,
        Color.lerp(scheme.primaryContainer, scheme.tertiaryContainer, 0.65)!,
        scheme.tertiaryContainer.withValues(alpha: 0.85),
      ],
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -50,
            child: AmbientGlow(
              color: scheme.primary.withValues(alpha: 0.55),
              size: 260,
              intensity: 0.35,
            ),
          ),
          Positioned(
            right: 18,
            bottom: 12,
            child: Opacity(
              opacity: 0.16,
              child: Icon(
                Icons.functions_rounded,
                size: 110,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 18 : 26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                StatusPill(
                  label: nextEraText(context, 'Material 3 Expressive', '材质 3 表现力'),
                  icon: Icons.auto_awesome_rounded,
                  color: scheme.onPrimaryContainer,
                  compact: true,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.welcomeTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    l10n.welcomeBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.86),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => context.go('/plotting'),
                      icon: const Icon(Icons.show_chart_rounded),
                      label: Text(l10n.openPlotter),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/history'),
                      icon: const Icon(Icons.history_rounded),
                      label: Text(nextEraText(context, 'History', '历史')),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(l10n.settings),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _HeroFact(
                      icon: Icons.memory_rounded,
                      label: nextEraText(context, 'C FFI engine', 'C FFI 引擎'),
                      color: scheme.onPrimaryContainer,
                    ),
                    _HeroFact(
                      icon: Icons.public_rounded,
                      label: nextEraText(context, 'Win · Lin · macOS · Android · Web', 'Win · Lin · macOS · Android · Web'),
                      color: scheme.onPrimaryContainer,
                    ),
                    _HeroFact(
                      icon: Icons.offline_bolt_rounded,
                      label: nextEraText(context, 'Offline first', '离线优先'),
                      color: scheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: StatusPill(
              label: '×${tokens.motionScale.toStringAsFixed(2)}',
              compact: true,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _StatusStrip extends ConsumerWidget {
  const _StatusStrip({required this.historyCount});

  final int historyCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final seeds = ref.watch(monetSeedsProvider);
    final settings = ref.watch(appSettingsProvider);
    final source = seeds.asData?.value.source;
    final sourceLabel = switch (source) {
      MonetSource.wallpaper => nextEraText(context, 'Wallpaper palette', '壁纸取色'),
      MonetSource.accent => nextEraText(context, 'System accent', '系统强调色'),
      MonetSource.seed => nextEraText(context, 'Seed palette', '种子配色'),
      null => nextEraText(context, 'Reading colors', '读取配色'),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _StatTile(
              icon: Icons.palette_outlined,
              label: settings.monetEnabled ? sourceLabel : nextEraText(context, 'Seed palette', '种子配色'),
              value: settings.monetStyle.name,
              color: scheme.primary,
              width: narrow ? (constraints.maxWidth - 10) / 2 : 200,
            ),
            _StatTile(
              icon: Icons.history_rounded,
              label: nextEraText(context, 'History', '历史'),
              value: '$historyCount',
              color: scheme.tertiary,
              width: narrow ? (constraints.maxWidth - 10) / 2 : 160,
            ),
            _StatTile(
              icon: Icons.speed_rounded,
              label: nextEraText(context, 'Sampling', '采样'),
              value: settings.plotResolution.name,
              color: scheme.secondary,
              width: narrow ? (constraints.maxWidth - 10) / 2 : 180,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: scheme.surfaceContainer,
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: ShapeDecoration(
                color: color.withValues(alpha: 0.12),
                shape: const CircleBorder(),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: scheme.secondaryContainer,
      onTap: () => context.go('/plotting'),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: ShapeDecoration(
              color: scheme.onSecondaryContainer.withValues(alpha: 0.1),
              shape: tokens.keyShape(),
            ),
            child: Icon(
              Icons.play_circle_outline_rounded,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nextEraText(context, 'Continue where you left off', '继续上次的计算'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  entry.expression,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  entry.result,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.tokens});

  final SuperCalcDesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final features = <_FeatureCardData>[
      _FeatureCardData(
        l10n.plotting,
        nextEraText(context, 'Functions, polar, implicit, 3D', '函数、极坐标、隐式、三维'),
        Icons.show_chart_rounded,
        '/plotting',
        Theme.of(context).colorScheme.primary,
      ),
      _FeatureCardData(
        l10n.calculus,
        nextEraText(context, 'Derivatives and definite integrals', '导数与定积分'),
        Icons.functions_rounded,
        '/calculus',
        Theme.of(context).colorScheme.tertiary,
      ),
      _FeatureCardData(
        l10n.equations,
        nextEraText(context, 'Polynomial and linear systems', '多项式与线性方程组'),
        Icons.account_tree_rounded,
        '/equations',
        Theme.of(context).colorScheme.secondary,
      ),
      _FeatureCardData(
        l10n.ode,
        nextEraText(context, 'Euler, Heun, RK4, RKF45', '欧拉、Heun、RK4、RKF45'),
        Icons.device_hub_rounded,
        '/ode',
        Theme.of(context).colorScheme.error,
      ),
      _FeatureCardData(
        l10n.signals,
        nextEraText(context, 'FFT, convolution, spectra', 'FFT、卷积、频谱'),
        Icons.graphic_eq_rounded,
        '/signals',
        Theme.of(context).colorScheme.primary,
      ),
      _FeatureCardData(
        l10n.dataAnalysis,
        nextEraText(context, 'Regression and interpolation', '回归与插值'),
        Icons.insights_rounded,
        '/data-analysis',
        Theme.of(context).colorScheme.tertiary,
      ),
      _FeatureCardData(
        l10n.statistics,
        nextEraText(context, 'Descriptive stats and histograms', '描述统计与直方图'),
        Icons.bar_chart_rounded,
        '/statistics',
        Theme.of(context).colorScheme.secondary,
      ),
      _FeatureCardData(
        l10n.linearAlgebra,
        nextEraText(context, 'Determinants, inverse, eigenvalues', '行列式、逆、特征值'),
        Icons.grid_4x4_rounded,
        '/linear-algebra',
        Theme.of(context).colorScheme.primary,
      ),
      _FeatureCardData(
        l10n.tools,
        nextEraText(context, 'Units, bases, finance', '单位、进制、财务'),
        Icons.build_rounded,
        '/tools',
        Theme.of(context).colorScheme.tertiary,
      ),
      _FeatureCardData(
        nextEraText(context, 'Advanced tools', '高级工具'),
        nextEraText(context, 'Complex numbers and distributions', '复数与概率分布'),
        Icons.science_rounded,
        '/advanced-tools',
        Theme.of(context).colorScheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * tokens.cardGap) / columns;
        return Wrap(
          spacing: tokens.cardGap,
          runSpacing: tokens.cardGap,
          children: features.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return SizedBox(
              width: width,
              child: StaggeredEntry(
                index: index,
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => context.go(item.path),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: ShapeDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          shape: tokens.keyShape(),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _FeatureCardData {
  const _FeatureCardData(
    this.label,
    this.description,
    this.icon,
    this.path,
    this.color,
  );

  final String label;
  final String description;
  final IconData icon;
  final String path;
  final Color color;
}
