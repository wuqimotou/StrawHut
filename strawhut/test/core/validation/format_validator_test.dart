import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/validation/format_validator.dart';
import 'package:strawhut/core/validation/validation_result.dart';

void main() {
  late FormatValidator formatValidator;

  setUp(() {
    formatValidator = FormatValidator();
  });

  group('ValidationResult', () {
    test('success() 应返回 isValid 为 true 且 errors 为空的结果', () {
      final result = ValidationResult.success();

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('failure() 应返回 isValid 为 false 且包含错误的结果', () {
      final result = ValidationResult.failure([
        '错误 1',
        '错误 2',
      ]);

      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.errors.contains('错误 1'), true);
      expect(result.errors.contains('错误 2'), true);
    });

    test('failure() 应支持空错误列表', () {
      final result = ValidationResult.failure([]);

      expect(result.isValid, false);
      expect(result.errors, isEmpty);
    });
  });

  group('FormatValidator.validateStrawFormat', () {
    // ========== 有效格式测试用例 ==========

    test('应验证有效的 .straw 文件格式成功', () {
      final validStrawJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'test_user',
          'publish_date': '2025-01-01T00:00:00Z',
          'title': '测试知识卡片',
          'is_anonymous': false,
          'tags': ['Flutter', '测试'],
          'description': '这是一个测试描述',
        },
        'content': {
          'encrypted_data': 'ZW5jcnlwdGVkX2RhdGFfZXhhbXBsZQ==',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'aW5pdGlhbGl6YXRpb25fdmVjdG9y',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应验证匿名模式的 .straw 文件格式成功', () {
      final validStrawJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': '${ANONYMOUS_PREFIX}a3f7b2c1',
          'publish_date': '2025-06-15T10:30:00Z',
          'title': '匿名卡片',
          'is_anonymous': true,
        },
        'content': {
          'encrypted_data': 'c29tZV9lbmNyeXB0ZWRfZGF0YQ==',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'c29tZV9pdl92YWx1ZQ==',
        },
        'integrity': {
          'hash':
              'sha256:00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
    });

    test('应验证包含最大数量标签的格式成功', () {
      final validStrawJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'power_user',
          'publish_date': '2025-03-20T12:00:00Z',
          'title': '标签测试卡片',
          'is_anonymous': false,
          'tags': List.generate(MAX_TAGS_COUNT, (index) => 'tag$index'),
        },
        'content': {
          'encrypted_data': 'dGVzdF9lbmNyeXB0ZWRfZGF0YQ==',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'dGVzdF9pdl92YWx1ZQ==',
        },
        'integrity': {
          'hash':
              'sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
    });

    // ========== 必填字段缺失测试用例 ==========

    test('缺少 format_version 时应验证失败', () {
      final invalidJson = {
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors
            .any((e) => e.contains('format_version')),
        true,
      );
    });

    test('缺少 meta 对象时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('meta')), true);
    });

    test('缺少 meta.publisher_alias 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('publisher_alias')),
        true,
      );
    });

    test('缺少 meta.publish_date 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('publish_date')),
        true,
      );
    });

    test('缺少 meta.title 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('title')), true);
    });

    test('meta.title 为空字符串时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('不能为空')), true);
    });

    test('缺少 meta.is_anonymous 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('is_anonymous')),
        true,
      );
    });

    test('缺少 content 对象时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('content')), true);
    });

    test('缺少 content.encrypted_data 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('encrypted_data')),
        true,
      );
    });

    test('缺少 content.encryption_algorithm 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('encryption_algorithm')),
        true,
      );
    });

    test('加密算法不支持时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': 'AES-128-CBC',
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的加密算法')),
        true,
      );
    });

    test('缺少 content.iv 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('.iv')), true);
    });

    test('缺少 integrity 对象时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity')), true);
    });

    test('缺少 integrity.hash 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity.hash')), true);
    });

    test('integrity.hash 格式无效（哈希值过短）时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash': 'sha256:abc123',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 使用 md5 前缀时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash': 'md5:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 包含大写十六进制字符时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 包含非十六进制字符时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:ghijklmnopqrstuvwxyz1234567890ghijklmnopqrstuvwxyz123456',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('缺少 integrity.hash_algorithm 时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('hash_algorithm')),
        true,
      );
    });

    test('哈希算法不支持时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': 'MD5',
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的哈希算法')),
        true,
      );
    });

    // ========== 标签和描述限制测试用例 ==========

    test('标签数量超过限制时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
          'tags': List.generate(MAX_TAGS_COUNT + 1, (index) => 'tag$index'),
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('标签数量超出限制')),
        true,
      );
    });

    test('标签长度超过限制时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
          'tags': ['a' * (MAX_TAG_LENGTH + 1)],
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('长度超出限制')),
        true,
      );
    });

    test('描述长度超过限制时应验证失败', () {
      final invalidJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
          'description': 'a' * (MAX_DESCRIPTION_LENGTH + 1),
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('描述长度超出限制')),
        true,
      );
    });

    // ========== 版本号兼容性测试用例 ==========

    test('主版本号为 2 的 format_version 应验证失败', () {
      final invalidJson = {
        'format_version': '2.0.0',
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不兼容的格式版本号')),
        true,
      );
    });

    test('次版本号不同但主版本为 1 应验证成功', () {
      final validJson = {
        'format_version': '1.5.0',
        'meta': {
          'publisher_alias': 'user',
          'publish_date': '2025-01-01',
          'title': '标题',
          'is_anonymous': false,
        },
        'content': {
          'encrypted_data': 'data',
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'iv': 'iv',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateStrawFormat(validJson);

      expect(result.isValid, true);
    });

    // ========== 收集多个错误测试用例 ==========

    test('应收集所有验证错误而非在第一个错误处停止', () {
      final invalidJson = {
        'meta': {
          'title': '',
        },
        'content': {},
        'integrity': {},
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.length, greaterThan(1));
    });
  });

  group('FormatValidator.validateKeyFormat', () {
    // ========== 有效格式测试用例 ==========

    test('应验证有效的 .key 文件格式成功', () {
      final validKeyJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(validKeyJson);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应验证包含标准 32 字节 Base64 密钥的格式成功', () {
      // 32 字节的 Base64 编码
      final validKeyJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_002',
          'created_at': '2025-06-15T10:30:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': base64Encode(
            List.generate(32, (index) => index),
          ),
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(validKeyJson);

      expect(result.isValid, true);
    });

    // ========== 必填字段缺失测试用例 ==========

    test('缺少 format_version 时应验证失败', () {
      final invalidJson = {
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('format_version')),
        true,
      );
    });

    test('缺少 key_metadata 对象时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_metadata')), true);
    });

    test('缺少 key_metadata.key_id 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_id')), true);
    });

    test('缺少 key_metadata.created_at 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('created_at')), true);
    });

    test('缺少 key_metadata.key_algorithm 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_algorithm')), true);
    });

    test('密钥算法不支持时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': 'AES-128-CBC',
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的密钥算法')),
        true,
      );
    });

    test('缺少 key_metadata.key_length_bits 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_length_bits')), true);
    });

    test('密钥长度不是 256 位时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 128,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的密钥长度')),
        true,
      );
    });

    test('缺少 key_data 对象时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_data')), true);
    });

    test('缺少 key_data.key_base64 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('key_base64')), true);
    });

    test('key_data.key_base64 为空字符串时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': '',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('不能为空')), true);
    });

    test(
        'key_data.key_base64 格式无效（包含非法 Base64 字符）时应验证失败',
        () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': '!!!invalid!!!',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不是有效的 Base64')),
        true,
      );
    });

    test('key_data.key_base64 包含空格时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVs bG9X b3Js Z',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不是有效的 Base64')),
        true,
      );
    });

    test('缺少 key_data.encoding 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('encoding')), true);
    });

    test('encoding 不是 base64 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'hex',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的编码格式')),
        true,
      );
    });

    test('缺少 integrity 对象时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity')), true);
    });

    test('缺少 integrity.hash 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash_algorithm': HASH_ALGORITHM_SHA256,
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity.hash')), true);
    });

    test('缺少 integrity.hash_algorithm 时应验证失败', () {
      final invalidJson = {
        'format_version': KEY_FORMAT_VERSION,
        'key_metadata': {
          'key_id': 'key_001',
          'created_at': '2025-01-01T00:00:00Z',
          'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'key_length_bits': 256,
        },
        'key_data': {
          'key_base64': 'SGVsbG9Xb3JsZEtleURhdGFBQkNERUY=',
          'encoding': 'base64',
        },
        'integrity': {
          'hash':
              'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        },
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('hash_algorithm')),
        true,
      );
    });

    // ========== 收集多个错误测试用例 ==========

    test('应收集所有验证错误而非在第一个错误处停止', () {
      final invalidJson = {
        'key_metadata': {},
        'key_data': {},
        'integrity': {},
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.length, greaterThan(1));
    });
  });
}
