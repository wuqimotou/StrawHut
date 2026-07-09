import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';

void main() {
  // ========== 辅助函数：创建测试用 StrawFile ==========
  StrawFile _createTestStrawFile() => StrawFile(
        formatVersion: const FormatVersion(2, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '分块测试卡片',
          isAnonymous: false,
        ),
        content: const StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: 1048576,
          totalChunks: 2,
          originalPayloadSize: 1500000,
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

  // ========== 辅助函数：创建测试用 ChunkInfo ==========
  ChunkInfo _createTestChunk({int seed = 0}) {
    return ChunkInfo(
      iv: Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xFF)),
      encryptedData: Uint8List.fromList(
        List.generate(32, (i) => (i + seed) & 0xFF),
      ),
    );
  }

  group('ParsedStrawFile 构造', () {
    test('应正确构造含 strawFile 和 chunks 的实例', () {
      final strawFile = _createTestStrawFile();
      final chunks = [_createTestChunk(seed: 0), _createTestChunk(seed: 1)];

      final parsed = ParsedStrawFile(strawFile: strawFile, chunks: chunks);

      expect(parsed.strawFile, strawFile);
      expect(parsed.chunks.length, 2);
      expect(parsed.chunks[0], chunks[0]);
      expect(parsed.chunks[1], chunks[1]);
    });

    test('应支持空 chunks 列表', () {
      final strawFile = _createTestStrawFile();

      final parsed = ParsedStrawFile(strawFile: strawFile, chunks: []);

      expect(parsed.chunks, isEmpty);
    });
  });

  group('ParsedStrawFile 相等性', () {
    test('两个字段完全相同的实例应相等', () {
      final strawFile = _createTestStrawFile();
      final chunks = [_createTestChunk(seed: 0)];

      final parsed1 = ParsedStrawFile(strawFile: strawFile, chunks: chunks);
      final parsed2 = ParsedStrawFile(strawFile: strawFile, chunks: chunks);

      expect(parsed1, equals(parsed2));
    });

    test('strawFile 不同时不应相等', () {
      final strawFile1 = _createTestStrawFile();
      final strawFile2 = StrawFile(
        formatVersion: const FormatVersion(2, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'DifferentUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '不同的标题',
          isAnonymous: false,
        ),
        content: const StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: 1048576,
          totalChunks: 2,
          originalPayloadSize: 1500000,
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );
      final chunks = [_createTestChunk(seed: 0)];

      final parsed1 = ParsedStrawFile(strawFile: strawFile1, chunks: chunks);
      final parsed2 = ParsedStrawFile(strawFile: strawFile2, chunks: chunks);

      expect(parsed1, isNot(equals(parsed2)));
    });

    test('chunks 不同时不应相等', () {
      final strawFile = _createTestStrawFile();
      final chunks1 = [_createTestChunk(seed: 0)];
      final chunks2 = [_createTestChunk(seed: 1)];

      final parsed1 = ParsedStrawFile(strawFile: strawFile, chunks: chunks1);
      final parsed2 = ParsedStrawFile(strawFile: strawFile, chunks: chunks2);

      expect(parsed1, isNot(equals(parsed2)));
    });

    test('chunks 长度不同时不应相等', () {
      final strawFile = _createTestStrawFile();
      final chunks1 = [_createTestChunk(seed: 0)];
      final chunks2 = [
        _createTestChunk(seed: 0),
        _createTestChunk(seed: 1),
      ];

      final parsed1 = ParsedStrawFile(strawFile: strawFile, chunks: chunks1);
      final parsed2 = ParsedStrawFile(strawFile: strawFile, chunks: chunks2);

      expect(parsed1, isNot(equals(parsed2)));
    });

    test('与自身应相等', () {
      final strawFile = _createTestStrawFile();
      final chunks = [_createTestChunk(seed: 0)];
      final parsed = ParsedStrawFile(strawFile: strawFile, chunks: chunks);

      expect(parsed, equals(parsed));
    });
  });
}
