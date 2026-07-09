import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/data/models/straw_content.dart';

void main() {
  group('StrawContent 构造', () {
    test('应正确构造含必填字段的实例', () {
      const content = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 3,
        originalPayloadSize: 2500000,
      );

      expect(content.encryptionAlgorithm, 'AES-256-GCM');
      expect(content.chunkSize, 1048576);
      expect(content.totalChunks, 3);
      expect(content.originalPayloadSize, 2500000);
      expect(content.saltBase64, isNull);
      expect(content.kdfAlgorithm, isNull);
      expect(content.kdfIterations, isNull);
    });

    test('应正确构造含可选字段的实例', () {
      const content = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 500,
        saltBase64: 'c2FsdDE2Ynl0ZXM=',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );

      expect(content.saltBase64, 'c2FsdDE2Ynl0ZXM=');
      expect(content.kdfAlgorithm, 'PBKDF2-HMAC-SHA256');
      expect(content.kdfIterations, 100000);
    });
  });

  group('StrawContent.toJson / fromJson 往返', () {
    test('仅含必填字段的序列化循环应还原所有字段', () {
      const original = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 5,
        originalPayloadSize: 5000000,
      );

      final json = original.toJson();
      final restored = StrawContent.fromJson(json);

      expect(restored.encryptionAlgorithm, original.encryptionAlgorithm);
      expect(restored.chunkSize, original.chunkSize);
      expect(restored.totalChunks, original.totalChunks);
      expect(restored.originalPayloadSize, original.originalPayloadSize);
      expect(restored.saltBase64, isNull);
      expect(restored.kdfAlgorithm, isNull);
      expect(restored.kdfIterations, isNull);
    });

    test('含可选字段的序列化循环应还原所有字段', () {
      const original = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 2,
        originalPayloadSize: 1500000,
        saltBase64: 'c2FsdA==',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );

      final json = original.toJson();
      final restored = StrawContent.fromJson(json);

      expect(restored.encryptionAlgorithm, original.encryptionAlgorithm);
      expect(restored.chunkSize, original.chunkSize);
      expect(restored.totalChunks, original.totalChunks);
      expect(restored.originalPayloadSize, original.originalPayloadSize);
      expect(restored.saltBase64, original.saltBase64);
      expect(restored.kdfAlgorithm, original.kdfAlgorithm);
      expect(restored.kdfIterations, original.kdfIterations);
    });

    test('toJson 应使用正确的 snake_case 键名', () {
      const content = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
      );

      final json = content.toJson();

      expect(json.containsKey('encryption_algorithm'), true);
      expect(json.containsKey('chunk_size'), true);
      expect(json.containsKey('total_chunks'), true);
      expect(json.containsKey('original_payload_size'), true);
      expect(json.containsKey('salt'), true);
      expect(json.containsKey('kdf_algorithm'), true);
      expect(json.containsKey('kdf_iterations'), true);
    });

    test('fromJson 应正确解析 snake_case 键名', () {
      final json = {
        'encryption_algorithm': 'AES-256-GCM',
        'chunk_size': 512,
        'total_chunks': 10,
        'original_payload_size': 5000,
        'salt': 'c2FsdA==',
        'kdf_algorithm': 'PBKDF2-HMAC-SHA256',
        'kdf_iterations': 100000,
      };

      final content = StrawContent.fromJson(json);

      expect(content.encryptionAlgorithm, 'AES-256-GCM');
      expect(content.chunkSize, 512);
      expect(content.totalChunks, 10);
      expect(content.originalPayloadSize, 5000);
      expect(content.saltBase64, 'c2FsdA==');
      expect(content.kdfAlgorithm, 'PBKDF2-HMAC-SHA256');
      expect(content.kdfIterations, 100000);
    });

    test('fromJson 中缺少可选字段时应为 null', () {
      final json = {
        'encryption_algorithm': 'AES-256-GCM',
        'chunk_size': 1048576,
        'total_chunks': 1,
        'original_payload_size': 100,
      };

      final content = StrawContent.fromJson(json);

      expect(content.saltBase64, isNull);
      expect(content.kdfAlgorithm, isNull);
      expect(content.kdfIterations, isNull);
    });
  });

  group('StrawContent 相等性', () {
    test('两个字段完全相同的实例应相等', () {
      const content1 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 3,
        originalPayloadSize: 2500000,
        saltBase64: 'c2FsdA==',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );
      const content2 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 3,
        originalPayloadSize: 2500000,
        saltBase64: 'c2FsdA==',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );

      expect(content1, equals(content2));
      expect(content1.hashCode, equals(content2.hashCode));
    });

    test('chunkSize 不同时不应相等', () {
      const content1 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
      );
      const content2 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 512,
        totalChunks: 1,
        originalPayloadSize: 100,
      );

      expect(content1, isNot(equals(content2)));
    });

    test('totalChunks 不同时不应相等', () {
      const content1 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
      );
      const content2 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 2,
        originalPayloadSize: 100,
      );

      expect(content1, isNot(equals(content2)));
    });

    test('originalPayloadSize 不同时不应相等', () {
      const content1 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
      );
      const content2 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 200,
      );

      expect(content1, isNot(equals(content2)));
    });

    test('可选字段不同时不应相等', () {
      const content1 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
        saltBase64: 'c2FsdA==',
      );
      const content2 = StrawContent(
        encryptionAlgorithm: 'AES-256-GCM',
        chunkSize: 1048576,
        totalChunks: 1,
        originalPayloadSize: 100,
      );

      expect(content1, isNot(equals(content2)));
    });
  });
}
