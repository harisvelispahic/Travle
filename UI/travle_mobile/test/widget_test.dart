import 'package:flutter_test/flutter_test.dart';
import 'package:travle_mobile/main.dart';

void main() {
  testWidgets('shows the login screen when signed out', (tester) async {
    await tester.pumpWidget(const TravleMobileApp());
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
