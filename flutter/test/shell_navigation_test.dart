import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supercalculator_next_era/app/app.dart';
import 'package:supercalculator_next_era/core/settings/app_settings.dart';
import 'package:supercalculator_next_era/features/calculus/calculus_page.dart';
import 'package:supercalculator_next_era/features/home/home_page.dart';
import 'package:supercalculator_next_era/features/plotting/plot_page.dart';

/// Guards the shell's navigation slot.
///
/// The shell used to wrap go_router's nested navigator in an `AnimatedSwitcher`
/// keyed by location. Both copies of the navigator existed at once while the
/// cross-fade ran, which raised "Multiple widgets used the same GlobalKey" and
/// left the body blank until something else forced a rebuild. These tests drive
/// both entry points (bottom bar and the "More" sheet) and require the target
/// page to be mounted and painted immediately afterwards.
Future<void> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(AppSettings.defaults),
      ],
      child: const SuperCalculatorApp(),
    ),
  );
  // The launch gate holds the first frame for ~1.4s.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('bottom bar destination swaps the page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _boot(tester);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.text('Plotting').last);
    // The plot surface animates continuously, so `pumpAndSettle` would never
    // return; a fixed span covers the page transition instead.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(PlotPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('more sheet destination swaps the page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _boot(tester);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('All sections'), findsOneWidget);

    await tester.tap(find.text('Calculus').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CalculusPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('sidebar destination swaps the page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _boot(tester);

    await tester.tap(find.text('Calculus').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CalculusPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });
}
