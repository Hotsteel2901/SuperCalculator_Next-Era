import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supercalculator_next_era/app/theme/app_theme.dart';
import 'package:supercalculator_next_era/core/settings/app_settings.dart';
import 'package:supercalculator_next_era/l10n/localization.dart';
import 'package:supercalculator_next_era/features/plotting/quick_input_panel.dart';
import 'package:supercalculator_next_era/features/plotting/symbol_catalog.dart';

Widget _host({
  required TextEditingController target,
  ValueChanged<String>? onChanged,
  VoidCallback? onSubmit,
  AppSettings settings = AppSettings.defaults,
}) {
  return ProviderScope(
    overrides: [
      initialSettingsProvider.overrideWithValue(settings),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
      theme: buildAppTheme(Brightness.light, settings: settings),
      home: Scaffold(
        body: QuickInputPanel(
          target: target,
          onChanged: onChanged ?? (_) {},
          onSubmit: onSubmit ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('quick input panel exposes search, tabs and the symbol grid', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(target: controller));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    // A representative symbol from the catalog is on screen.
    expect(find.text(SymbolCatalog.all.first.label), findsWidgets);
  });

  testWidgets('tapping a symbol inserts it into the target editor', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changes = 0;

    await tester.pumpWidget(
      _host(target: controller, onChanged: (_) => changes++),
    );
    await tester.pumpAndSettle();

    final symbol = SymbolCatalog.all.firstWhere(
      (MathSymbol item) => item.id == 'sq',
    );
    await tester.tap(find.text(symbol.label).first);
    await tester.pumpAndSettle();

    expect(controller.text, symbol.insertion);
    expect(changes, greaterThan(0));
  });

  testWidgets('panel works with the compact bottom-sheet density', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        target: controller,
        settings: AppSettings.defaults.copyWith(
          quickPanelLayout: QuickPanelLayout.bottomSheet,
          largeTouchTargets: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GridView), findsOneWidget);
  });
}
