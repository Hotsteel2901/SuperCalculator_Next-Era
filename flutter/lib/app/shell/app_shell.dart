import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/design_tokens.dart';
import '../../core/ui/feature_widgets.dart';
import '../../l10n/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = SuperCalcDesignTokens.of(context);
    final destinations = <_Destination>[
      _Destination('/home', Icons.home_outlined, Icons.home, l10n.home),
      _Destination(
        '/plotting',
        Icons.show_chart_outlined,
        Icons.show_chart,
        l10n.plotting,
      ),
      _Destination(
        '/calculus',
        Icons.functions_outlined,
        Icons.functions,
        l10n.calculus,
      ),
      _Destination(
        '/equations',
        Icons.account_tree_outlined,
        Icons.account_tree,
        l10n.equations,
      ),
      _Destination(
        '/ode',
        Icons.device_hub_outlined,
        Icons.device_hub,
        l10n.ode,
      ),
      _Destination(
        '/signals',
        Icons.graphic_eq_outlined,
        Icons.graphic_eq,
        l10n.signals,
      ),
      _Destination(
        '/data-analysis',
        Icons.insights_outlined,
        Icons.insights,
        l10n.dataAnalysis,
      ),
      _Destination(
        '/statistics',
        Icons.bar_chart_outlined,
        Icons.bar_chart,
        l10n.statistics,
      ),
      _Destination(
        '/linear-algebra',
        Icons.grid_4x4_outlined,
        Icons.grid_4x4,
        l10n.linearAlgebra,
      ),
      _Destination('/tools', Icons.build_outlined, Icons.build, l10n.tools),
      _Destination(
        '/advanced-tools',
        Icons.science_outlined,
        Icons.science,
        nextEraText(context, 'Advanced', '高级'),
      ),
      _Destination(
        '/history',
        Icons.history_outlined,
        Icons.history,
        nextEraText(context, 'History', '历史'),
      ),
      _Destination(
        '/settings',
        Icons.settings_outlined,
        Icons.settings,
        l10n.settings,
      ),
    ];
    // Keep the bottom bar short, but provide a single, scrollable place for all
    // destinations that do not fit there (including Settings).
    final compactDestinations = <_Destination>[
      ...destinations.take(4),
      _Destination(
        '/more',
        Icons.more_horiz,
        Icons.more_horiz,
        nextEraText(context, 'More', '更多'),
      ),
    ];
    final selected = _selectedIndex(location, destinations);
    final compactSelected = selected < 4 ? selected : 4;

    void navigate(int index) {
      if (index >= 0 && index < destinations.length) {
        context.go(destinations[index].path);
      }
    }

    void showAllDestinations() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          final maxHeight = MediaQuery.sizeOf(sheetContext).height * .8;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                      nextEraText(context, 'All sections', '所有功能'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  for (final item in destinations)
                    ListTile(
                      leading: Icon(
                        location == item.path ||
                                location.startsWith('${item.path}/')
                            ? item.selectedIcon
                            : item.icon,
                      ),
                      title: Text(item.label),
                      selected: location == item.path ||
                          location.startsWith('${item.path}/'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    void navigateCompact(int index) {
      if (index == compactDestinations.length - 1) {
        showAllDestinations();
      } else if (index >= 0 && index < destinations.length) {
        context.go(destinations[index].path);
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final useRail = constraints.maxWidth >= tokens.compactBreakpoint;
        final page = Scaffold(
          body: child,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: compactSelected,
                  onDestinationSelected: navigateCompact,
                  destinations: compactDestinations
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                      )
                      .toList(growable: false),
                ),
        );

        if (!useRail) {
          return page;
        }

        final showLabels = constraints.maxWidth >= tokens.mediumBreakpoint;
        return Scaffold(
          body: Row(
            children: <Widget>[
              _ScrollableSidebar(
                destinations: destinations,
                selectedIndex: selected,
                showLabels: showLabels,
                appTitle: l10n.appTitle,
                onDestinationSelected: navigate,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        );
      },
    );
  }

  int _selectedIndex(String current, List<_Destination> destinations) {
    final index = destinations.indexWhere(
      (item) => current == item.path || current.startsWith('${item.path}/'),
    );
    return index < 0 ? 0 : index;
  }
}

/// Desktop navigation is a bounded, independently scrollable list. A stock
/// NavigationRail lays every destination out at once, so on short/high-DPI
/// windows its lower items were clipped and mouse-wheel input had nowhere to go.
class _ScrollableSidebar extends StatefulWidget {
  const _ScrollableSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.showLabels,
    required this.appTitle,
    required this.onDestinationSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final bool showLabels;
  final String appTitle;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_ScrollableSidebar> createState() => _ScrollableSidebarState();
}

class _ScrollableSidebarState extends State<_ScrollableSidebar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final itemHeight = math.max(52.0, 52.0 * scale);

    return SizedBox(
      width: widget.showLabels ? 224 : 80,
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 68,
              child: Center(
                child: Tooltip(
                  message: widget.appTitle,
                  child: Semantics(
                    label: widget.appTitle,
                    child: Icon(
                      Icons.calculate_outlined,
                      size: 30,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                interactive: true,
                child: ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: widget.destinations.length,
                  itemExtent: itemHeight,
                  itemBuilder: (context, index) {
                    final item = widget.destinations[index];
                    final selected = index == widget.selectedIndex;
                    final tile = Material(
                      color: selected
                          ? colors.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => widget.onDestinationSelected(index),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.showLabels ? 12 : 0,
                          ),
                          child: Row(
                            mainAxisAlignment: widget.showLabels
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                color: selected
                                    ? colors.onSecondaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                              if (widget.showLabels) ...<Widget>[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: selected
                                              ? colors.onSecondaryContainer
                                              : colors.onSurfaceVariant,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : null,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: widget.showLabels
                          ? tile
                          : Tooltip(message: item.label, child: tile),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.selectedIcon, this.label);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
