import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';

void main() {
  group('ChunkInfo 构造', () {
    test('应正确构造含必填字段的实例', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));

      final chunkInfo = ChunkInfo(iv: iv, encryptedData: encryptedData);

      expect(chunkInfo.iv, iv);
      expect(chunkInfo.encryptedData, encryptedData);
    });
  });

  group('ChunkInfo 相等性', () {
    test('两个字段完全相同的实例应相等', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));

      final chunk1 = ChunkInfo(iv: iv, encryptedData: encryptedData);
      final chunk2 = ChunkInfo(iv: iv, encryptedData: encryptedData);

      expect(chunk1, equals(chunk2));
    });

    test('两个字段相同的独立实例应相等', () {
      final iv1 = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData1 = Uint8List.fromList(List.generate(32, (i) => i));
      final iv2 = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData2 = Uint8List.fromList(List.generate(32, (i) => i));

      final chunk1 = ChunkInfo(iv: iv1, encryptedData: encryptedData1);
      final chunk2 = ChunkInfo(iv: iv2, encryptedData: encryptedData2);

      expect(chunk1, equals(chunk2));
    });

    test('iv 不同时不应相等', () {
      final iv1 = Uint8List.fromList(List.generate(16, (i) => i));
      final iv2 = Uint8List.fromList(List.generate(16, (i) => i + 16));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));

      final chunk1 = ChunkInfo(iv: iv1, encryptedData: encryptedData);
      final chunk2 = ChunkInfo(iv: iv2, encryptedData: encryptedData);

      expect(chunk1, isNot(equals(chunk2)));
    });

    test('encryptedData 不同时不应相等', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData1 = Uint8List.fromList(List.generate(32, (i) => i));
      final encryptedData2 =
          Uint8List.fromList(List.generate(32, (i) => i + 32));

      final chunk1 = ChunkInfo(iv: iv, encryptedData: encryptedData1);
      final chunk2 = ChunkInfo(iv: iv, encryptedData: encryptedData2);

      expect(chunk1, isNot(equals(chunk2)));
    });

    test('iv 长度不同时不应相等', () {
      final iv1 = Uint8List.fromList(List.generate(16, (i) => i));
      final iv2 = Uint8List.fromList(List.generate(12, (i) => i));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));

      final chunk1 = ChunkInfo(iv: iv1, encryptedData: encryptedData);
      final chunk2 = ChunkInfo(iv: iv2, encryptedData: encryptedData);

      expect(chunk1, isNot(equals(chunk2)));
    });

    test('与自身应相等', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));
      final chunk = ChunkInfo(iv: iv, encryptedData: encryptedData);

      expect(chunk, equals(chunk));
    });

    test('与其他类型不应相等', () {
      final iv = Uint8List.fromList(List.generate(16, (i) => i));
      final encryptedData = Uint8List.fromList(List.generate(32, (i) => i));
      final chunk = ChunkInfo(iv: iv, encryptedData: encryptedData);

      // ignore: unrelated_type_equality_checks
      expect(chunk == 'not a ChunkInfo', isFalse);
    });
  });
}
