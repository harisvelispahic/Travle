import 'package:flutter_test/flutter_test.dart';
import 'package:travle_desktop/main.dart';

void main() {
  testWidgets('shows the login screen when signed out', (tester) async {
    await tester.pumpWidget(const TravleDesktopApp());
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Travle Management'), findsOneWidget);
  });
}
