import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supercalculator_next_era/app/theme/app_theme.dart';
import 'package:supercalculator_next_era/features/calculus/calculus_page.dart';
import 'package:supercalculator_next_era/features/data_analysis/data_analysis_page.dart';
import 'package:supercalculator_next_era/features/equations/equations_page.dart';
import 'package:supercalculator_next_era/features/history/history_page.dart';
import 'package:supercalculator_next_era/features/home/home_page.dart';
import 'package:supercalculator_next_era/features/linear_algebra/linear_algebra_page.dart';
import 'package:supercalculator_next_era/features/ode/ode_page.dart';
import 'package:supercalculator_next_era/features/plotting/plot_page.dart';
import 'package:supercalculator_next_era/features/settings/about_page.dart';
import 'package:supercalculator_next_era/features/settings/settings_page.dart';
import 'package:supercalculator_next_era/features/signals/signals_page.dart';
import 'package:supercalculator_next_era/features/statistics/statistics_page.dart';
import 'package:supercalculator_next_era/features/tools/advanced_tools_page.dart';
import 'package:supercalculator_next_era/features/tools/tools_page.dart';
import 'package:supercalculator_next_era/l10n/generated/app_localizations.dart';

/// Layout guard for every page at phone and desktop widths.
///
/// `RenderFlex overflowed` is reported as a test failure, and so is any other
/// build exception, so a page that only fits on one form factor (or a title bar
/// that mis-measures its heading) shows up here instead of on a device.
Widget _host(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      // The shell provides the Scaffold in the real app; repeating it here keeps
      // the Material ancestor requirements identical to production.
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, Widget Function()>{
    'home': HomePage.new,
    'plotting': PlotPage.new,
    'calculus': CalculusPage.new,
    'equations': EquationsPage.new,
    'ode': OdePage.new,
    'signals': SignalsPage.new,
    'statistics': StatisticsPage.new,
    'data analysis': DataAnalysisPage.new,
    'linear algebra': LinearAlgebraPage.new,
    'tools': ToolsPage.new,
    'advanced tools': AdvancedToolsPage.new,
    'history': HistoryPage.new,
    'settings': SettingsPage.new,
    'about': AboutPage.new,
  };

  for (final size in <Size>[
    const Size(320, 640),
    const Size(360, 780),
    const Size(768, 900),
    const Size(1440, 900),
  ]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} lays out at ${size.width.toInt()}px', (
        WidgetTester tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(entry.value()));
        // Let async providers (history, symbols, sampling) settle.
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(tester.takeException(), isNull);
      });
    }
  }
}
