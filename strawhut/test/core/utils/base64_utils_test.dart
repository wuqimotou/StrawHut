import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/utils/base64_utils.dart';

void main() {
  group('Base64Utils.encodeToBase64', () {
    test('should encode empty Uint8List to empty string', () {
      final input = Uint8List(0);
      final result = Base64Utils.encodeToBase64(input);
      expect(result, '');
    });

    test('should encode simple bytes correctly', () {
      final input = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      final result = Base64Utils.encodeToBase64(input);
      expect(result, 'SGVsbG8=');
    });

    test('should encode ASCII string correctly', () {
      final input = utf8.encode('Hello, World!');
      final result = Base64Utils.encodeToBase64(Uint8List.fromList(input));
      expect(result, 'SGVsbG8sIFdvcmxkIQ==');
    });

    test('should encode binary data with padding', () {
      final input = Uint8List.fromList([0, 1, 2, 3]);
      final result = Base64Utils.encodeToBase64(input);
      expect(result, 'AAECAw==');
    });

    test('should encode bytes that produce + and / in standard base64', () {
      // Bytes that produce + and / characters
      final input = Uint8List.fromList([251, 255, 254]);
      final result = Base64Utils.encodeToBase64(input);
      expect(result, '+//+');
    });
  });

  group('Base64Utils.decodeFromBase64', () {
    test('should decode empty string to empty Uint8List', () {
      final result = Base64Utils.decodeFromBase64('');
      expect(result, isEmpty);
    });

    test('should decode simple base64 correctly', () {
      final result = Base64Utils.decodeFromBase64('SGVsbG8=');
      expect(result, [72, 101, 108, 108, 111]);
    });

    test('should decode ASCII string correctly', () {
      final result = Base64Utils.decodeFromBase64('SGVsbG8sIFdvcmxkIQ==');
      expect(utf8.decode(result), 'Hello, World!');
    });

    test('should decode binary data with padding', () {
      final result = Base64Utils.decodeFromBase64('AAECAw==');
      expect(result, [0, 1, 2, 3]);
    });

    test('should decode base64 with + and / characters', () {
      final result = Base64Utils.decodeFromBase64('+//+');
      expect(result, [251, 255, 254]);
    });

    test('should throw FormatException on invalid base64', () {
      expect(
        () => Base64Utils.decodeFromBase64('invalid!!!'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Base64Utils encode/decode roundtrip', () {
    test('should roundtrip random bytes', () {
      final original = Uint8List.fromList(
        List.generate(100, (i) => i % 256),
      );
      final encoded = Base64Utils.encodeToBase64(original);
      final decoded = Base64Utils.decodeFromBase64(encoded);
      expect(decoded, original);
    });

    test('should roundtrip UTF-8 encoded Chinese text', () {
      final text = '你好，世界！';
      final original = utf8.encode(text);
      final encoded = Base64Utils.encodeToBase64(Uint8List.fromList(original));
      final decoded = Base64Utils.decodeFromBase64(encoded);
      expect(utf8.decode(decoded), text);
    });
  });

  group('Base64Utils.encodeToBase64Url', () {
    test('should encode string to URL-safe base64', () {
      final result = Base64Utils.encodeToBase64Url('Hello, World!');
      // URL-safe base64 should not contain + or /
      expect(result.contains('+'), isFalse);
      expect(result.contains('/'), isFalse);
    });

    test('should use - instead of +', () {
      // Data that would produce + in standard base64
      final result = Base64Utils.encodeToBase64Url(
        String.fromCharCodes([251, 239]),
      );
      expect(result.contains('+'), isFalse);
    });

    test('should use _ instead of /', () {
      // Data that would produce / in standard base64
      final result = Base64Utils.encodeToBase64Url(
        String.fromCharCodes([255, 255]),
      );
      expect(result.contains('/'), isFalse);
    });

    test('should produce valid URL-safe base64 with padding', () {
      final result = Base64Utils.encodeToBase64Url('test');
      // Dart's base64Url.encode includes padding by default
      expect(result, 'dGVzdA==');
      // But it should not contain + or /
      expect(result.contains('+'), isFalse);
      expect(result.contains('/'), isFalse);
    });

    test('should handle empty string', () {
      final result = Base64Utils.encodeToBase64Url('');
      expect(result, '');
    });
  });
}
