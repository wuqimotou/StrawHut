import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/validation/format_validator.dart';
import 'package:strawhut/core/validation/validation_result.dart';

void main() {
  late FormatValidator formatValidator;

  setUp(() {
    formatValidator = FormatValidator();
  });

  /// 构建 v2.0 格式的有效 .straw JSON 模板
  ///
  /// 使用 v2.0 二进制容器格式的 content 字段：
  /// encryption_algorithm / chunk_size / total_chunks / original_payload_size
  Map<String, dynamic> buildValidStrawJson({
    String formatVersion = '2.0.0',
    Map<String, dynamic>? metaOverrides,
    Map<String, dynamic>? contentOverrides,
    Map<String, dynamic>? integrityOverrides,
  }) {
    return {
      'format_version': formatVersion,
      'meta': {
        'publisher_alias': 'test_user',
        'publish_date': '2025-01-01T00:00:00Z',
        'title': '测试知识卡片',
        'is_anonymous': false,
        'tags': ['Flutter', '测试'],
        'description': '这是一个测试描述',
        ...?metaOverrides,
      },
      'content': {
        'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
        'chunk_size': 1048576,
        'total_chunks': 3,
        'original_payload_size': 2500000,
        ...?contentOverrides,
      },
      'integrity': {
        'hash':
            'sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        'hash_algorithm': HASH_ALGORITHM_SHA256,
        ...?integrityOverrides,
      },
    };
  }

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

  group('FormatValidator.validateStrawFormat - v2.0 有效格式', () {
    test('应验证有效的 v2.0 .straw 文件格式成功', () {
      final validStrawJson = buildValidStrawJson();

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应验证匿名模式的 .straw 文件格式成功', () {
      final validStrawJson = buildValidStrawJson(
        metaOverrides: {
          'publisher_alias': '${ANONYMOUS_PREFIX}a3f7b2c1',
          'publish_date': '2025-06-15T10:30:00Z',
          'title': '匿名卡片',
          'is_anonymous': true,
        },
      );

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
    });

    test('应验证包含最大数量标签的格式成功', () {
      final validStrawJson = buildValidStrawJson(
        metaOverrides: {
          'tags': List.generate(MAX_TAGS_COUNT, (index) => 'tag$index'),
        },
      );

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
    });

    test('应验证包含可选 KDF 字段的格式成功', () {
      final validStrawJson = buildValidStrawJson(
        contentOverrides: {
          'salt': 'base64SaltValue==',
          'kdf_algorithm': KDF_ALGORITHM_PBKDF2,
          'kdf_iterations': KDF_ITERATIONS,
        },
      );

      final result = formatValidator.validateStrawFormat(validStrawJson);

      expect(result.isValid, true);
    });

    test('v2.0 content 不应包含 encrypted_data 和 iv 字段（逻辑验证）', () {
      final validStrawJson = buildValidStrawJson();

      final content = validStrawJson['content'] as Map<String, dynamic>;
      // v2.0 格式中 content 不再使用 encrypted_data 和 iv
      expect(content.containsKey('encrypted_data'), isFalse);
      expect(content.containsKey('iv'), isFalse);
      expect(content.containsKey('chunk_size'), isTrue);
      expect(content.containsKey('total_chunks'), isTrue);
      expect(content.containsKey('original_payload_size'), isTrue,);
    });
  });

  group('FormatValidator.validateStrawFormat - 必填字段缺失', () {
    test('缺少 format_version 时应验证失败', () {
      final invalidJson = buildValidStrawJson()..remove('format_version');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('format_version')),
        true,
      );
    });

    test('缺少 meta 对象时应验证失败', () {
      final invalidJson = buildValidStrawJson()..remove('meta');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('meta')), true);
    });

    test('缺少 meta.publisher_alias 时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        metaOverrides: {}..remove('publisher_alias'),
      );
      (invalidJson['meta'] as Map<String, dynamic>).remove('publisher_alias');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('publisher_alias')),
        true,
      );
    });

    test('缺少 meta.publish_date 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['meta'] as Map<String, dynamic>).remove('publish_date');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('publish_date')),
        true,
      );
    });

    test('缺少 meta.title 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['meta'] as Map<String, dynamic>).remove('title');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('title')), true);
    });

    test('meta.title 为空字符串时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        metaOverrides: {'title': ''},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('不能为空')), true);
    });

    test('缺少 meta.is_anonymous 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['meta'] as Map<String, dynamic>).remove('is_anonymous');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('is_anonymous')),
        true,
      );
    });

    test('缺少 content 对象时应验证失败', () {
      final invalidJson = buildValidStrawJson()..remove('content');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('content')), true);
    });

    test('缺少 content.encryption_algorithm 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['content'] as Map<String, dynamic>)
          .remove('encryption_algorithm');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('encryption_algorithm')),
        true,
      );
    });

    test('缺少 content.chunk_size 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['content'] as Map<String, dynamic>).remove('chunk_size');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('chunk_size')),
        true,
      );
    });

    test('缺少 content.total_chunks 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['content'] as Map<String, dynamic>).remove('total_chunks');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('total_chunks')),
        true,
      );
    });

    test('缺少 content.original_payload_size 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['content'] as Map<String, dynamic>)
          .remove('original_payload_size');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('original_payload_size')),
        true,
      );
    });

    test('缺少 integrity 对象时应验证失败', () {
      final invalidJson = buildValidStrawJson()..remove('integrity');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity')), true);
    });

    test('缺少 integrity.hash 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['integrity'] as Map<String, dynamic>).remove('hash');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.any((e) => e.contains('integrity.hash')), true);
    });

    test('缺少 integrity.hash_algorithm 时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      (invalidJson['integrity'] as Map<String, dynamic>)
          .remove('hash_algorithm');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('hash_algorithm')),
        true,
      );
    });
  });

  group('FormatValidator.validateStrawFormat - content 字段值验证', () {
    test('加密算法不支持时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {
          'encryption_algorithm': 'AES-128-CBC',
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的加密算法')),
        true,
      );
    });

    test('content.chunk_size 为零时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'chunk_size': 0},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('chunk_size') && e.contains('正整数')),
        true,
      );
    });

    test('content.chunk_size 为负数时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'chunk_size': -1},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('chunk_size') && e.contains('正整数')),
        true,
      );
    });

    test('content.chunk_size 为非整数（字符串）时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'chunk_size': 'not_a_number'},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('chunk_size') && e.contains('正整数')),
        true,
      );
    });

    test('content.total_chunks 为零时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'total_chunks': 0},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors
            .any((e) => e.contains('total_chunks') && e.contains('正整数')),
        true,
      );
    });

    test('content.total_chunks 为负数时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'total_chunks': -5},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors
            .any((e) => e.contains('total_chunks') && e.contains('正整数')),
        true,
      );
    });

    test('content.total_chunks 为非整数（字符串）时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'total_chunks': 'three'},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors
            .any((e) => e.contains('total_chunks') && e.contains('正整数')),
        true,
      );
    });

    test('content.original_payload_size 为负数时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'original_payload_size': -100},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any(
            (e) => e.contains('original_payload_size') && e.contains('非负整数'),),
        true,
      );
    });

    test('content.original_payload_size 为非整数（字符串）时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        contentOverrides: {'original_payload_size': 'large'},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any(
            (e) => e.contains('original_payload_size') && e.contains('非负整数'),),
        true,
      );
    });

    test('content.original_payload_size 为零时应验证成功（空载荷合法）', () {
      final validJson = buildValidStrawJson(
        contentOverrides: {'original_payload_size': 0},
      );

      final result = formatValidator.validateStrawFormat(validJson);

      expect(result.isValid, true);
    });

    test('content 不是 Map 类型时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      invalidJson['content'] = 'not_a_map';

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('content') && e.contains('对象')),
        true,
      );
    });
  });

  group('FormatValidator.validateStrawFormat - integrity 字段值验证', () {
    test('integrity.hash 格式无效（哈希值过短）时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        integrityOverrides: {'hash': 'sha256:abc123'},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 使用 md5 前缀时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        integrityOverrides: {
          'hash': 'md5:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 包含大写十六进制字符时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        integrityOverrides: {
          'hash':
              'sha256:A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2',
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('integrity.hash 包含非十六进制字符时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        integrityOverrides: {
          'hash':
              'sha256:ghijklmnopqrstuvwxyz1234567890ghijklmnopqrstuvwxyz123456',
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity.hash 格式无效')),
        true,
      );
    });

    test('哈希算法不支持时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        integrityOverrides: {'hash_algorithm': 'MD5'},
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不支持的哈希算法')),
        true,
      );
    });

    test('integrity 不是 Map 类型时应验证失败', () {
      final invalidJson = buildValidStrawJson();
      invalidJson['integrity'] = 'not_a_map';

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('integrity') && e.contains('对象')),
        true,
      );
    });
  });

  group('FormatValidator.validateStrawFormat - 标签和描述限制', () {
    test('标签数量超过限制时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        metaOverrides: {
          'tags': List.generate(MAX_TAGS_COUNT + 1, (index) => 'tag$index'),
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('标签数量超出限制')),
        true,
      );
    });

    test('标签长度超过限制时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        metaOverrides: {
          'tags': ['a' * (MAX_TAG_LENGTH + 1)],
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('长度超出限制')),
        true,
      );
    });

    test('描述长度超过限制时应验证失败', () {
      final invalidJson = buildValidStrawJson(
        metaOverrides: {
          'description': 'a' * (MAX_DESCRIPTION_LENGTH + 1),
        },
      );

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('描述长度超出限制')),
        true,
      );
    });
  });

  group('FormatValidator.validateStrawFormat - 版本号兼容性', () {
    test('主版本号为 1 的 format_version 应验证失败', () {
      final invalidJson = buildValidStrawJson(formatVersion: '1.0.0');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不兼容的格式版本号')),
        true,
      );
    });

    test('主版本号为 1.1.0 的 format_version 应验证失败', () {
      final invalidJson = buildValidStrawJson(formatVersion: '1.1.0');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不兼容的格式版本号')),
        true,
      );
    });

    test('主版本号为 3 的 format_version 应验证失败', () {
      final invalidJson = buildValidStrawJson(formatVersion: '3.0.0');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('不兼容的格式版本号')),
        true,
      );
    });

    test('次版本号不同但主版本为 2 应验证成功', () {
      final validJson = buildValidStrawJson(formatVersion: '2.5.0');

      final result = formatValidator.validateStrawFormat(validJson);

      expect(result.isValid, true);
    });

    test('修订号不同但主版本为 2 应验证成功', () {
      final validJson = buildValidStrawJson(formatVersion: '2.0.3');

      final result = formatValidator.validateStrawFormat(validJson);

      expect(result.isValid, true);
    });

    test('format_version 为空字符串时应验证失败', () {
      final invalidJson = buildValidStrawJson(formatVersion: '');

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('format_version 不能为空')),
        true,
      );
    });
  });

  group('FormatValidator.validateStrawFormat - 收集多个错误', () {
    test('应收集所有验证错误而非在第一个错误处停止', () {
      final invalidJson = {
        'meta': {
          'title': '',
        },
        'content': <String, dynamic>{},
        'integrity': <String, dynamic>{},
      };

      final result = formatValidator.validateStrawFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.length, greaterThan(1));
    });
  });

  group('FormatValidator.validateBinaryFormat', () {
    test('有效的 STRAWHUT Magic Bytes 应验证成功', () {
      // "STRAWHUT" 的 ASCII 编码
      final validBytes = Uint8List.fromList(STRAW_MAGIC_BYTES);

      final result = formatValidator.validateBinaryFormat(validBytes);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('Magic Bytes 后跟其他数据应验证成功', () {
      final bytes = Uint8List.fromList([
        ...STRAW_MAGIC_BYTES,
        ...utf8.encode('{"format_version": "2.0.0"}'),
      ]);

      final result = formatValidator.validateBinaryFormat(bytes);

      expect(result.isValid, true);
    });

    test('Magic Bytes 不匹配时应验证失败', () {
      // "NOTAHUTX" - 与 STRAWHUT 不同的 8 字节
      final invalidBytes =
          Uint8List.fromList([0x4E, 0x4F, 0x54, 0x41, 0x48, 0x55, 0x54, 0x58]);

      final result = formatValidator.validateBinaryFormat(invalidBytes);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('Magic Bytes 不匹配')),
        true,
      );
    });

    test('数据过短（不足 8 字节）时应验证失败', () {
      final shortBytes = Uint8List.fromList([0x53, 0x54, 0x52]); // "STR"

      final result = formatValidator.validateBinaryFormat(shortBytes);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('文件数据过短')),
        true,
      );
    });

    test('空字节数组应验证失败', () {
      final emptyBytes = Uint8List(0);

      final result = formatValidator.validateBinaryFormat(emptyBytes);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('文件数据过短')),
        true,
      );
    });

    test('恰好 8 字节的有效 Magic Bytes 应验证成功', () {
      final exactBytes = Uint8List.fromList(STRAW_MAGIC_BYTES);

      final result = formatValidator.validateBinaryFormat(exactBytes);

      expect(result.isValid, true);
    });

    test('第一个字节错误应验证失败', () {
      final invalidBytes = Uint8List.fromList(STRAW_MAGIC_BYTES);
      invalidBytes[0] = 0x00; // 修改第一个字节

      final result = formatValidator.validateBinaryFormat(invalidBytes);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('Magic Bytes 不匹配')),
        true,
      );
    });

    test('最后一个字节错误应验证失败', () {
      final invalidBytes = Uint8List.fromList(STRAW_MAGIC_BYTES);
      invalidBytes[7] = 0x00; // 修改最后一个字节

      final result = formatValidator.validateBinaryFormat(invalidBytes);

      expect(result.isValid, false);
      expect(
        result.errors.any((e) => e.contains('Magic Bytes 不匹配')),
        true,
      );
    });

    test('全部为零的字节数组应验证失败', () {
      final zeroBytes = Uint8List(8);

      final result = formatValidator.validateBinaryFormat(zeroBytes);

      expect(result.isValid, false);
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

    test('key_data.key_base64 格式无效（包含非法 Base64 字符）时应验证失败', () {
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
      final invalidJson = <String, dynamic>{
        'key_metadata': <String, dynamic>{},
        'key_data': <String, dynamic>{},
        'integrity': <String, dynamic>{},
      };

      final result = formatValidator.validateKeyFormat(invalidJson);

      expect(result.isValid, false);
      expect(result.errors.length, greaterThan(1));
    });
  });
}
