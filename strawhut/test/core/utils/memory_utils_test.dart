import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/utils/memory_utils.dart';

void main() {
  group('MemoryUtils.wipeBytes', () {
    test('should wipe all bytes in Uint8List to zero', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      MemoryUtils.wipeBytes(bytes);
      expect(bytes, Uint8List.fromList([0, 0, 0, 0, 0]));
    });

    test('should handle empty Uint8List', () {
      final bytes = Uint8List(0);
      MemoryUtils.wipeBytes(bytes);
      expect(bytes, isEmpty);
    });

    test('should wipe bytes that are already zero', () {
      final bytes = Uint8List(5);
      MemoryUtils.wipeBytes(bytes);
      expect(bytes.every((b) => b == 0), isTrue);
    });

    test('should wipe bytes with maximum values', () {
      final bytes = Uint8List.fromList([255, 255, 255]);
      MemoryUtils.wipeBytes(bytes);
      expect(bytes, Uint8List.fromList([0, 0, 0]));
    });

    test('should modify the original array in place', () {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final reference = bytes;
      MemoryUtils.wipeBytes(bytes);
      expect(identical(bytes, reference), isTrue);
      expect(bytes, Uint8List.fromList([0, 0, 0]));
    });
  });

  group('MemoryUtils.secureClearMap', () {
    test('should clear all values in map to null', () {
      final map = <String, dynamic>{
        'key1': 'value1',
        'key2': 42,
        'key3': true,
      };
      MemoryUtils.secureClearMap(map);
      expect(map['key1'], isNull);
      expect(map['key2'], isNull);
      expect(map['key3'], isNull);
    });

    test('should wipe Uint8List values before setting to null', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final map = <String, dynamic>{
        'secret_key': bytes,
      };
      MemoryUtils.secureClearMap(map);
      expect(map['secret_key'], isNull);
      // The original bytes should be wiped
      expect(bytes, Uint8List.fromList([0, 0, 0, 0, 0]));
    });

    test('should wipe List<int> values before setting to null', () {
      final list = <int>[10, 20, 30];
      final map = <String, dynamic>{
        'data': list,
      };
      MemoryUtils.secureClearMap(map);
      expect(map['data'], isNull);
      // The original list should be wiped
      expect(list, [0, 0, 0]);
    });

    test('should handle empty map', () {
      final map = <String, dynamic>{};
      MemoryUtils.secureClearMap(map);
      expect(map, isEmpty);
    });

    test('should preserve keys in the map', () {
      final map = <String, dynamic>{
        'a': 1,
        'b': 2,
        'c': 3,
      };
      MemoryUtils.secureClearMap(map);
      expect(map.keys, containsAll(['a', 'b', 'c']));
      expect(map.values.every((v) => v == null), isTrue);
    });

    test('should handle nested map values (set to null)', () {
      final nestedMap = <String, dynamic>{'inner': 'value'};
      final map = <String, dynamic>{
        'nested': nestedMap,
      };
      MemoryUtils.secureClearMap(map);
      expect(map['nested'], isNull);
    });
  });
}
