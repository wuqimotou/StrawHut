import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/encrypted_content.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/data/models/integrity_info.dart';

void main() {
  // ========== 辅助函数：创建有效的 StrawFile 测试夹具 ==========
  /// 创建一个包含所有必填字段的有效 StrawFile 实例，供多个测试用例复用
  StrawFile _createValidStrawFile() => StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

  // ========== 辅助函数：创建有效的 JSON 测试夹具 ==========
  /// 创建一个有效的 .straw 文件 JSON 映射，用于 fromJson 测试
  Map<String, dynamic> _createValidStrawJson() => {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'TestUser',
          'publish_date': '2026-05-01T12:00:00Z',
          'title': '测试卡片',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'dGVzdGVuY3J5cHRlZGRhdGE=',
          'iv': 'dGVzdGl2MTIzNDU2',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash':
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          'hash_algorithm': 'SHA-256',
        },
      };

  group('StrawFile 相等性与 hashCode', () {
    test('两个相同的 StrawFile 对象应该相等', () {
      // 验证 StrawFile 的 == 运算符实现正确
      // 当所有字段都相同时，两个实例应被视为相等
      final file1 = _createValidStrawFile();
      final file2 = _createValidStrawFile();

      expect(file1, equals(file2));
    });

    test('两个相同的 StrawFile 对象应该有相同的 hashCode', () {
      // 验证 hashCode 实现与 == 运算符一致
      // 相等的对象必须具有相同的 hashCode，这是 Dart 集合（如 HashSet、HashMap）正确工作的前提
      final file1 = _createValidStrawFile();
      final file2 = _createValidStrawFile();

      expect(file1.hashCode, equals(file2.hashCode));
    });

    test('不同内容的 StrawFile 对象不应该相等', () {
      // 验证当某个字段不同时，两个 StrawFile 不相等
      // 测试 title 字段不同
      final file1 = _createValidStrawFile();
      final file2 = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '不同的标题', // 唯一不同的字段
          isAnonymous: false,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      expect(file1, isNot(equals(file2)));
    });

    test('StrawFile 与自身应该相等（同一实例）', () {
      // 验证 identical 场景下相等性成立
      final file = _createValidStrawFile();
      expect(file, equals(file));
    });

    test('StrawFile 与其他类型的对象不应该相等', () {
      // 验证 StrawFile 的 == 运算符正确判断类型
      final file = _createValidStrawFile();
      expect(file == 'not a StrawFile', isFalse);
      expect(file == 42, isFalse);
      expect(file == null, isFalse);
    });
  });

  group('StrawFile.fromJson 异常处理', () {
    test('缺少 format_version 字段时应抛出异常', () {
      // 验证 fromJson 在缺少必填字段时的容错行为
      // format_version 是 StrawFile 的必填字段，缺失时应抛出异常
      final json = _createValidStrawJson();
      json.remove('format_version');

      expect(() => StrawFile.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('缺少 meta 字段时应抛出异常', () {
      // meta 是必填字段，CardMeta.fromJson 会因为 null 转换失败而抛出异常
      final json = _createValidStrawJson();
      json.remove('meta');

      expect(() => StrawFile.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('缺少 content 字段时应抛出异常', () {
      // content 是必填字段，缺失时应抛出异常
      final json = _createValidStrawJson();
      json.remove('content');

      expect(() => StrawFile.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('缺少 integrity 字段时应抛出异常', () {
      // integrity 是必填字段，缺失时应抛出异常
      final json = _createValidStrawJson();
      json.remove('integrity');

      expect(() => StrawFile.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('content 缺少 encrypted_data 时应抛出异常', () {
      // EncryptedContent 的 encryptedDataBase64 是必填字段
      final json = _createValidStrawJson();
      (json['content'] as Map<String, dynamic>).remove('encrypted_data');

      expect(() => StrawFile.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('StrawFile.toJson', () {
    test('应输出包含所有必填字段的 JSON 映射', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = strawFile.toJson();

      expect(json.containsKey('format_version'), true);
      expect(json.containsKey('meta'), true);
      expect(json.containsKey('content'), true);
      expect(json.containsKey('integrity'), true);
    });

    test('JSON 键名应使用 snake_case 格式', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = strawFile.toJson();
      final contentJson = json['content'] as Map<String, dynamic>;
      final integrityJson = json['integrity'] as Map<String, dynamic>;

      // 验证顶层键名
      expect(json.containsKey('format_version'), true);
      // 验证 content 内部键名
      expect(contentJson.containsKey('encrypted_data'), true);
      expect(contentJson.containsKey('encryption_algorithm'), true);
      expect(contentJson.containsKey('iv'), true);
      // 验证 integrity 内部键名
      expect(integrityJson.containsKey('hash'), true);
      expect(integrityJson.containsKey('hash_algorithm'), true);
    });

    test('CardMeta 可选字段为 null 时不应输出', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
          // description 和 customAnnotations 为 null（默认）
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = strawFile.toJson();
      final metaJson = json['meta'] as Map<String, dynamic>;

      expect(metaJson.containsKey('description'), false);
      expect(metaJson.containsKey('custom_annotations'), false);
    });

    test('CardMeta 可选字段有值时应正确输出', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
          tags: ['测试', '笔记'],
          description: '这是一张测试卡片',
          customAnnotations: {'key': 'value'},
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = strawFile.toJson();
      final metaJson = json['meta'] as Map<String, dynamic>;

      expect(metaJson['description'], '这是一张测试卡片');
      expect(metaJson['tags'], ['测试', '笔记']);
      expect(metaJson['custom_annotations'], {'key': 'value'});
    });
  });

  group('StrawFile.fromJson', () {
    test('应从完整 JSON 正确解析所有字段', () {
      final json = {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'TestUser',
          'publish_date': '2026-05-01T12:00:00Z',
          'title': '测试卡片',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'dGVzdGVuY3J5cHRlZGRhdGE=',
          'iv': 'dGVzdGl2MTIzNDU2',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash':
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          'hash_algorithm': 'SHA-256',
        },
      };

      final strawFile = StrawFile.fromJson(json);

      expect(strawFile.formatVersion.toString(), '1.0.0');
      expect(strawFile.meta.publisherAlias, 'TestUser');
      expect(strawFile.meta.title, '测试卡片');
      expect(strawFile.content.encryptedDataBase64, 'dGVzdGVuY3J5cHRlZGRhdGE=');
      expect(strawFile.content.ivBase64, 'dGVzdGl2MTIzNDU2');
      expect(strawFile.content.algorithm, 'AES-256-GCM');
      expect(
        strawFile.integrity.hash,
        'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      );
      expect(strawFile.integrity.hashAlgorithm, 'SHA-256');
    });

    test('嵌套对象 meta 应正确解析', () {
      final json = {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'Anonymous_a3f7b2c1',
          'publish_date': '2026-05-02T08:30:00Z',
          'title': '网络安全入门',
          'tags': ['安全', '入门'],
          'description': '一份入门指南',
          'is_anonymous': true,
        },
        'content': {
          'encrypted_data': 'dGVzdA==',
          'iv': 'dGVzdA==',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash': 'sha256:abc123',
          'hash_algorithm': 'SHA-256',
        },
      };

      final strawFile = StrawFile.fromJson(json);

      expect(strawFile.meta.publisherAlias, 'Anonymous_a3f7b2c1');
      expect(strawFile.meta.publishDate, '2026-05-02T08:30:00Z');
      expect(strawFile.meta.title, '网络安全入门');
      expect(strawFile.meta.tags, ['安全', '入门']);
      expect(strawFile.meta.description, '一份入门指南');
      expect(strawFile.meta.isAnonymous, true);
    });

    test('嵌套对象 content 应正确解析', () {
      final json = {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'TestUser',
          'publish_date': '2026-05-01T12:00:00Z',
          'title': '测试',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'ZW5jcnlwdGVk',
          'iv': 'aXZkYXRh',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash': 'sha256:def456',
          'hash_algorithm': 'SHA-256',
        },
      };

      final strawFile = StrawFile.fromJson(json);

      expect(strawFile.content.encryptedDataBase64, 'ZW5jcnlwdGVk');
      expect(strawFile.content.ivBase64, 'aXZkYXRh');
      expect(strawFile.content.algorithm, 'AES-256-GCM');
    });

    test('嵌套对象 integrity 应正确解析', () {
      final json = {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'TestUser',
          'publish_date': '2026-05-01T12:00:00Z',
          'title': '测试',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'dGVzdA==',
          'iv': 'dGVzdA==',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash':
              'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          'hash_algorithm': 'SHA-256',
        },
      };

      final strawFile = StrawFile.fromJson(json);

      expect(
        strawFile.integrity.hash,
        'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      expect(strawFile.integrity.hashAlgorithm, 'SHA-256');
    });

    test('meta 中 tags 字段不存在时应默认为空列表', () {
      final json = {
        'format_version': '1.0.0',
        'meta': {
          'publisher_alias': 'TestUser',
          'publish_date': '2026-05-01T12:00:00Z',
          'title': '测试',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'dGVzdA==',
          'iv': 'dGVzdA==',
          'encryption_algorithm': 'AES-256-GCM',
        },
        'integrity': {
          'hash': 'sha256:abc',
          'hash_algorithm': 'SHA-256',
        },
      };

      final strawFile = StrawFile.fromJson(json);

      expect(strawFile.meta.tags, isEmpty);
    });
  });

  group('StrawFile.assembleToJson', () {
    test('应输出有效的 JSON 字符串', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final jsonString = strawFile.assembleToJson();

      // 验证是有效的 JSON 字符串
      final decoded = jsonDecode(jsonString);
      expect(decoded, isA<Map<String, dynamic>>());
    });

    test('assembleToJson 应与 toJson 结果一致', () {
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
          tags: ['测试'],
          description: '描述',
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final toJsonResult = strawFile.toJson();
      final assembleResult =
          jsonDecode(strawFile.assembleToJson()) as Map<String, dynamic>;

      expect(assembleResult['format_version'], toJsonResult['format_version']);
      expect(assembleResult['meta'], toJsonResult['meta']);
      expect(assembleResult['content'], toJsonResult['content']);
      expect(assembleResult['integrity'], toJsonResult['integrity']);
    });
  });

  group('StrawFile toJson/fromJson 序列化循环', () {
    test('完整序列化循环应还原所有字段', () {
      final original = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'TestUser',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          isAnonymous: false,
          tags: ['测试', '笔记'],
          description: '这是一张测试卡片',
          customAnnotations: {'version': '1'},
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
          ivBase64: 'dGVzdGl2MTIzNDU2',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final json = original.toJson();
      final restored = StrawFile.fromJson(json);

      expect(
        restored.formatVersion.toString(),
        original.formatVersion.toString(),
      );
      expect(restored.meta.publisherAlias, original.meta.publisherAlias);
      expect(restored.meta.publishDate, original.meta.publishDate);
      expect(restored.meta.title, original.meta.title);
      expect(restored.meta.tags, original.meta.tags);
      expect(restored.meta.description, original.meta.description);
      expect(restored.meta.isAnonymous, original.meta.isAnonymous);
      expect(
        restored.meta.customAnnotations,
        original.meta.customAnnotations,
      );
      expect(
        restored.content.encryptedDataBase64,
        original.content.encryptedDataBase64,
      );
      expect(restored.content.ivBase64, original.content.ivBase64);
      expect(restored.content.algorithm, original.content.algorithm);
      expect(restored.integrity.hash, original.integrity.hash);
      expect(
          restored.integrity.hashAlgorithm, original.integrity.hashAlgorithm);
    });

    test('assembleToJson 后再解析应还原所有字段', () {
      final original = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'Anonymous_a3f7b2c1',
          publishDate: '2026-05-02T08:30:00Z',
          title: '匿名卡片',
          isAnonymous: true,
        ),
        content: const EncryptedContent(
          encryptedDataBase64: 'c2VjcmV0ZGF0YQ==',
          ivBase64: 'cmFuZG9taXYxNg==',
          algorithm: 'AES-256-GCM',
        ),
        integrity: const IntegrityInfo(
          hash:
              'sha256:0000000000000000000000000000000000000000000000000000000000000000',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final jsonString = original.assembleToJson();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = StrawFile.fromJson(jsonMap);

      expect(
        restored.formatVersion.toString(),
        original.formatVersion.toString(),
      );
      expect(restored.meta.isAnonymous, true);
      expect(restored.meta.publisherAlias, 'Anonymous_a3f7b2c1');
    });
  });

  group('IntegrityInfo.toJson/fromJson', () {
    test('序列化循环应还原所有字段', () {
      const original = IntegrityInfo(
        hash:
            'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
        hashAlgorithm: 'SHA-256',
      );

      final json = original.toJson();
      final restored = IntegrityInfo.fromJson(json);

      expect(restored.hash, original.hash);
      expect(restored.hashAlgorithm, original.hashAlgorithm);
    });

    test('toJson 应使用正确的键名', () {
      const integrity = IntegrityInfo(
        hash: 'sha256:abc123',
        hashAlgorithm: 'SHA-256',
      );

      final json = integrity.toJson();

      expect(json['hash'], 'sha256:abc123');
      expect(json['hash_algorithm'], 'SHA-256');
    });

    test('应从 JSON 正确解析哈希值', () {
      final json = {
        'hash':
            'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        'hash_algorithm': 'SHA-256',
      };

      final integrity = IntegrityInfo.fromJson(json);

      expect(
        integrity.hash,
        'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      expect(integrity.hashAlgorithm, 'SHA-256');
    });
  });

  group('FormatVersion 序列化', () {
    test('toString 应返回 "major.minor.patch" 格式', () {
      const version = FormatVersion(1, 2, 3);
      expect(version.toString(), '1.2.3');
    });

    test('fromString 应正确解析版本号', () {
      final version = FormatVersion.fromString('2.0.1');
      expect(version.major, 2);
      expect(version.minor, 0);
      expect(version.patch, 1);
    });

    test('序列化循环应还原版本号', () {
      const original = FormatVersion(1, 0, 0);
      final restored = FormatVersion.fromString(original.toString());

      expect(restored.major, original.major);
      expect(restored.minor, original.minor);
      expect(restored.patch, original.patch);
    });
  });

  group('EncryptedContent toJson/fromJson', () {
    test('序列化循环应还原所有字段', () {
      const original = EncryptedContent(
        encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
        ivBase64: 'dGVzdGl2MTIzNDU2',
        algorithm: 'AES-256-GCM',
      );

      final json = original.toJson();
      final restored = EncryptedContent.fromJson(json);

      expect(restored.encryptedDataBase64, original.encryptedDataBase64);
      expect(restored.ivBase64, original.ivBase64);
      expect(restored.algorithm, original.algorithm);
    });

    test('toJson 应使用正确的键名', () {
      const content = EncryptedContent(
        encryptedDataBase64: 'c2VjcmV0',
        ivBase64: 'aXYxNg==',
        algorithm: 'AES-256-GCM',
      );

      final json = content.toJson();

      expect(json['encrypted_data'], 'c2VjcmV0');
      expect(json['encryption_algorithm'], 'AES-256-GCM');
      expect(json['iv'], 'aXYxNg==');
    });
  });

  group('CardMeta toJson/fromJson', () {
    test('序列化循环应还原所有字段', () {
      const original = CardMeta(
        publisherAlias: 'TestUser',
        publishDate: '2026-05-01T12:00:00Z',
        title: '测试卡片',
        isAnonymous: false,
        tags: ['测试'],
        description: '描述',
        customAnnotations: {'key': 'value'},
      );

      final json = original.toJson();
      final restored = CardMeta.fromJson(json);

      expect(restored.publisherAlias, original.publisherAlias);
      expect(restored.publishDate, original.publishDate);
      expect(restored.title, original.title);
      expect(restored.tags, original.tags);
      expect(restored.description, original.description);
      expect(restored.isAnonymous, original.isAnonymous);
      expect(
        restored.customAnnotations,
        original.customAnnotations,
      );
    });

    test('可选字段为 null 时 toJson 不应输出', () {
      const meta = CardMeta(
        publisherAlias: 'TestUser',
        publishDate: '2026-05-01T12:00:00Z',
        title: '测试卡片',
        isAnonymous: false,
      );

      final json = meta.toJson();

      expect(json.containsKey('description'), false);
      expect(json.containsKey('custom_annotations'), false);
    });

    test('可选字段有值时 toJson 应正确输出', () {
      const meta = CardMeta(
        publisherAlias: 'Anonymous_a3f7',
        publishDate: '2026-05-01T12:00:00Z',
        title: '匿名卡片',
        isAnonymous: true,
        tags: ['匿名'],
        description: '匿名描述',
        customAnnotations: {'anon': 'true'},
      );

      final json = meta.toJson();

      expect(json['description'], '匿名描述');
      expect(json['custom_annotations'], {'anon': 'true'});
      expect(json['tags'], ['匿名']);
    });

    test('fromJson 中 tags 缺失时应默认为空列表', () {
      final json = {
        'publisher_alias': 'TestUser',
        'publish_date': '2026-05-01T12:00:00Z',
        'title': '测试',
        'is_anonymous': false,
      };

      final meta = CardMeta.fromJson(json);

      expect(meta.tags, isEmpty);
    });
  });

  group('StrawFile v1.1.0 negotiated key mode', () {
    test('EncryptedContent with salt/kdf fields', () {
      const content = EncryptedContent(
        encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
        ivBase64: 'dGVzdGl2MTIzNDU2',
        algorithm: 'AES-256-GCM',
        saltBase64: 'c2FsdDE2Ynl0ZXM=',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );
      expect(content.saltBase64, 'c2FsdDE2Ynl0ZXM=');
      expect(content.kdfAlgorithm, 'PBKDF2-HMAC-SHA256');
      expect(content.kdfIterations, 100000);
    });

    test('EncryptedContent random key mode new fields should be null', () {
      const content = EncryptedContent(
        encryptedDataBase64: 'dGVzdGVuY3J5cHRlZGRhdGE=',
        ivBase64: 'dGVzdGl2MTIzNDU2',
        algorithm: 'AES-256-GCM',
        saltBase64: 'c2FsdDE2Ynl0ZXM=',
      );
      expect(content.saltBase64, 'c2FsdDE2Ynl0ZXM=');
      expect(content.kdfAlgorithm, isNull);
      expect(content.kdfIterations, isNull);
    });

    test('v1.1.0 toJson should include new fields', () {
      const content = EncryptedContent(
        encryptedDataBase64: 'dGVzdA==',
        ivBase64: 'aXY=',
        algorithm: 'AES-256-GCM',
        saltBase64: 'c2FsdA==',
        kdfAlgorithm: 'PBKDF2-HMAC-SHA256',
        kdfIterations: 100000,
      );
      final json = content.toJson();
      expect(json['salt'], 'c2FsdA==');
      expect(json['kdf_algorithm'], 'PBKDF2-HMAC-SHA256');
      expect(json['kdf_iterations'], 100000);
    });

    test('v1.1.0 fromJson should parse new fields', () {
      final json = {
        'encrypted_data': 'dGVzdA==',
        'iv': 'aXY=',
        'encryption_algorithm': 'AES-256-GCM',
        'salt': 'c2FsdA==',
        'kdf_algorithm': 'PBKDF2-HMAC-SHA256',
        'kdf_iterations': 100000,
      };
      final content = EncryptedContent.fromJson(json);
      expect(content.saltBase64, 'c2FsdA==');
      expect(content.kdfAlgorithm, 'PBKDF2-HMAC-SHA256');
      expect(content.kdfIterations, 100000);
    });

    test('v1.0.0 format fromJson new fields should be null', () {
      final json = {
        'encrypted_data': 'dGVzdA==',
        'iv': 'aXY=',
        'encryption_algorithm': 'AES-256-GCM',
      };
      final content = EncryptedContent.fromJson(json);
      expect(content.saltBase64, isNull);
      expect(content.kdfAlgorithm, isNull);
      expect(content.kdfIterations, isNull);
    });
  });
}
