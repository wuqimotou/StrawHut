import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';

void main() {
  group('PassphraseStrengthService.evaluate - strength levels', () {
    test('very short passphrase should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('abc'),
          PassphraseStrength.veryWeak);
    });

    test('7-character passphrase should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('abcdefg'),
          PassphraseStrength.veryWeak);
    });

    test('8-character letters-only should be weak', () {
      expect(PassphraseStrengthService.evaluate('abcdefgh'),
          PassphraseStrength.weak);
    });

    test('12-character with letters and digits should be medium', () {
      expect(PassphraseStrengthService.evaluate('abcdefghijkl1'),
          PassphraseStrength.medium);
    });

    test('16-character with 3+ char types should be strong', () {
      expect(PassphraseStrengthService.evaluate('Abcdefghijkl123!'),
          PassphraseStrength.strong);
    });
  });

  group('PassphraseStrengthService.evaluate - special interception rules', () {
    test('empty string should be veryWeak', () {
      expect(
          PassphraseStrengthService.evaluate(''), PassphraseStrength.veryWeak);
    });

    test('whitespace-only should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('   '),
          PassphraseStrength.veryWeak);
    });

    test('6 consecutive same chars should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('aaaaaa1B!xyz'),
          PassphraseStrength.veryWeak);
    });

    test('consecutive digit sequence 123456 should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('abc123456xyz'),
          PassphraseStrength.veryWeak);
    });

    test('consecutive digit sequence 654321 should be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('abc654321xyz'),
          PassphraseStrength.veryWeak);
    });

    test('5 consecutive same chars should NOT be veryWeak', () {
      expect(PassphraseStrengthService.evaluate('aaaaaB1!xyz12'),
          isNot(equals(PassphraseStrength.veryWeak)));
    });
  });

  group('PassphraseStrengthService.evaluate - boundary conditions', () {
    test('exactly 12 chars with letters and digits should be medium', () {
      expect(PassphraseStrengthService.evaluate('aBcDeFgHiJk1'),
          PassphraseStrength.medium);
    });

    test('exactly 16 chars with 3 types should be strong', () {
      expect(PassphraseStrengthService.evaluate('aBcDeFgHiJkLmN1!'),
          PassphraseStrength.strong);
    });

    test('15 chars with 3 types should be medium (not strong)', () {
      expect(PassphraseStrengthService.evaluate('aBcDeFgHiJkL1!'),
          PassphraseStrength.medium);
    });
  });
}
