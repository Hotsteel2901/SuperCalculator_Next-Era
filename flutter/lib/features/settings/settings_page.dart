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

/// Appearance, behaviour and accessibility settings for the whole application.
///
/// Every control writes to [appSettingsProvider]; consumers read the exact
/// field they need through `select`, so changing a plot setting never rebuilds
/// the theme and vice versa.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(AppSettings Function(AppSettings current) transform) {
    ref.read(appSettingsProvider.notifier).update(transform);
  }

  bool _matches(String haystack) =>
      _query.isEmpty || haystack.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final seeds = ref.watch(monetSeedsProvider);
    final history = ref.watch(calculationHistoryProvider);
    final strings = _Strings(context);
    final search = _query;
    final showAppearance =
        search.isEmpty ||
        'appearance theme monet palette colour color contrast shape text tools '
                '外观 主题 配色 颜色 对比 形状 文字 工具'
            .contains(search);
    final showMotion =
        search.isEmpty ||
        'motion animation spring reduced 动效 动画 弹簧 减弱'.contains(search);
    final showPlot =
        search.isEmpty ||
        'plot sampling grid labels curve 3d mesh 绘图 采样 网格 标签 曲线 三维'.contains(
          search,
        );
    final showInput =
        search.isEmpty ||
        'input keyboard haptics history precision start page 输入 键盘 触感 历史 精度 启动'
            .contains(search);
    final showData =
        search.isEmpty || 'data history language 数据 历史 语言'.contains(search);
    final showAbout =
        search.isEmpty || 'about version license 关于 版本 许可'.contains(search);

    return FeaturePageFrame(
      title: l10n.settings,
      icon: Icons.tune_rounded,
      subtitle: nextEraText(
        context,
        'Every option applies immediately and is stored on this device.',
        '所有选项即时生效，并保存在本设备。',
      ),
      actions: <Widget>[
        AppTooltip(
          message: strings.search,
          child: IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
            icon: Icon(
              _searching ? Icons.search_off_rounded : Icons.search_rounded,
            ),
          ),
        ),
        AppTooltip(
          message: strings.resetAll,
          child: IconButton(
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ),
        const SizedBox(width: 4),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_searching) ...<Widget>[
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: strings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_query.isEmpty) ...<Widget>[
            _PreviewCard(settings: settings),
            const SizedBox(height: 18),
          ],
          if (showAppearance) ...<Widget>[
            SectionHeader(
              title: strings.appearance,
              subtitle: strings.appearanceHint,
              icon: Icons.palette_outlined,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_matches(
                    '${strings.themeMode} ${strings.system}',
                  )) ...<Widget>[
                    SettingsTile(
                      icon: Icons.brightness_6_outlined,
                      title: strings.themeMode,
                      subtitle: strings.themeModeHint,
                      trailing: _ThemeModeToggle(
                        mode: settings.themeMode,
                        onChanged: (mode) =>
                            _update((s) => s.copyWith(themeMode: mode)),
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches('monet ${strings.dynamicColor}')) ...<Widget>[
                    SettingsSwitchTile(
                      icon: Icons.wallpaper_outlined,
                      title: strings.dynamicColor,
                      subtitle: _monetSubtitle(seeds.asData?.value),
                      value: settings.monetEnabled,
                      onChanged: (value) =>
                          _update((s) => s.copyWith(monetEnabled: value)),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches('${strings.seedPalette} palette')) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.color_lens_outlined,
                                size: 22,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  strings.seedPalette,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: SeedPalette.values
                                .map((palette) {
                                  final selected =
                                      settings.seedPalette == palette;
                                  return AppTooltip(
                                    message: _paletteLabel(palette, strings),
                                    child: PressableScale(
                                      onTap: () => _update(
                                        (s) => s.copyWith(seedPalette: palette),
                                      ),
                                      child: AnimatedContainer(
                                        duration: tokens.scaled(
                                          const Duration(milliseconds: 200),
                                        ),
                                        width: 40,
                                        height: 40,
                                        decoration: ShapeDecoration(
                                          color: palette.seedColor,
                                          shape: selected
                                              ? const CircleBorder(
                                                  side: BorderSide(
                                                    color: Colors.white,
                                                    width: 3,
                                                  ),
                                                )
                                              : CircleBorder(
                                                  side: BorderSide(
                                                    color:
                                                        scheme.outlineVariant,
                                                  ),
                                                ),
                                          shadows: selected
                                              ? <BoxShadow>[
                                                  BoxShadow(
                                                    color: palette.seedColor
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 12,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches(
                    '${strings.paletteStyle} tonal vibrant',
                  )) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.paletteStyle,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            strings.paletteStyleHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          SettingsChoice<MonetStyle>(
                            values: MonetStyle.values,
                            selected: settings.monetStyle,
                            labelOf: (style) => _styleLabel(style, strings),
                            onSelected: (style) =>
                                _update((s) => s.copyWith(monetStyle: style)),
                          ),
                        ],
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches(strings.contrast)) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.contrast,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          SettingsChoice<MonetContrast>(
                            values: MonetContrast.values,
                            selected: settings.monetContrast,
                            labelOf: (value) => _contrastLabel(value, strings),
                            onSelected: (value) => _update(
                              (s) => s.copyWith(monetContrast: value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches(strings.intensity)) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.intensity,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _intensityDescription(l10n, settings.intensity),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          SettingsChoice<ExpressiveIntensity>(
                            values: ExpressiveIntensity.values,
                            selected: settings.intensity,
                            labelOf: (value) => _intensityLabel(value, strings),
                            onSelected: (value) =>
                                _update((s) => s.copyWith(intensity: value)),
                          ),
                        ],
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  if (_matches('${strings.shapes} corner')) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.shapes,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          SettingsChoice<CornerStyle>(
                            values: CornerStyle.values,
                            selected: settings.cornerStyle,
                            labelOf: (value) => value == CornerStyle.rounded
                                ? strings.rounded
                                : strings.squircle,
                            iconOf: (value) => value == CornerStyle.rounded
                                ? Icons.crop_square_rounded
                                : Icons.blur_on_rounded,
                            onSelected: (value) =>
                                _update((s) => s.copyWith(cornerStyle: value)),
                          ),
                        ],
                      ),
                    ),
                    const SoftDivider(indent: 12, endIndent: 12),
                  ],
                  SettingsSlider(
                    icon: Icons.format_size_rounded,
                    title: strings.textScale,
                    subtitle: strings.textScaleHint,
                    value: settings.textScale,
                    min: 0.85,
                    max: 1.45,
                    divisions: 12,
                    valueLabel: (value) => '${(value * 100).round()}%',
                    onChanged: (value) =>
                        _update((s) => s.copyWith(textScale: value)),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  SettingsSwitchTile(
                    icon: Icons.format_bold_rounded,
                    title: strings.boldText,
                    value: settings.boldText,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(boldText: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.contrast_rounded,
                    title: strings.highContrast,
                    subtitle: strings.highContrastHint,
                    value: settings.highContrast,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(highContrast: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.touch_app_outlined,
                    title: strings.largeTargets,
                    value: settings.largeTouchTargets,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(largeTouchTargets: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.info_outline_rounded,
                    title: strings.tooltips,
                    value: settings.showTooltips,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(showTooltips: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showMotion) ...<Widget>[
            SectionHeader(
              title: strings.motion,
              subtitle: strings.motionHint,
              icon: Icons.animation_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.motionSpeed,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<MotionSpeed>(
                          values: MotionSpeed.values,
                          selected: settings.motionSpeed,
                          labelOf: (value) => switch (value) {
                            MotionSpeed.calm => strings.calm,
                            MotionSpeed.standard => strings.standard,
                            MotionSpeed.brisk => strings.brisk,
                            MotionSpeed.lively => strings.lively,
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(motionSpeed: value)),
                        ),
                      ],
                    ),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.reduceMotion,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.reduceMotionHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<ReduceMotionPreference>(
                          values: ReduceMotionPreference.values,
                          selected: settings.reduceMotion,
                          labelOf: (value) => switch (value) {
                            ReduceMotionPreference.system =>
                              strings.followSystem,
                            ReduceMotionPreference.reduce =>
                              strings.alwaysReduce,
                            ReduceMotionPreference.allow => strings.alwaysAllow,
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(reduceMotion: value)),
                        ),
                      ],
                    ),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  SettingsSwitchTile(
                    icon: Icons.draw_outlined,
                    title: strings.animatePlot,
                    subtitle: strings.animatePlotHint,
                    value: settings.animatePlotDraw,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(animatePlotDraw: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showPlot) ...<Widget>[
            SectionHeader(
              title: strings.plot,
              subtitle: strings.plotHint,
              icon: Icons.show_chart_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.resolution,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.resolutionHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<PlotResolution>(
                          values: PlotResolution.values,
                          selected: settings.plotResolution,
                          labelOf: (value) => switch (value) {
                            PlotResolution.adaptive => strings.adaptive,
                            PlotResolution.balanced => '2.4k',
                            PlotResolution.high => '4.8k',
                            PlotResolution.ultra => '8k',
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(plotResolution: value)),
                        ),
                      ],
                    ),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  SettingsSwitchTile(
                    icon: Icons.auto_graph_rounded,
                    title: strings.adaptiveSampling,
                    subtitle: strings.adaptiveSamplingHint,
                    value: settings.adaptiveSampling,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(adaptiveSampling: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.sync_rounded,
                    title: strings.autoResample,
                    subtitle: strings.autoResampleHint,
                    value: settings.autoResample,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(autoResample: value)),
                  ),
                  SettingsSlider(
                    icon: Icons.line_weight_rounded,
                    title: strings.curveThickness,
                    value: settings.curveThickness,
                    min: 1,
                    max: 5,
                    divisions: 20,
                    valueLabel: (value) => '${value.toStringAsFixed(1)} px',
                    onChanged: (value) =>
                        _update((s) => s.copyWith(curveThickness: value)),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  SettingsSwitchTile(
                    icon: Icons.grid_on_rounded,
                    title: strings.grid,
                    value: settings.showGrid,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(showGrid: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.numbers_rounded,
                    title: strings.axisLabels,
                    value: settings.showAxisLabels,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(showAxisLabels: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.ads_click_rounded,
                    title: strings.tapToMark,
                    value: settings.tapToMark,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(tapToMark: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.zoom_in_map_rounded,
                    title: strings.doubleTapZoom,
                    value: settings.doubleTapZoom,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(doubleTapZoom: value)),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.plotBackground,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<PlotBackgroundStyle>(
                          values: PlotBackgroundStyle.values,
                          selected: settings.plotBackground,
                          labelOf: (value) => switch (value) {
                            PlotBackgroundStyle.surface => strings.surface,
                            PlotBackgroundStyle.container => strings.container,
                            PlotBackgroundStyle.contrast =>
                              strings.contrastOption,
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(plotBackground: value)),
                        ),
                      ],
                    ),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.meshDensity,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<MeshDensity>(
                          values: MeshDensity.values,
                          selected: settings.meshDensity,
                          labelOf: (value) => switch (value) {
                            MeshDensity.low => strings.low,
                            MeshDensity.medium => strings.medium,
                            MeshDensity.high => strings.high,
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(meshDensity: value)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showInput) ...<Widget>[
            SectionHeader(
              title: strings.input,
              subtitle: strings.inputHint,
              icon: Icons.tune_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.quickPanel,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.quickPanelHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<QuickPanelLayout>(
                          values: QuickPanelLayout.values,
                          selected: settings.quickPanelLayout,
                          labelOf: (value) => switch (value) {
                            QuickPanelLayout.automatic => strings.automatic,
                            QuickPanelLayout.bottomSheet => strings.sheet,
                            QuickPanelLayout.sidePanel => strings.sidePanel,
                            QuickPanelLayout.dialog => strings.dialog,
                          },
                          onSelected: (value) => _update(
                            (s) => s.copyWith(quickPanelLayout: value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  SettingsSwitchTile(
                    icon: Icons.vibration_rounded,
                    title: strings.haptics,
                    value: settings.haptics,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(haptics: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.keyboard_return_rounded,
                    title: strings.autoEvaluate,
                    subtitle: strings.autoEvaluateHint,
                    value: settings.autoEvaluate,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(autoEvaluate: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.keyboard_command_key_rounded,
                    title: strings.shortcuts,
                    value: settings.keyboardShortcuts,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(keyboardShortcuts: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.cleaning_services_outlined,
                    title: strings.confirmReset,
                    value: settings.confirmReset,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(confirmReset: value)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.functions_rounded,
                    title: strings.precision,
                    subtitle: strings.precisionHint,
                    value: settings.numberPrecision != NumberPrecision.auto,
                    onChanged: (value) => _update(
                      (s) => s.copyWith(
                        numberPrecision: value
                            ? NumberPrecision.ten
                            : NumberPrecision.auto,
                      ),
                    ),
                  ),
                  if (settings.numberPrecision != NumberPrecision.auto)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: SettingsChoice<NumberPrecision>(
                        values: <NumberPrecision>[
                          NumberPrecision.six,
                          NumberPrecision.eight,
                          NumberPrecision.ten,
                          NumberPrecision.twelve,
                        ],
                        selected: settings.numberPrecision,
                        labelOf: (value) => '${value.digits} ${strings.digits}',
                        onSelected: (value) =>
                            _update((s) => s.copyWith(numberPrecision: value)),
                      ),
                    ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.startPage,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<StartPage>(
                          values: StartPage.values,
                          selected: settings.startPage,
                          labelOf: (value) => switch (value) {
                            StartPage.home => strings.home,
                            StartPage.plotting => strings.plotting,
                            StartPage.history => strings.history,
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(startPage: value)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showData) ...<Widget>[
            SectionHeader(
              title: strings.data,
              subtitle: strings.dataHint,
              icon: Icons.storage_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.historyLimit,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<int>(
                          values: const <int>[25, 50, 100, 200],
                          selected: settings.historyLimit,
                          labelOf: (value) => '$value',
                          onSelected: (value) =>
                              _update((s) => s.copyWith(historyLimit: value)),
                        ),
                      ],
                    ),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.bookmark_add_outlined,
                    title: strings.autoSaveHistory,
                    value: settings.autoSaveHistory,
                    onChanged: (value) =>
                        _update((s) => s.copyWith(autoSaveHistory: value)),
                  ),
                  SettingsActionTile(
                    icon: Icons.delete_sweep_outlined,
                    title: strings.clearHistory,
                    subtitle: strings.historyCount(history.length),
                    onTap: history.isEmpty
                        ? () {}
                        : () => ref
                              .read(calculationHistoryProvider.notifier)
                              .clear(),
                  ),
                  const SoftDivider(indent: 12, endIndent: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.language,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SettingsChoice<AppLocale>(
                          values: AppLocale.values,
                          selected: settings.locale,
                          labelOf: (value) => switch (value) {
                            AppLocale.system => strings.followSystem,
                            AppLocale.english => 'English',
                            AppLocale.simplifiedChinese => '简体中文',
                          },
                          onSelected: (value) =>
                              _update((s) => s.copyWith(locale: value)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (showAbout) ...<Widget>[
            SectionHeader(
              title: strings.about,
              icon: Icons.info_outline_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: SettingsActionTile(
                icon: Icons.calculate_outlined,
                title: l10n.appTitle,
                subtitle: l10n.aboutTagline,
                onTap: () => context.go('/settings/about'),
              ),
            ),
          ],
          if (_query.isNotEmpty &&
              !showAppearance &&
              !showMotion &&
              !showPlot &&
              !showInput &&
              !showData &&
              !showAbout)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(strings.noResults),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _monetSubtitle(MonetSeeds? seeds) {
    final strings = _Strings(context);
    if (!ref.read(appSettingsProvider).monetEnabled) {
      return strings.monetOffHint;
    }
    return switch (seeds?.source) {
      MonetSource.wallpaper => strings.monetWallpaper,
      MonetSource.accent => strings.monetAccent,
      MonetSource.seed => strings.monetFallback,
      null => strings.monetLoading,
    };
  }

  Future<void> _confirmReset(BuildContext context) async {
    final strings = _Strings(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded),
        title: Text(strings.resetAll),
        content: Text(strings.resetConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.resetAll),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref.read(appSettingsProvider.notifier).resetToDefaults();
      _search.clear();
      setState(() => _query = '');
    }
  }

  String _paletteLabel(SeedPalette palette, _Strings strings) =>
      switch (palette) {
        SeedPalette.indigo => strings.indigo,
        SeedPalette.teal => strings.teal,
        SeedPalette.green => strings.green,
        SeedPalette.amber => strings.amber,
        SeedPalette.rose => strings.rose,
        SeedPalette.violet => strings.violet,
        SeedPalette.cyan => strings.cyan,
        SeedPalette.slate => strings.slate,
      };

  String _styleLabel(MonetStyle style, _Strings strings) => switch (style) {
    MonetStyle.tonalSpot => strings.tonalSpot,
    MonetStyle.vibrant => strings.vibrant,
    MonetStyle.expressive => strings.expressive,
    MonetStyle.neutral => strings.neutral,
    MonetStyle.monochrome => strings.monochrome,
  };

  String _contrastLabel(MonetContrast contrast, _Strings strings) =>
      switch (contrast) {
        MonetContrast.standard => strings.standard,
        MonetContrast.medium => strings.medium,
        MonetContrast.high => strings.high,
      };

  String _intensityLabel(ExpressiveIntensity value, _Strings strings) =>
      switch (value) {
        ExpressiveIntensity.foundational => strings.foundational,
        ExpressiveIntensity.excellent => strings.excellent,
        ExpressiveIntensity.transformative => strings.transformative,
      };

  String _intensityDescription(
    AppLocalizations l10n,
    ExpressiveIntensity intensity,
  ) {
    return switch (intensity) {
      ExpressiveIntensity.foundational => l10n.intensityFoundationalDescription,
      ExpressiveIntensity.excellent => l10n.intensityExcellentDescription,
      ExpressiveIntensity.transformative =>
        l10n.intensityTransformativeDescription,
    };
  }
}

/// Live preview of the current choices; it updates with the theme so users can
/// judge a palette before leaving the page.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final strings = _Strings(context);
    return AppCard(
      padding: const EdgeInsets.all(0),
      gradient: <Color>[scheme.primaryContainer, scheme.tertiaryContainer],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: ShapeDecoration(
                    color: scheme.surface.withValues(alpha: 0.55),
                    shape: tokens.keyShape(),
                  ),
                  child: Icon(Icons.calculate_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.previewTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                      Text(
                        strings.previewBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: settings.monetEnabled
                      ? strings.dynamicOn
                      : strings.dynamicOff,
                  color: scheme.onPrimaryContainer,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.show_chart_rounded),
                  label: Text(strings.sampleAction),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: Text(strings.sampleSecondary),
                ),
                ChoiceChip(
                  label: Text(strings.sampleChip),
                  selected: true,
                  onSelected: (_) {},
                ),
                Switch.adaptive(value: true, onChanged: (_) {}),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.motionNote(settings.motionSpeed.scale),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeToggle extends StatelessWidget {
  const _ThemeModeToggle({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = _Strings(context);
    return SegmentedButton<AppThemeMode>(
      showSelectedIcon: false,
      segments: <ButtonSegment<AppThemeMode>>[
        ButtonSegment<AppThemeMode>(
          value: AppThemeMode.system,
          icon: const Icon(Icons.brightness_auto_rounded),
          tooltip: strings.followSystem,
        ),
        ButtonSegment<AppThemeMode>(
          value: AppThemeMode.light,
          icon: const Icon(Icons.light_mode_rounded),
          tooltip: strings.light,
        ),
        ButtonSegment<AppThemeMode>(
          value: AppThemeMode.dark,
          icon: const Icon(Icons.dark_mode_rounded),
          tooltip: strings.dark,
        ),
      ],
      selected: <AppThemeMode>{mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Bilingual strings for the settings surface. Keeping them next to the widgets
/// avoids a 200-key ARB migration for copy that only this page uses.
class _Strings {
  _Strings(this.context);

  final BuildContext context;

  String _t(String en, String zh) => nextEraText(context, en, zh);

  String get appearance => _t('Appearance', '外观');
  String get appearanceHint =>
      _t('Color, shape and type for the whole app', '全局配色、形状与字体');
  String get theme => _t('Theme', '主题');
  String get themeMode => _t('Theme mode', '主题模式');
  String get themeModeHint =>
      _t('Follow the system or pin light / dark', '跟随系统，或固定浅色 / 深色');
  String get system => _t('System', '系统');
  String get light => _t('Light', '浅色');
  String get dark => _t('Dark', '深色');
  String get dynamicColor =>
      _t('Material You dynamic color', '莫奈取色（Material You）');
  String get monetOffHint =>
      _t('Off — using the seed palette', '已关闭 — 使用内置种子色');
  String get monetWallpaper =>
      _t('Wallpaper palette detected (Android 12+)', '已读取壁纸色调（Android 12+）');
  String get monetAccent => _t('Using the system accent color', '正在使用系统强调色');
  String get monetFallback =>
      _t('No system palette here — using the seed color', '当前平台无系统取色 — 使用种子色');
  String get monetLoading => _t('Reading system colors…', '正在读取系统配色…');
  String get seedPalette => _t('Seed palette', '种子配色');
  String get paletteStyle => _t('Palette style', '配色风格');
  String get paletteStyleHint =>
      _t('Affects hue spread and container chroma', '影响色相分布与容器饱和度');
  String get contrast => _t('Tonal contrast', '色调对比度');
  String get intensity => _t('Expressive intensity', '表现力强度');
  String get shapes => _t('Corner shape', '圆角形状');
  String get rounded => _t('Rounded', '圆角');
  String get squircle => _t('Squircle', '超椭圆');
  String get textScale => _t('Text size', '文字大小');
  String get textScaleHint =>
      _t('Scales on top of the system setting', '在系统字号基础上缩放');
  String get boldText => _t('Bolder text', '加粗文字');
  String get highContrast => _t('High contrast', '高对比度');
  String get highContrastHint =>
      _t('Uses the strongest accessible palette', '使用可读性最强的配色');
  String get largeTargets => _t('Larger touch targets', '更大的触控区域');
  String get tooltips => _t('Tooltips', '工具提示');

  String get motion => _t('Motion', '动效');
  String get motionHint =>
      _t('Springs, page transitions and plot animation', '弹簧、页面转场与绘图动画');
  String get motionSpeed => _t('Motion speed', '动效速度');
  String get calm => _t('Calm', '舒缓');
  String get standard => _t('Standard', '标准');
  String get brisk => _t('Brisk', '轻快');
  String get lively => _t('Lively', '活泼');
  String get reduceMotion => _t('Reduce motion', '减弱动效');
  String get reduceMotionHint =>
      _t('Overrides Android / iOS / desktop settings', '可覆盖系统“减弱动态效果”设置');
  String get alwaysReduce => _t('Always', '始终');
  String get alwaysAllow => _t('Never', '从不');
  String get followSystem => _t('System', '跟随系统');
  String get animatePlot => _t('Animate plot drawing', '绘图动画');
  String get animatePlotHint =>
      _t('Curves are drawn in when a result arrives', '结果生成时曲线逐段绘出');

  String get plot => _t('Plotting', '绘图');
  String get plotHint =>
      _t('Sampling, curve style and mesh quality', '采样、曲线样式与网格质量');
  String get resolution => _t('Sampling budget', '采样精度');
  String get resolutionHint =>
      _t('Higher budgets resolve fast oscillations', '更高精度可还原快速振荡');
  String get adaptive => _t('Adaptive', '自适应');
  String get adaptiveSampling => _t('Curvature-aware sampling', '曲率自适应采样');
  String get adaptiveSamplingHint =>
      _t('Adds samples where the curve bends or spikes', '在曲线弯曲或突变处自动加密');
  String get autoResample => _t('Resample while panning', '平移时重新采样');
  String get autoResampleHint => _t(
    'Keeps the whole curve visible after zooming or dragging',
    '缩放或拖动后仍绘制完整曲线',
  );
  String get curveThickness => _t('Curve thickness', '曲线粗细');
  String get grid => _t('Show grid', '显示网格');
  String get axisLabels => _t('Show axis labels', '显示坐标标签');
  String get tapToMark => _t('Tap to place a marker', '点击放置标记');
  String get doubleTapZoom => _t('Double tap to zoom', '双击缩放');
  String get plotBackground => _t('Plot background', '绘图背景');
  String get surface => _t('Surface', '表面');
  String get container => _t('Container', '容器');
  String get contrastOption => _t('High contrast', '高对比');
  String get meshDensity => _t('3D mesh density', '三维网格密度');
  String get low => _t('Low', '低');
  String get medium => _t('Medium', '中');
  String get high => _t('High', '高');

  String get input => _t('Input & behaviour', '输入与行为');
  String get inputHint =>
      _t('Quick input, keyboard and history', '快捷输入、键盘与历史记录');
  String get quickPanel => _t('Quick input layout', '快捷输入面板布局');
  String get quickPanelHint =>
      _t('Automatic adapts to the window size', '“自动”会随窗口尺寸选择底部弹层或侧栏');
  String get automatic => _t('Automatic', '自动');
  String get sheet => _t('Bottom sheet', '底部弹层');
  String get sidePanel => _t('Side panel', '侧边面板');
  String get dialog => _t('Dialog', '对话框');
  String get haptics => _t('Haptic feedback', '触感反馈');
  String get autoEvaluate => _t('Evaluate while typing', '输入时自动计算');
  String get autoEvaluateHint =>
      _t('Debounced; cheaper results appear instantly', '带防抖；轻量结果即时呈现');
  String get shortcuts => _t('Keyboard shortcuts', '键盘快捷键');
  String get confirmReset => _t('Confirm destructive actions', '危险操作前确认');
  String get precision => _t('Fixed result precision', '固定结果精度');
  String get precisionHint =>
      _t('Off keeps adaptive significant digits', '关闭时按数值自适应有效位');
  String get digits => _t('digits', '位');
  String get startPage => _t('Start page', '启动页面');
  String get home => _t('Home', '主页');
  String get plotting => _t('Plotting', '绘图');
  String get history => _t('History', '历史');

  String get data => _t('Data & language', '数据与语言');
  String get dataHint => _t('History size, storage and locale', '历史容量、存储与语言');
  String get historyLimit => _t('History entries kept', '保留的历史条数');
  String get autoSaveHistory =>
      _t('Save calculations automatically', '自动保存计算记录');
  String get clearHistory => _t('Clear history', '清空历史');
  String historyCount(int count) => _t('$count entries', '$count 条记录');
  String get language => _t('Language', '语言');

  String get about => _t('About', '关于');
  String get search => _t('Search settings', '搜索设置');
  String get searchHint => _t('Search settings…', '搜索设置…');
  String get resetAll => _t('Reset all settings', '恢复默认设置');
  String get resetConfirm => _t(
    'Theme, plot, motion and input preferences return to their defaults. History is kept.',
    '主题、绘图、动效与输入偏好将恢复默认值，历史记录会保留。',
  );
  String get noResults => _t('No settings match that search', '没有匹配的设置项');

  String get previewTitle => _t('Live preview', '实时预览');
  String get previewBody => _t(
    'This card uses the same components as the rest of the app',
    '此卡片使用了与应用其余部分相同的组件',
  );
  String get sampleAction => _t('Primary', '主按钮');
  String get sampleSecondary => _t('Secondary', '次按钮');
  String get sampleChip => _t('Selected chip', '已选标签');
  String get dynamicOn => _t('Dynamic', '动态取色');
  String get dynamicOff => _t('Seed', '种子色');
  String motionNote(double scale) => _t(
    'Motion ×${scale.toStringAsFixed(2)}',
    '动效倍率 ×${scale.toStringAsFixed(2)}',
  );

  String get indigo => _t('Indigo', '靛蓝');
  String get teal => _t('Teal', '青绿');
  String get green => _t('Green', '森绿');
  String get amber => _t('Amber', '琥珀');
  String get rose => _t('Rose', '玫红');
  String get violet => _t('Violet', '紫罗兰');
  String get cyan => _t('Cyan', '湖蓝');
  String get slate => _t('Slate', '石板灰');
  String get tonalSpot => _t('Tonal spot', '柔和');
  String get vibrant => _t('Vibrant', '鲜艳');
  String get expressive => _t('Expressive', '表现力');
  String get neutral => _t('Neutral', '中性');
  String get monochrome => _t('Monochrome', '单色');
  String get foundational => _t('Foundational', '基础');
  String get excellent => _t('Excellent', '出色');
  String get transformative => _t('Transformative', '变革');
}
