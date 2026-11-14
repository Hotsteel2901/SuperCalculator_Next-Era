import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:supercalculator_next_era/app/theme/app_theme.dart';
import 'package:supercalculator_next_era/core/ui/feature_widgets.dart';

/// Regression guard for the collapsed page header.
///
/// The previous implementation hand-rolled a `FlexibleSpaceBar` with a fixed
/// `titlePadding.bottom` that made room for the subtitle. While expanded it
/// looked right; once the bar collapsed the title kept that 44dp offset inside a
/// 56dp toolbar and ended up drawn *above* the bar, under the status bar, with
/// the leading icon floating below it. This test scrolls the frame and checks
/// that every copy of the heading stays inside the pinned toolbar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const double statusBar = 48;
  const double collapsedToolbar = 64;

  Widget host() {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: statusBar),
          viewPadding: EdgeInsets.only(top: statusBar),
        ),
        child: Scaffold(
          body: FeaturePageFrame(
            title: 'Plotting',
            icon: Icons.insights_rounded,
            subtitle: 'Nine plot modes with adaptive sampling and full curves.',
            child: Column(
              children: <Widget>[
                for (var index = 0; index < 12; index++)
                  SizedBox(height: 120, child: Text('row $index')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('collapsed heading stays inside the toolbar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Expanded: the heading belongs to the flexible space, not the toolbar.
    final expanded = tester.getRect(find.text('Plotting').first);
    expect(expanded.top, greaterThan(statusBar));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final titles = find.text('Plotting').evaluate().toList();
    expect(titles, isNotEmpty);
    for (final element in titles) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      // The pinned bar spans the status bar plus one toolbar; nothing may be
      // drawn above it, which is exactly what the old layout did.
      expect(
        rect.top,
        greaterThanOrEqualTo(statusBar),
        reason: 'heading drawn at ${rect.top} is above the pinned bar',
      );
      expect(rect.bottom, lessThanOrEqualTo(statusBar + collapsedToolbar + 1));
    }
  });
}
