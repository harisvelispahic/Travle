import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travle_ui/travle_ui.dart';

/// Regression tests for the reason-prompt dialog every destructive decision uses.
///
/// The bug these lock down: `showDialog`'s future completes synchronously when the
/// route is popped, while the dialog is still animating out with a live
/// `EditableText`. Each screen used to own the controller and dispose it from
/// `.whenComplete(...)`, which killed it mid-animation — throwing "A
/// TextEditingController was used after being disposed" and, in the running app,
/// a duplicate `_OverlayEntryWidgetState` GlobalKey cascade. It only fired when the
/// field still held focus, i.e. exactly the Escape and barrier paths (tapping a
/// button moves focus off the field first), which is why the button path looked fine.
void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    ValueChanged<String?> onResult, {
    bool isRequired = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showReasonDialog(
                  context,
                  title: 'Reject booking',
                  label: 'Reason (sent to the traveler)',
                  confirmLabel: 'Reject',
                  isRequired: isRequired,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('Escape closes it without disposing the controller too early',
      (tester) async {
    String? result = 'sentinel';
    await pumpHost(tester, (r) => result = r);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    // A dismissal is null, never an empty reason.
    expect(result, isNull);
  });

  testWidgets('tapping the barrier closes it cleanly', (tester) async {
    String? result = 'sentinel';
    await pumpHost(tester, (r) => result = r);

    // Top-left corner is outside the centred dialog — i.e. the barrier.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('a required reason blocks confirm until it is filled in',
      (tester) async {
    String? result = 'sentinel';
    await pumpHost(tester, (r) => result = r);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'stays open');
    expect(find.text('A reason is required'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Not enough seats  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'Not enough seats');
  });

  testWidgets('an optional reason may be confirmed empty', (tester) async {
    String? result = 'sentinel';
    await pumpHost(tester, (r) => result = r, isRequired: false);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, '');
  });
}
