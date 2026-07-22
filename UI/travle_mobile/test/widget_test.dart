import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travle_mobile/main.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No persisted session in tests: stub the secure-storage channel so the
    // launch splash resolves straight to the login screen.
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  });

  testWidgets('shows the login screen when signed out', (tester) async {
    await tester.pumpWidget(const TravleMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
