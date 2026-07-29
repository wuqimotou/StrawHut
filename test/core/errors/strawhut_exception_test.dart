import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/core/errors/format_exception.dart';
import 'package:strawhut/core/errors/strawhut_exception.dart';

void main() {
  group('StrawHutException', () {
    test('should create exception with message only', () {
      const exception = TestException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      const exception = TestException('Test error', code: 'TEST_001');

      expect(exception.message, 'Test error');
      expect(exception.code, 'TEST_001');
    });

    test('should format toString with runtimeType', () {
      const exceptionWithCode = TestException('Error', code: 'ERR_001');
      expect(exceptionWithCode.toString(), 'TestException(ERR_001): Error');
    });

    test('should format toString with null code', () {
      const exceptionWithoutCode = TestException('Error');
      expect(exceptionWithoutCode.toString(), 'TestException(null): Error');
    });

    test('should show specific type for CryptoException', () {
      const cryptoException = CryptoException('Failed', code: 'CRYPTO_001');
      expect(cryptoException.toString(), 'CryptoException(CRYPTO_001): Failed');
    });

    test('should show specific type for FileException', () {
      const fileException = FileException('Not found', code: 'FILE_001');
      expect(fileException.toString(), 'FileException(FILE_001): Not found');
    });
  });

  group('CryptoException', () {
    test('should create exception with message only', () {
      const exception = CryptoException('Encryption failed');

      expect(exception.message, 'Encryption failed');
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      const exception = CryptoException(
        'Key generation failed',
        code: 'CRYPTO_001',
      );

      expect(exception.message, 'Key generation failed');
      expect(exception.code, 'CRYPTO_001');
    });

    test('should inherit from StrawHutException', () {
      const exception = CryptoException('Test');
      expect(exception, isA<StrawHutException>());
    });

    test('should implement Exception', () {
      const exception = CryptoException('Test');
      expect(exception, isA<Exception>());
    });
  });

  group('FileException', () {
    test('should create exception with message only', () {
      const exception = FileException('File not found');

      expect(exception.message, 'File not found');
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      const exception = FileException('Permission denied', code: 'FILE_001');

      expect(exception.message, 'Permission denied');
      expect(exception.code, 'FILE_001');
    });

    test('should inherit from StrawHutException', () {
      const exception = FileException('Test');
      expect(exception, isA<StrawHutException>());
    });

    test('should implement Exception', () {
      const exception = FileException('Test');
      expect(exception, isA<Exception>());
    });
  });

  group('StrawFormatException', () {
    test('should create exception with message only', () {
      const exception = StrawFormatException('Invalid format');

      expect(exception.message, 'Invalid format');
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      const exception = StrawFormatException(
        'Missing required field',
        code: 'FORMAT_001',
      );

      expect(exception.message, 'Missing required field');
      expect(exception.code, 'FORMAT_001');
    });

    test('should inherit from StrawHutException', () {
      const exception = StrawFormatException('Test');
      expect(exception, isA<StrawHutException>());
    });

    test('should implement Exception', () {
      const exception = StrawFormatException('Test');
      expect(exception, isA<Exception>());
    });
  });

  group('Exception Hierarchy', () {
    test('all custom exceptions should be catchable as StrawHutException', () {
      const exceptions = <StrawHutException>[
        CryptoException('crypto'),
        FileException('file'),
        StrawFormatException('format'),
      ];

      for (final exception in exceptions) {
        expect(exception, isA<StrawHutException>());
        expect(exception, isA<Exception>());
      }
    });
  });
}

class TestException extends StrawHutException {
  const TestException(super.message, {super.code});
}
