import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travle_ui/travle_ui.dart';

/// Guards the dashboard/statistics metric rows against the "BoxConstraints forces an
/// infinite height" crash: a `Row(crossAxisAlignment: stretch)` of `StatTile`s inside
/// a `ListView` (unbounded height) must be wrapped in `IntrinsicHeight` to bound the
/// cross-axis. This reproduces that exact pattern and asserts it lays out cleanly.
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
}
