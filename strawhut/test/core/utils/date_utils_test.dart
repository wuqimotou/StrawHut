import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/errors/format_exception.dart';
import 'package:strawhut/core/utils/date_utils.dart';

void main() {
  group('DateUtils.formatToISO8601', () {
    test('should return a non-empty string', () {
      final result = DateUtils.formatToISO8601();
      expect(result, isNotEmpty);
    });

    test('should return a string that can be parsed back to DateTime', () {
      final result = DateUtils.formatToISO8601();
      final parsed = DateTime.parse(result);
      expect(parsed, isA<DateTime>());
    });

    test('should produce UTC time (ends with Z or contains offset)', () {
      final result = DateUtils.formatToISO8601();
      // ISO 8601 UTC format should end with 'Z' or contain timezone info
      final parsed = DateUtils.parseISO8601(result);
      expect(parsed.isUtc, isTrue);
    });

    test('should match ISO 8601 format pattern', () {
      final result = DateUtils.formatToISO8601();
      // ISO 8601 pattern: YYYY-MM-DDTHH:MM:SS.mmmZ
      final regex = RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
      );
      expect(regex.hasMatch(result), isTrue);
    });

    test('should return recent time', () {
      final before = DateTime.now().toUtc();
      final result = DateUtils.formatToISO8601();
      final after = DateTime.now().toUtc();
      final parsed = DateUtils.parseISO8601(result);
      // The parsed time should be between before and after (with some tolerance)
      expect(
        parsed.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        parsed.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('DateUtils.parseISO8601', () {
    test('should parse basic ISO 8601 date string', () {
      const isoString = '2026-05-02T12:30:45Z';
      final result = DateUtils.parseISO8601(isoString);
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 2);
      expect(result.hour, 12);
      expect(result.minute, 30);
      expect(result.second, 45);
    });

    test('should parse ISO 8601 with milliseconds', () {
      const isoString = '2026-05-02T12:30:45.123Z';
      final result = DateUtils.parseISO8601(isoString);
      expect(result.millisecond, 123);
    });

    test('should parse ISO 8601 with timezone offset', () {
      const isoString = '2026-05-02T12:30:45+08:00';
      final result = DateUtils.parseISO8601(isoString);
      // When parsed, it converts to local time but the instant is correct
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 2);
    });

    test('should parse UTC midnight', () {
      const isoString = '2026-01-01T00:00:00Z';
      final result = DateUtils.parseISO8601(isoString);
      expect(result.year, 2026);
      expect(result.month, 1);
      expect(result.day, 1);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('should throw StrawFormatException on invalid string', () {
      expect(
        () => DateUtils.parseISO8601('not-a-date'),
        throwsA(isA<StrawFormatException>()),
      );
    });

    test('should throw StrawFormatException on empty string', () {
      expect(
        () => DateUtils.parseISO8601(''),
        throwsA(isA<StrawFormatException>()),
      );
    });
  });

  group('DateUtils roundtrip', () {
    test('should roundtrip through formatToISO8601 and parseISO8601', () {
      // Use a fixed time for testing
      final isoString = DateUtils.formatToISO8601();
      final parsed = DateUtils.parseISO8601(isoString);
      // Re-format and compare
      final reformatted = parsed.toIso8601String();
      expect(reformatted, isoString);
    });
  });
}
