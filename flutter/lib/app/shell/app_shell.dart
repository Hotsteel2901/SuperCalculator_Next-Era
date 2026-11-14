import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/expressive/expressive_widgets.dart';
import '../../core/ui/expressive/motion.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../theme/squircle_border.dart';

/// Adaptive application shell.
///
/// Phones get a floating navigation bar with a "More" sheet, medium windows a
/// compact rail, and wide windows a labelled sidebar. Selection is animated with
/// a shared spring so the indicator travels between destinations instead of
/// popping, and every layout keeps the same destination set.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _userCollapsed = false;

  List<_Destination> _destinations(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <_Destination>[
      _Destination(
        '/home',
        Icons.home_outlined,
        Icons.home_rounded,
        l10n.home,
        nextEraText(context, 'Overview and shortcuts', '概览与快捷入口'),
        _NavGroup.workspace,
      ),
      _Destination(
        '/plotting',
        Icons.show_chart_outlined,
        Icons.show_chart_rounded,
        l10n.plotting,
        nextEraText(context, 'Functions, polar, 3D', '函数、极坐标、三维'),
        _NavGroup.workspace,
      ),
      _Destination(
        '/calculus',
        Icons.functions_outlined,
        Icons.functions_rounded,
        l10n.calculus,
        nextEraText(context, 'Derivatives and integrals', '导数与积分'),
        _NavGroup.workspace,
      ),
      _Destination(
        '/equations',
        Icons.account_tree_outlined,
        Icons.account_tree_rounded,
        l10n.equations,
        nextEraText(context, 'Solve and factor', '求解与因式分解'),
        _NavGroup.workspace,
      ),
      _Destination(
        '/ode',
        Icons.device_hub_outlined,
        Icons.device_hub_rounded,
        l10n.ode,
        nextEraText(context, 'Numerical ODE solvers', '数值常微分方程'),
        _NavGroup.analysis,
      ),
      _Destination(
        '/signals',
        Icons.graphic_eq_outlined,
        Icons.graphic_eq_rounded,
        l10n.signals,
        nextEraText(context, 'FFT and convolution', 'FFT 与卷积'),
        _NavGroup.analysis,
      ),
      _Destination(
        '/data-analysis',
        Icons.insights_outlined,
        Icons.insights_rounded,
        l10n.dataAnalysis,
        nextEraText(context, 'Regression and fitting', '回归与拟合'),
        _NavGroup.analysis,
      ),
      _Destination(
        '/statistics',
        Icons.bar_chart_outlined,
        Icons.bar_chart_rounded,
        l10n.statistics,
        nextEraText(context, 'Distributions and tests', '分布与检验'),
        _NavGroup.analysis,
      ),
      _Destination(
        '/linear-algebra',
        Icons.grid_4x4_outlined,
        Icons.grid_4x4_rounded,
        l10n.linearAlgebra,
        nextEraText(context, 'Matrices and vectors', '矩阵与向量'),
        _NavGroup.analysis,
      ),
      _Destination(
        '/tools',
        Icons.build_outlined,
        Icons.build_rounded,
        l10n.tools,
        nextEraText(context, 'Converters and finance', '换算与财务'),
        _NavGroup.utilities,
      ),
      _Destination(
        '/advanced-tools',
        Icons.science_outlined,
        Icons.science_rounded,
        nextEraText(context, 'Advanced', '高级'),
        nextEraText(context, 'Complex numbers and more', '复数与更多工具'),
        _NavGroup.utilities,
      ),
      _Destination(
        '/history',
        Icons.history_outlined,
        Icons.history_rounded,
        nextEraText(context, 'History', '历史'),
        nextEraText(context, 'Recent results and export', '最近结果与导出'),
        _NavGroup.utilities,
      ),
      _Destination(
        '/settings',
        Icons.settings_outlined,
        Icons.settings_rounded,
        l10n.settings,
        nextEraText(context, 'Theme, plot and behaviour', '主题、绘图与行为'),
        _NavGroup.settings,
      ),
    ];
  }

  int _selectedIndex(String current, List<_Destination> destinations) {
    final index = destinations.indexWhere(
      (item) => current == item.path || current.startsWith('${item.path}/'),
    );
    return index < 0 ? 0 : index;
  }

  void _go(String path) {
    if (ref.read(appSettingsProvider).haptics) {
      HapticFeedback.selectionClick();
    }
    context.go(path);
  }

  Future<void> _showAllSections(List<_Destination> destinations) async {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.82;
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        nextEraText(context, 'All sections', '所有功能'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Wrap(
                    spacing: tokens.cardGap,
                    runSpacing: tokens.cardGap,
                    children: destinations
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final selected =
                              widget.location == item.path ||
                              widget.location.startsWith('${item.path}/');
                          final width =
                              (MediaQuery.sizeOf(sheetContext).width -
                                  32 -
                                  tokens.cardGap) /
                              2;
                          return SizedBox(
                            width: width.clamp(140, 320),
                            child: StaggeredEntry(
                              index: index,
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                color: selected
                                    ? scheme.secondaryContainer
                                    : scheme.surfaceContainer,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  _go(item.path);
                                },
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: ShapeDecoration(
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                                  .withValues(alpha: 0.12)
                                            : scheme.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                        shape: tokens.keyShape(),
                                      ),
                                      child: Icon(
                                        selected
                                            ? item.selectedIcon
                                            : item.icon,
                                        size: 20,
                                        color: selected
                                            ? scheme.onSecondaryContainer
                                            : scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Text(
                                            item.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final selected = _selectedIndex(widget.location, destinations);
    final tokens = SuperCalcDesignTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useSidebar = width >= 760;
        final expanded = !_userCollapsed && width >= 1080;

        if (!useSidebar) {
          final primaryCount = math.min(4, destinations.length);
          final compact = <_Destination>[
            ...destinations.take(primaryCount),
            _Destination(
              '/more',
              Icons.grid_view_rounded,
              Icons.grid_view_rounded,
              nextEraText(context, 'More', '更多'),
              '',
              _NavGroup.utilities,
            ),
          ];
          final compactSelected = selected < primaryCount
              ? selected
              : primaryCount;
          return Scaffold(
            body: AnimatedSwitcher(
              duration: tokens.scaled(const Duration(milliseconds: 260)),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.015),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<String>(widget.location),
                child: widget.child,
              ),
            ),
            bottomNavigationBar: _FloatingNavigationBar(
              destinations: compact,
              selectedIndex: compactSelected,
              onSelected: (index) {
                if (index == primaryCount) {
                  _showAllSections(destinations);
                } else {
                  _go(destinations[index].path);
                }
              },
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: <Widget>[
              _ExpressiveSidebar(
                destinations: destinations,
                selectedIndex: selected,
                expanded: expanded,
                onToggle: () =>
                    setState(() => _userCollapsed = !_userCollapsed),
                onSelected: (index) => _go(destinations[index].path),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: tokens.scaled(const Duration(milliseconds: 260)),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: KeyedSubtree(
                    key: ValueKey<String>(widget.location),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _NavGroup { workspace, analysis, utilities, settings }

class _Destination {
  const _Destination(
    this.path,
    this.icon,
    this.selectedIcon,
    this.label,
    this.description,
    this.group,
  );

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String description;
  final _NavGroup group;
}

class _FloatingNavigationBar extends StatelessWidget {
  const _FloatingNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
            shape: SquircleBorder(radius: tokens.cornerLarge),
            shadows: <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 68,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: destinations
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                    tooltip: item.label,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

/// Bounded, independently scrollable sidebar with an animated selection pill.
class _ExpressiveSidebar extends StatefulWidget {
  const _ExpressiveSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelected;

  @override
  State<_ExpressiveSidebar> createState() => _ExpressiveSidebarState();
}

class _ExpressiveSidebarState extends State<_ExpressiveSidebar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final l10n = AppLocalizations.of(context);

    Widget itemFor(int index) {
      final item = widget.destinations[index];
      final selected = index == widget.selectedIndex;
      return _SidebarItem(
        item: item,
        selected: selected,
        expanded: widget.expanded,
        onTap: () => widget.onSelected(index),
      );
    }

    List<Widget> group(_NavGroup group) {
      final indices = <int>[
        for (var i = 0; i < widget.destinations.length; i++)
          if (widget.destinations[i].group == group) i,
      ];
      if (indices.isEmpty) return const <Widget>[];
      return <Widget>[
        if (widget.expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
            child: Text(
              switch (group) {
                _NavGroup.workspace => nextEraText(context, 'WORKSPACE', '工作区'),
                _NavGroup.analysis => nextEraText(context, 'ANALYSIS', '分析'),
                _NavGroup.utilities => nextEraText(context, 'UTILITIES', '工具'),
                _NavGroup.settings => nextEraText(context, 'SYSTEM', '系统'),
              },
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          const SizedBox(height: 10),
        for (final index in indices) itemFor(index),
      ];
    }

    return AnimatedContainer(
      duration: tokens.scaled(const Duration(milliseconds: 260)),
      curve: Curves.easeOutCubic,
      width: widget.expanded ? 236 : 86,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.fromLTRB(widget.expanded ? 16 : 0, 10, 8, 8),
            child: Row(
              mainAxisAlignment: widget.expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: <Widget>[
                _BrandMark(color: scheme.primary, onPrimary: scheme.onPrimary),
                if (widget.expanded) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          nextEraText(context, 'Next Era', 'Next Era'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                gradient: <Color>[
                  scheme.primaryContainer.withValues(alpha: 0.85),
                  scheme.tertiaryContainer.withValues(alpha: 0.75),
                ],
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextEraText(
                          context,
                          'Ctrl+I quick input',
                          'Ctrl+I 快捷输入',
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: widget.expanded,
              interactive: true,
              child: ListView(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                children: <Widget>[
                  ...group(_NavGroup.workspace),
                  ...group(_NavGroup.analysis),
                  ...group(_NavGroup.utilities),
                  ...group(_NavGroup.settings),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: AppTooltip(
              message: widget.expanded
                  ? nextEraText(context, 'Collapse sidebar', '收起侧栏')
                  : nextEraText(context, 'Expand sidebar', '展开侧栏'),
              child: TextButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(
                  widget.expanded
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                  size: 20,
                ),
                label: widget.expanded
                    ? Text(nextEraText(context, 'Collapse', '收起'))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final _Destination item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final content = AnimatedContainer(
      duration: tokens.scaled(const Duration(milliseconds: 220)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 14 : 0,
        vertical: 10,
      ),
      decoration: ShapeDecoration(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: SquircleBorder(radius: tokens.cornerSmall + 2),
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            selected ? item.selectedIcon : item.icon,
            size: 22,
            color: foreground,
          ),
          if (expanded) ...<Widget>[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return AppTooltip(
      message: expanded
          ? item.description
          : '${item.label} · ${item.description}',
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.97,
        semanticLabel: item.label,
        child: content,
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.color, required this.onPrimary});

  final Color color;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: <Color>[color, Color.lerp(color, onPrimary, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: const SquircleBorder(radius: 13),
      ),
      child: Icon(Icons.calculate_rounded, size: 21, color: onPrimary),
    );
  }
}
