import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/data/models/format_version.dart';

void main() {
  group('FormatVersion 构造函数', () {
    test('should create instance with valid version numbers', () {
      const version = FormatVersion(1, 2, 3);
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
    });

    test('should create instance with zero version', () {
      const version = FormatVersion(0, 0, 0);
      expect(version.major, 0);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });

    test('should create instance with large version numbers', () {
      const version = FormatVersion(999, 999, 999);
      expect(version.major, 999);
      expect(version.minor, 999);
      expect(version.patch, 999);
    });
  });

  group('FormatVersion.fromString 正面测试', () {
    test('should parse standard version string', () {
      final version = FormatVersion.fromString('1.0.0');
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });

    test('should parse version with all non-zero components', () {
      final version = FormatVersion.fromString('2.3.4');
      expect(version.major, 2);
      expect(version.minor, 3);
      expect(version.patch, 4);
    });

    test('should parse zero version "0.0.0"', () {
      final version = FormatVersion.fromString('0.0.0');
      expect(version.major, 0);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });

    test('should parse large version numbers', () {
      final version = FormatVersion.fromString('999.999.999');
      expect(version.major, 999);
      expect(version.minor, 999);
      expect(version.patch, 999);
    });
  });

  group('FormatVersion.fromString 负面测试', () {
    test('should throw FormatException for empty string', () {
      expect(
        () => FormatVersion.fromString(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for single segment', () {
      expect(
        () => FormatVersion.fromString('1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for two segments', () {
      expect(
        () => FormatVersion.fromString('1.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for four segments', () {
      expect(
        () => FormatVersion.fromString('1.0.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for non-numeric major', () {
      expect(
        () => FormatVersion.fromString('abc.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for non-numeric minor', () {
      expect(
        () => FormatVersion.fromString('1.abc.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for non-numeric patch', () {
      expect(
        () => FormatVersion.fromString('1.0.abc'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for negative major version', () {
      expect(
        () => FormatVersion.fromString('-1.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for negative minor version', () {
      expect(
        () => FormatVersion.fromString('1.-1.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for negative patch version', () {
      expect(
        () => FormatVersion.fromString('1.0.-1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for mixed valid and invalid segments', () {
      expect(
        () => FormatVersion.fromString('1.2.x'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should throw FormatException for decimal numbers', () {
      expect(
        () => FormatVersion.fromString('1.0.0.5'),
        throwsA(isA<FormatException>()),
      );
    });

    test('should accept version string with leading/trailing whitespace', () {
      final version = FormatVersion.fromString(' 1.0.0');
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });

    test('should accept version string with spaces around numbers', () {
      final version = FormatVersion.fromString('1. 0. 0');
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });
  });

  group('FormatVersion.fromJson', () {
    test('should parse version from JSON string', () {
      final version = FormatVersion.fromJson('1.2.3');
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
    });

    test('should throw FormatException for invalid JSON string', () {
      expect(
        () => FormatVersion.fromJson('invalid'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('FormatVersion.toString()', () {
    test('should return correct string representation', () {
      const version = FormatVersion(1, 2, 3);
      expect(version.toString(), '1.2.3');
    });

    test('should return "0.0.0" for zero version', () {
      const version = FormatVersion(0, 0, 0);
      expect(version.toString(), '0.0.0');
    });
  });

  group('FormatVersion 相等性比较', () {
    test('should be equal for same version numbers', () {
      const v1 = FormatVersion(1, 2, 3);
      const v2 = FormatVersion(1, 2, 3);
      expect(v1, equals(v2));
    });

    test('should not be equal for different major version', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(2, 0, 0);
      expect(v1 == v2, isFalse);
    });

    test('should not be equal for different minor version', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(1, 1, 0);
      expect(v1 == v2, isFalse);
    });

    test('should not be equal for different patch version', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(1, 0, 1);
      expect(v1 == v2, isFalse);
    });

    test('should have same hashCode for equal versions', () {
      const v1 = FormatVersion(1, 2, 3);
      const v2 = FormatVersion(1, 2, 3);
      expect(v1.hashCode, equals(v2.hashCode));
    });

    test('should have different hashCode for different versions', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(2, 0, 0);
      expect(v1.hashCode, isNot(equals(v2.hashCode)));
    });
  });

  group('FormatVersion.isCompatibleWith', () {
    test('should be compatible with same major version', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(1, 5, 0);
      expect(v1.isCompatibleWith(v2), isTrue);
    });

    test('should not be compatible with different major version', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(2, 0, 0);
      expect(v1.isCompatibleWith(v2), isFalse);
    });

    test('should be compatible with higher minor/patch versions', () {
      const v1 = FormatVersion(1, 0, 0);
      const v2 = FormatVersion(1, 99, 99);
      expect(v1.isCompatibleWith(v2), isTrue);
    });
  });

  group('FormatVersion @immutable', () {
    test('should have immutable fields', () {
      const version = FormatVersion(1, 2, 3);
      // All fields are final, cannot be modified
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
    });
  });
}
