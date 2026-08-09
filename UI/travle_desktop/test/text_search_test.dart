import 'package:flutter_test/flutter_test.dart';
import 'package:travle_core/travle_core.dart';

/// Verifies the client-side accent-aware matcher used by the organizer statistics
/// per-tour search mirrors the backend `TextSearch` semantics.
void main() {
  group('accentAwareContains', () {
    test('plain term is accent-insensitive ("Poc" matches "Počitelj")', () {
      expect(accentAwareContains('Blagaj & Počitelj Excursion', 'Poc'), isTrue);
      expect(accentAwareContains('Baščaršija Walk', 'bascar'), isTrue);
      expect(accentAwareContains('Kravice Waterfalls', 'kravice'), isTrue);
    });

    test('accented term stays accent-sensitive', () {
      // "Poč" (accented) must NOT match a plain "Poc..." target...
      expect(accentAwareContains('Pocitelj plain', 'Poč'), isFalse);
      // ...but matches the truly accented target.
      expect(accentAwareContains('Počitelj', 'Poč'), isTrue);
    });

    test('case-insensitive and blank term matches everything', () {
      expect(accentAwareContains('Mostar Old Town', 'OLD'), isTrue);
      expect(accentAwareContains('anything', '   '), isTrue);
      expect(accentAwareContains('anything', 'zzz'), isFalse);
    });
  });
}
