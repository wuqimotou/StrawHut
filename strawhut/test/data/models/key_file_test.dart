import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/integrity_info.dart';

// ========== 辅助函数：创建有效的 KeyFile 测试夹具 ==========
/// 创建一个包含所有必填字段的有效 KeyFile 实例，供多个测试用例复用
KeyFile _createValidKeyFile() => KeyFile(
      formatVersion: const FormatVersion(1, 0, 0),
      keyMetadata: const KeyMetadata(
        keyId: 'k_20260501120000000_a3f7b2c1',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      ),
      keyData: const KeyData(
        keyBase64:
            'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVmZ2g=',
        encoding: 'base64',
      ),
      integrity: const IntegrityInfo(
        hash:
            'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
        hashAlgorithm: 'SHA-256',
      ),
    );

void main() {
  // ========== KeyFile 相等性与 hashCode 测试 ==========
  group('KeyFile 相等性与 hashCode', () {
    test('两个相同的 KeyFile 对象应该相等', () {
      // 验证 KeyFile 的 == 运算符实现正确
      // 当所有字段都相同时，两个实例应被视为相等
      final file1 = _createValidKeyFile();
      final file2 = _createValidKeyFile();

      expect(file1, equals(file2));
    });

    test('两个相同的 KeyFile 对象应该有相同的 hashCode', () {
      // 验证 hashCode 实现与 == 运算符一致
      // 相等的对象必须具有相同的 hashCode，这是 Dart 集合正确工作的前提
      final file1 = _createValidKeyFile();
      final file2 = _createValidKeyFile();

      expect(file1.hashCode, equals(file2.hashCode));
    });

    test('不同 keyId 的 KeyFile 对象不应该相等', () {
      // 验证当 keyMetadata 中的 keyId 不同时，两个 KeyFile 不相等
      final file1 = _createValidKeyFile();
      final file2 = KeyFile(
        formatVersion: const FormatVersion(1, 0, 0),
        keyMetadata: const KeyMetadata(
          keyId: 'k_20260502120000000_deadbeef', // 不同的 keyId
          createdAt: '2026-05-01T12:00:00Z',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: const KeyData(
          keyBase64:
              'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVmZ2g=',
          encoding: 'base64',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      expect(file1, isNot(equals(file2)));
    });

    test('不同 keyBase64 的 KeyFile 对象不应该相等', () {
      // 验证当 keyData 中的 keyBase64 不同时，两个 KeyFile 不相等
      final file1 = _createValidKeyFile();
      final file2 = KeyFile(
        formatVersion: const FormatVersion(1, 0, 0),
        keyMetadata: const KeyMetadata(
          keyId: 'k_20260501120000000_a3f7b2c1',
          createdAt: '2026-05-01T12:00:00Z',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: const KeyData(
          keyBase64: 'ZGlmZmVyZW50S2V5QmFzZTY0VmFsdWUxMjM0NTY3ODkwYWJjZGVmZ2g=', // 不同的密钥
          encoding: 'base64',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      expect(file1, isNot(equals(file2)));
    });

    test('KeyFile 与自身应该相等（同一实例）', () {
      // 验证 identical 场景下相等性成立
      final file = _createValidKeyFile();
      expect(file, equals(file));
    });

    test('KeyFile 与其他类型的对象不应该相等', () {
      // 验证 KeyFile 的 == 运算符正确判断类型
      final file = _createValidKeyFile();
      expect(file == 'not a KeyFile', isFalse);
      expect(file == 42, isFalse);
      expect(file == null, isFalse);
    });
  });

  // ========== KeyMetadata 相等性与 hashCode 测试 ==========
  group('KeyMetadata 相等性与 hashCode', () {
    test('两个相同的 KeyMetadata 对象应该相等', () {
      // 验证 KeyMetadata 的 == 运算符实现正确
      const meta1 = KeyMetadata(
        keyId: 'k_test_001',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        associatedCardTitle: '测试卡片',
      );
      const meta2 = KeyMetadata(
        keyId: 'k_test_001',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        associatedCardTitle: '测试卡片',
      );

      expect(meta1, equals(meta2));
    });

    test('两个相同的 KeyMetadata 对象应该有相同的 hashCode', () {
      // 验证 hashCode 与 == 运算符一致
      const meta1 = KeyMetadata(
        keyId: 'k_test_002',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        notes: '测试备注',
      );
      const meta2 = KeyMetadata(
        keyId: 'k_test_002',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        notes: '测试备注',
      );

      expect(meta1.hashCode, equals(meta2.hashCode));
    });

    test('notes 不同的 KeyMetadata 对象不应该相等', () {
      // 验证可选字段不同也会影响相等性
      const meta1 = KeyMetadata(
        keyId: 'k_test_003',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        notes: '备注1',
      );
      const meta2 = KeyMetadata(
        keyId: 'k_test_003',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        notes: '备注2', // 只有 notes 不同
      );

      expect(meta1, isNot(equals(meta2)));
    });

    test('一个 notes 为 null 另一个不为 null 的 KeyMetadata 不相等', () {
      // 验证 null 与非 null 可选字段的相等性
      const meta1 = KeyMetadata(
        keyId: 'k_test_004',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );
      const meta2 = KeyMetadata(
        keyId: 'k_test_004',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        notes: '有备注',
      );

      expect(meta1, isNot(equals(meta2)));
    });

    test('两个 notes 均为 null 的 KeyMetadata 应该相等', () {
      // 验证可选字段都为 null 时相等
      const meta1 = KeyMetadata(
        keyId: 'k_test_005',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );
      const meta2 = KeyMetadata(
        keyId: 'k_test_005',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );

      expect(meta1, equals(meta2));
      expect(meta1.hashCode, equals(meta2.hashCode));
    });
  });

  // ========== KeyData 相等性与 hashCode 测试 ==========
  group('KeyData 相等性与 hashCode', () {
    test('两个相同的 KeyData 对象应该相等', () {
      // 验证 KeyData 的 == 运算符实现正确
      const data1 = KeyData(
        keyBase64: 'dGVzdGtleUJhc2U2NA==',
        encoding: 'base64',
      );
      const data2 = KeyData(
        keyBase64: 'dGVzdGtleUJhc2U2NA==',
        encoding: 'base64',
      );

      expect(data1, equals(data2));
    });

    test('两个相同的 KeyData 对象应该有相同的 hashCode', () {
      // 验证 KeyData hashCode 与 == 一致
      const data1 = KeyData(
        keyBase64: 'YW5vdGhlcktleQ==',
        encoding: 'base64',
      );
      const data2 = KeyData(
        keyBase64: 'YW5vdGhlcktleQ==',
        encoding: 'base64',
      );

      expect(data1.hashCode, equals(data2.hashCode));
    });

    test('不同 keyBase64 的 KeyData 对象不应该相等', () {
      // 验证 keyBase64 不同导致不相等
      const data1 = KeyData(
        keyBase64: 'a2V5MQ==',
        encoding: 'base64',
      );
      const data2 = KeyData(
        keyBase64: 'a2V5Mg==', // 不同的密钥
        encoding: 'base64',
      );

      expect(data1, isNot(equals(data2)));
    });

    test('不同 encoding 的 KeyData 对象不应该相等', () {
      // 验证 encoding 不同导致不相等
      const data1 = KeyData(
        keyBase64: 'c2FtZUtleQ==',
        encoding: 'base64',
      );
      const data2 = KeyData(
        keyBase64: 'c2FtZUtleQ==',
        encoding: 'hex', // 不同的编码
      );

      expect(data1, isNot(equals(data2)));
    });
  });

  group('KeyFile.toJson/fromJson 序列化循环', () {
    test('完整序列化循环应还原所有字段', () {
      final original = KeyFile(
        formatVersion: const FormatVersion(1, 0, 0),
        keyMetadata: const KeyMetadata(
          keyId: 'k_20260501120000000_a3f7b2c1',
          createdAt: '2026-05-01T12:00:00Z',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
          associatedCardTitle: '测试卡片',
          associatedCardId: 'card_001',
          notes: '这是一把测试密钥',
        ),
        keyData: const KeyData(
          keyBase64:
              'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVmZ2g=',
          encoding: 'base64',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = original.toJson();
      final restored = KeyFile.fromJson(json);

      expect(
        restored.formatVersion.toString(),
        original.formatVersion.toString(),
      );
      expect(restored.keyMetadata.keyId, original.keyMetadata.keyId);
      expect(restored.keyMetadata.createdAt, original.keyMetadata.createdAt);
      expect(
        restored.keyMetadata.associatedCardTitle,
        original.keyMetadata.associatedCardTitle,
      );
      expect(
        restored.keyMetadata.associatedCardId,
        original.keyMetadata.associatedCardId,
      );
      expect(
        restored.keyMetadata.keyAlgorithm,
        original.keyMetadata.keyAlgorithm,
      );
      expect(
        restored.keyMetadata.keyLengthBits,
        original.keyMetadata.keyLengthBits,
      );
      expect(restored.keyMetadata.notes, original.keyMetadata.notes);
      expect(restored.keyData.keyBase64, original.keyData.keyBase64);
      expect(restored.keyData.encoding, original.keyData.encoding);
      expect(restored.integrity.hash, original.integrity.hash);
      expect(restored.integrity.hashAlgorithm, original.integrity.hashAlgorithm);
    });

    test('assembleToJson 类似流程应还原所有字段', () {
      final original = KeyFile(
        formatVersion: const FormatVersion(1, 0, 0),
        keyMetadata: const KeyMetadata(
          keyId: 'k_20260502083000000_b2c3d4e5',
          createdAt: '2026-05-02T08:30:00Z',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: const KeyData(
          keyBase64: 'c2VjcmV0a2V5MTIzNDU2Nzg5MGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHk=',
          encoding: 'base64',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:0000000000000000000000000000000000000000000000000000000000000001',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final jsonString = jsonEncode(original.toJson());
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = KeyFile.fromJson(jsonMap);

      expect(restored.keyMetadata.keyId, original.keyMetadata.keyId);
      expect(restored.keyData.keyBase64, original.keyData.keyBase64);
      expect(restored.integrity.hash, original.integrity.hash);
    });

    test('toJson 应输出正确的顶层键名', () {
      final keyFile = KeyFile(
        formatVersion: const FormatVersion(1, 0, 0),
        keyMetadata: const KeyMetadata(
          keyId: 'k_20260501120000000_test',
          createdAt: '2026-05-01T12:00:00Z',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: const KeyData(
          keyBase64: 'dGVzdGtleQ==',
          encoding: 'base64',
        ),
        integrity: const IntegrityInfo(
          hash: 'sha256:abc',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = keyFile.toJson();

      expect(json.containsKey('format_version'), true);
      expect(json.containsKey('key_metadata'), true);
      expect(json.containsKey('key_data'), true);
      expect(json.containsKey('integrity'), true);
    });
  });

  group('KeyMetadata.toJson/fromJson 序列化循环', () {
    test('含所有可选字段的序列化循环应还原所有字段', () {
      const original = KeyMetadata(
        keyId: 'k_20260501120000000_a3f7b2c1',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        associatedCardTitle: '网络安全入门',
        associatedCardId: 'card_abc123',
        notes: '这是第一把密钥',
      );

      final json = original.toJson();
      final restored = KeyMetadata.fromJson(json);

      expect(restored.keyId, original.keyId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.associatedCardTitle, original.associatedCardTitle);
      expect(restored.associatedCardId, original.associatedCardId);
      expect(restored.keyAlgorithm, original.keyAlgorithm);
      expect(restored.keyLengthBits, original.keyLengthBits);
      expect(restored.notes, original.notes);
    });

    test('可选字段为 null 时 toJson 不应输出', () {
      const metadata = KeyMetadata(
        keyId: 'k_20260501120000000_test',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        // associatedCardTitle, associatedCardId, notes 均为 null
      );

      final json = metadata.toJson();

      expect(json.containsKey('associated_card_title'), false);
      expect(json.containsKey('associated_card_id'), false);
      expect(json.containsKey('notes'), false);
    });

    test('可选字段有值时 toJson 应正确输出', () {
      const metadata = KeyMetadata(
        keyId: 'k_20260501120000000_test',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        associatedCardTitle: '测试卡片',
        associatedCardId: 'card_001',
        notes: '测试备注',
      );

      final json = metadata.toJson();

      expect(json['associated_card_title'], '测试卡片');
      expect(json['associated_card_id'], 'card_001');
      expect(json['notes'], '测试备注');
    });

    test('部分可选字段有值时应只输出有值的字段', () {
      const metadata = KeyMetadata(
        keyId: 'k_20260501120000000_test',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
        associatedCardTitle: '测试卡片',
        // associatedCardId 和 notes 为 null
      );

      final json = metadata.toJson();

      expect(json['associated_card_title'], '测试卡片');
      expect(json.containsKey('associated_card_id'), false);
      expect(json.containsKey('notes'), false);
    });

    test('toJson 应使用 snake_case 键名', () {
      const metadata = KeyMetadata(
        keyId: 'k_20260501120000000_test',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );

      final json = metadata.toJson();

      expect(json.containsKey('key_id'), true);
      expect(json.containsKey('created_at'), true);
      expect(json.containsKey('key_algorithm'), true);
      expect(json.containsKey('key_length_bits'), true);
    });

    test('fromJson 应正确解析必填字段', () {
      final json = {
        'key_id': 'k_20260501120000000_parse_test',
        'created_at': '2026-05-01T12:00:00Z',
        'key_algorithm': 'AES-256-GCM',
        'key_length_bits': 256,
      };

      final metadata = KeyMetadata.fromJson(json);

      expect(metadata.keyId, 'k_20260501120000000_parse_test');
      expect(metadata.createdAt, '2026-05-01T12:00:00Z');
      expect(metadata.keyAlgorithm, 'AES-256-GCM');
      expect(metadata.keyLengthBits, 256);
    });

    test('fromJson 应正确解析可选字段', () {
      final json = {
        'key_id': 'k_20260501120000000_full_test',
        'created_at': '2026-05-01T12:00:00Z',
        'key_algorithm': 'AES-256-GCM',
        'key_length_bits': 256,
        'associated_card_title': '完整测试卡片',
        'associated_card_id': 'card_full',
        'notes': '完整测试备注',
      };

      final metadata = KeyMetadata.fromJson(json);

      expect(metadata.associatedCardTitle, '完整测试卡片');
      expect(metadata.associatedCardId, 'card_full');
      expect(metadata.notes, '完整测试备注');
    });

    test('fromJson 中可选字段缺失时应为 null', () {
      final json = {
        'key_id': 'k_20260501120000000_minimal',
        'created_at': '2026-05-01T12:00:00Z',
        'key_algorithm': 'AES-256-GCM',
        'key_length_bits': 256,
      };

      final metadata = KeyMetadata.fromJson(json);

      expect(metadata.associatedCardTitle, null);
      expect(metadata.associatedCardId, null);
      expect(metadata.notes, null);
    });
  });

  group('KeyData.toJson/fromJson 序列化循环', () {
    test('序列化循环应还原所有字段', () {
      const original = KeyData(
        keyBase64:
            'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVmZ2g=',
        encoding: 'base64',
      );

      final json = original.toJson();
      final restored = KeyData.fromJson(json);

      expect(restored.keyBase64, original.keyBase64);
      expect(restored.encoding, original.encoding);
    });

    test('toJson 应使用正确的键名', () {
      const keyData = KeyData(
        keyBase64: 'c2VjcmV0a2V5',
        encoding: 'base64',
      );

      final json = keyData.toJson();

      expect(json['key_base64'], 'c2VjcmV0a2V5');
      expect(json['encoding'], 'base64');
    });

    test('应从 JSON 正确解析密钥数据', () {
      final json = {
        'key_base64':
            'd3h5ejEyMzQ1Njc4OTBhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejEyMzQ1Ng==',
        'encoding': 'base64',
      };

      final keyData = KeyData.fromJson(json);

      expect(
        keyData.keyBase64,
        'd3h5ejEyMzQ1Njc4OTBhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejEyMzQ1Ng==',
      );
      expect(keyData.encoding, 'base64');
    });
  });

  group('IntegrityInfo.toJson/fromJson', () {
    test('序列化循环应还原所有字段', () {
      const original = IntegrityInfo(
        hash:
            'sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        hashAlgorithm: 'SHA-256',
      );

      final json = original.toJson();
      final restored = IntegrityInfo.fromJson(json);

      expect(restored.hash, original.hash);
      expect(restored.hashAlgorithm, original.hashAlgorithm);
    });

    test('toJson 应使用 snake_case 键名', () {
      const integrity = IntegrityInfo(
        hash: 'sha256:test',
        hashAlgorithm: 'SHA-256',
      );

      final json = integrity.toJson();

      expect(json['hash'], 'sha256:test');
      expect(json['hash_algorithm'], 'SHA-256');
    });
  });

  group('密钥 ID 生成规则验证', () {
    test('密钥 ID 格式应为 k_{时间戳}_{8位随机十六进制}', () {
      const keyId = 'k_20260501120000000_a3f7b2c1';
      final parts = keyId.split('_');

      // 第一个部分应为 "k"
      expect(parts[0], 'k');
      // 第二部分为时间戳（至少包含数字）
      expect(RegExp(r'^\d+$').hasMatch(parts[1]), true);
      // 第三部分为 8 位随机十六进制
      expect(parts[2].length, 8);
      expect(RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(parts[2]), true);
    });

    test('不同时间戳应产生不同的密钥 ID', () {
      const keyId1 = 'k_20260501120000000_a3f7b2c1';
      const keyId2 = 'k_20260502120000000_a3f7b2c1';

      expect(keyId1, isNot(equals(keyId2)));
    });

    test('相同时间戳不同随机后缀应产生不同的密钥 ID', () {
      const keyId1 = 'k_20260501120000000_a3f7b2c1';
      const keyId2 = 'k_20260501120000000_b3f7b2c1';

      expect(keyId1, isNot(equals(keyId2)));
    });

    test('8 位随机十六进制应仅包含有效十六进制字符', () {
      const suffix1 = 'a3f7b2c1';
      const suffix2 = '00ff00ff';
      const suffix3 = 'ABCDEF01';

      expect(RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(suffix1), true);
      expect(RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(suffix2), true);
      expect(RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(suffix3), true);
    });

    test('密钥 ID 前缀应为 k_', () {
      const keyId = 'k_20260501120000000_a3f7b2c1';

      expect(keyId.startsWith('k_'), true);
    });

    test('有效密钥 ID 应能正确设置到 KeyMetadata', () {
      const keyId = 'k_20260501120000000_deadbeef';

      const metadata = KeyMetadata(
        keyId: keyId,
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );

      expect(metadata.keyId, keyId);
      expect(metadata.toJson()['key_id'], keyId);
    });
  });

  group('FormatVersion 序列化', () {
    test('toString 应返回 "major.minor.patch" 格式', () {
      const version = FormatVersion(1, 0, 0);
      expect(version.toString(), '1.0.0');
    });

    test('fromString 应正确解析版本号', () {
      final version = FormatVersion.fromString('1.0.0');
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.patch, 0);
    });
  });

  group('边界条件测试', () {
    test('KeyMetadata 所有可选字段均为 null 时的序列化循环', () {
      const original = KeyMetadata(
        keyId: 'k_20260501120000000_minimal',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );

      final json = original.toJson();
      final restored = KeyMetadata.fromJson(json);

      expect(restored.keyId, original.keyId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.keyAlgorithm, original.keyAlgorithm);
      expect(restored.keyLengthBits, original.keyLengthBits);
      expect(restored.associatedCardTitle, null);
      expect(restored.associatedCardId, null);
      expect(restored.notes, null);
    });

    test('KeyMetadata 可选字段均为 null 时 toJson 应仅包含必填字段', () {
      const metadata = KeyMetadata(
        keyId: 'k_20260501120000000_test',
        createdAt: '2026-05-01T12:00:00Z',
        keyAlgorithm: 'AES-256-GCM',
        keyLengthBits: 256,
      );

      final json = metadata.toJson();

      expect(json.length, 4);
      expect(json.containsKey('key_id'), true);
      expect(json.containsKey('created_at'), true);
      expect(json.containsKey('key_algorithm'), true);
      expect(json.containsKey('key_length_bits'), true);
    });

    test('空列表 tags 的 CardMeta 序列化', () {
      const meta = CardMeta(
        publisherAlias: 'TestUser',
        publishDate: '2026-05-01T12:00:00Z',
        title: '测试',
        isAnonymous: false,
        tags: [],
      );

      final json = meta.toJson();

      expect(json['tags'], isEmpty);
    });
  });
}
