import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travle_ui/travle_ui.dart';

/// Guards the metric rows against the "BoxConstraints forces an infinite height" crash.
///
/// Two patterns are in use and both are exercised here inside a `ListView` (i.e. with an
/// unbounded height), because that is the context that produced the original crash:
///
/// * the organizer/curator statistics rows — a `Row(crossAxisAlignment: stretch)` of
///   `StatTile`s, which must be wrapped in `IntrinsicHeight` to bound the cross-axis;
/// * the admin dashboard's metric row — a `LayoutBuilder` + `Wrap` of fixed-width tiles
///   that reflows 5/3/2 per row by available width (Phase 12), which bounds itself.
void main() {
  testWidgets('stretched StatTile row inside a ListView lays out without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: StatTile(
                        label: 'Users',
                        value: '12',
                        icon: Icons.group_outlined,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Pending requests',
                        value: '2',
                        sub: '1 applications · 1 destinations',
                        icon: Icons.pending_actions_outlined,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Revenue this month',
                        value: '200.00 KM',
                        icon: Icons.account_balance_wallet_outlined,
                        emphasize: true,
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

    expect(tester.takeException(), isNull);
    expect(find.byType(StatTile), findsNWidgets(3));
  });

  testWidgets('the dashboard LayoutBuilder + Wrap metric row reflows without exceptions',
      (tester) async {
    // Mirrors _MetricsRow in dashboard_screen.dart: a width-driven Wrap of five tiles
    // sitting directly in a ListView.
    Widget metrics() => LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 1180
                ? 5
                : constraints.maxWidth >= 760
                    ? 3
                    : 2;
            final width = (constraints.maxWidth - 12.0 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final label in const [
                  'Users',
                  'Bookings',
                  'Active tours',
                  'Pending requests',
                  'Revenue this month',
                ])
                  SizedBox(
                    width: width,
                    child: StatTile(
                      label: label,
                      value: '12',
                      sub: 'all time',
                      icon: Icons.group_outlined,
                    ),
                  ),
              ],
            );
          },
        );

    // Wide (5 per row), medium (3) and narrow (2) all have to lay out cleanly.
    for (final size in const [Size(1600, 900), Size(1000, 900), Size(600, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ListView(children: [metrics()]))),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'at width ${size.width}');
      expect(find.byType(StatTile), findsNWidgets(5));
    }
  });
}
