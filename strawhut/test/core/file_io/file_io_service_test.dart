import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/core/file_io/file_extensions.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/validation/format_validator.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// FileIOService 单元测试
///
/// 测试策略：
/// 由于 FileIOService 直接使用 dart:io 的 File 类（没有依赖注入抽象），
/// 采用临时目录方案进行测试：
/// 1. 使用 Directory.systemTemp.createTemp() 为每个测试创建临时目录
/// 2. 在临时目录中创建真实的测试文件
/// 3. 在 tearDown 中清理临时目录
///
/// 覆盖场景：
/// - 扩展名校验（正例与反例）
/// - 文件读取全流程（6 步管道的各个环节）
/// - 文件写入（新建与覆盖）
/// - 往返测试（写入后读取验证数据一致性）
void main() {
  late FileIOService fileIOService;
  late Directory tempDir;

  setUp(() async {
    fileIOService = FileIOService();
    // 为每个测试创建独立的临时目录，避免测试之间相互影响
    tempDir = await Directory.systemTemp.createTemp('strawhut_test_');
  });

  tearDown(() async {
    // 清理临时目录，删除测试过程中创建的所有文件
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ==========================================
  // 辅助方法：生成有效的 .straw JSON 字符串
  // ==========================================
  /// 生成一个完整的、格式正确的 .straw 文件 JSON 字符串
  /// 包含所有必填字段，确保能通过 FormatValidator 的验证
  String generateValidStrawJson({
    String title = '测试知识卡片',
    String description = '这是一个测试描述',
    List<String> tags = const ['test'],
    bool isAnonymous = true,
    String formatVersion = '1.0.0',
  }) {
    return jsonEncode({
      'format_version': formatVersion,
      'meta': {
        'publisher_alias': 'Anonymous_a3f7b2c1',
        'publish_date': '2026-05-01T12:00:00Z',
        'title': title,
        'tags': tags,
        'description': description,
        'is_anonymous': isAnonymous,
      },
      'content': {
        'encrypted_data': 'dGVzdA==',
        'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
        'iv': 'YWJjZGVmZ2hpamtsbW5vcA==',
      },
      'integrity': {
        'hash':
            'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
        'hash_algorithm': HASH_ALGORITHM_SHA256,
      },
    });
  }

  // ==========================================
  // 辅助方法：生成有效的 .key JSON 字符串
  // ==========================================
  /// 生成一个完整的、格式正确的 .key 文件 JSON 字符串
  /// 包含所有必填字段，确保能通过 FormatValidator 的验证
  String generateValidKeyJson({
    String keyId = 'k_20260501120000000_a3f7b2c1',
    String associatedCardTitle = '测试知识卡片',
    String formatVersion = '1.0.0',
  }) {
    return jsonEncode({
      'format_version': formatVersion,
      'key_metadata': {
        'key_id': keyId,
        'created_at': '2026-05-01T12:00:00Z',
        'associated_card_title': associatedCardTitle,
        'key_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
        'key_length_bits': 256,
      },
      'key_data': {
        'key_base64': '5T2skvZAuZkwvc3/Qom+bTxDrmQQb061Z+EyeQ1y3Xk=',
        'encoding': 'base64',
      },
      'integrity': {
        'hash': 'sha256:fedcba0987654321abcdef0123456789abcdef0123456789abcdef0123456789',
        'hash_algorithm': HASH_ALGORITHM_SHA256,
      },
    });
  }

  // ==========================================
  // 辅助方法：生成无效的 JSON 字符串
  // ==========================================
  /// 生成格式错误的 JSON 字符串（缺少右大括号），用于测试 JSON 解析异常
  String generateInvalidJson() {
    return '{"format_version": "1.0.0", "broken"';
  }

  // ==========================================
  // 辅助方法：生成不完整的 JSON 字符串
  // ==========================================
  /// 生成合法的 JSON 但缺少必填字段的字符串
  /// 用于测试 FormatValidator 验证失败的异常路径
  String generateIncompleteStrawJson() {
    return jsonEncode({
      'format_version': '1.0.0',
      // 缺少 meta、content、integrity 等必填对象
    });
  }

  /// 生成合法的 .key JSON 但缺少必填字段
  String generateIncompleteKeyJson() {
    return jsonEncode({
      'format_version': '1.0.0',
      // 缺少 key_metadata、key_data、integrity 等必填对象
    });
  }

  // ==========================================
  // isValidStrawFile 测试
  // ==========================================
  group('FileIOService.isValidStrawFile', () {
    test('对于以 .straw 结尾的路径应返回 true', () {
      // 测试：标准的 .straw 文件路径应被识别为有效
      expect(fileIOService.isValidStrawFile('/path/to/file.straw'), true);
    });

    test('对于以 .key 结尾的路径应返回 false', () {
      // 测试：.key 扩展名的文件不应被识别为 .straw 文件
      expect(fileIOService.isValidStrawFile('/path/to/file.key'), false);
    });

    test('对于以 .txt 结尾的路径应返回 false', () {
      // 测试：其他文本文件扩展名应被拒绝
      expect(fileIOService.isValidStrawFile('/path/to/file.txt'), false);
    });

    test('对于没有扩展名的路径应返回 false', () {
      // 测试：没有扩展名的文件路径应被拒绝
      expect(fileIOService.isValidStrawFile('/path/to/file'), false);
    });

    test('对于 .straw 出现在文件名中间的情况应返回 false', () {
      // 测试：扩展名校验应检查文件名的最后部分，
      // 例如 'file.straw.bak' 的实际扩展名是 .bak 而非 .straw
      expect(fileIOService.isValidStrawFile('/path/to/file.straw.bak'), false);
    });
  });

  // ==========================================
  // isValidKeyFile 测试
  // ==========================================
  group('FileIOService.isValidKeyFile', () {
    test('对于以 .key 结尾的路径应返回 true', () {
      // 测试：标准的 .key 文件路径应被识别为有效
      expect(fileIOService.isValidKeyFile('/path/to/file.key'), true);
    });

    test('对于以 .straw 结尾的路径应返回 false', () {
      // 测试：.straw 扩展名的文件不应被识别为 .key 文件
      expect(fileIOService.isValidKeyFile('/path/to/file.straw'), false);
    });

    test('对于以 .json 结尾的路径应返回 false', () {
      // 测试：.json 扩展名的文件不应被识别为 .key 文件
      expect(fileIOService.isValidKeyFile('/path/to/file.json'), false);
    });
  });

  // ==========================================
  // readStrawFile 测试
  // ==========================================
  group('FileIOService.readStrawFile', () {
    test('对于非 .straw 文件应抛出 FileException，code 为 INVALID_EXTENSION',
        () async {
      // 测试：扩展名校验是读取流程的第一步，
      // 应在尝试读取文件之前就拒绝非 .straw 文件
      expect(
        () async => fileIOService.readStrawFile('/path/to/file.txt'),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'INVALID_EXTENSION',
        )),
      );
    });

    test('对于不存在的 .straw 文件应抛出 FileException，code 为 FILE_NOT_FOUND',
        () async {
      // 测试：即使扩展名正确，如果文件不存在也应快速失败
      // 这避免了无意义的 I/O 操作并提供了清晰的错误信息
      final nonExistentPath = '${tempDir.path}/nonexistent.straw';

      expect(
        () async => fileIOService.readStrawFile(nonExistentPath),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'FILE_NOT_FOUND',
        )),
      );
    });

    test('对于包含无效 JSON 的文件应抛出 FileException，code 为 INVALID_FORMAT',
        () async {
      // 测试：文件内容不是有效 JSON 时应拒绝解析
      // 这防止了损坏或被篡改的文件进入系统
      final invalidJsonFile = File('${tempDir.path}/invalid.straw');
      await invalidJsonFile.writeAsString(generateInvalidJson());

      expect(
        () async => fileIOService.readStrawFile(invalidJsonFile.path),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'INVALID_FORMAT',
        )),
      );
    });

    test(
        '对于有效 JSON 但缺少必填字段的文件应抛出 FileException，code 为 VALIDATION_FAILED',
        () async {
      // 测试：JSON 格式正确但缺少必填字段（如 meta、content、integrity）时，
      // FormatValidator 应检测到并拒绝该文件
      // 这是安全验证的核心步骤，确保文件结构完整
      final incompleteFile = File('${tempDir.path}/incomplete.straw');
      await incompleteFile.writeAsString(generateIncompleteStrawJson());

      expect(
        () async => fileIOService.readStrawFile(incompleteFile.path),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'VALIDATION_FAILED',
        )),
      );
    });

    test('成功读取并解析有效的 .straw 文件', () async {
      // 测试：完整的 6 步流程（扩展名检查 -> 存在性检查 -> 读取 ->
      // JSON 解析 -> 格式验证 -> 反序列化）应成功执行
      final validJson = generateValidStrawJson();
      final validFile = File('${tempDir.path}/valid.straw');
      await validFile.writeAsString(validJson);

      // 不应抛出异常
      final result = await fileIOService.readStrawFile(validFile.path);

      // 验证返回的是 StrawFile 对象
      expect(result, isA<StrawFile>());
    });

    test('返回的 StrawFile 对象应包含所有正确填充的字段', () async {
      // 测试：读取后反序列化的 StrawFile 对象应完整还原文件中的所有数据
      // 包括嵌套的 meta、content、integrity 对象
      final validFile = File('${tempDir.path}/detailed.straw');
      await validFile.writeAsString(generateValidStrawJson(
        title: '详细测试卡片',
        description: '这是一个详细的测试描述',
        tags: ['Dart', '测试', '单元测试'],
        isAnonymous: false,
      ));

      final result = await fileIOService.readStrawFile(validFile.path);

      // 验证顶层字段
      expect(result.formatVersion.toString(), '1.0.0');

      // 验证 meta 字段
      expect(result.meta.title, '详细测试卡片');
      expect(result.meta.description, '这是一个详细的测试描述');
      expect(result.meta.isAnonymous, false);
      expect(result.meta.tags, ['Dart', '测试', '单元测试']);
      expect(result.meta.publisherAlias, 'Anonymous_a3f7b2c1');

      // 验证 content 字段
      expect(result.content.encryptedDataBase64, 'dGVzdA==');
      expect(result.content.algorithm, ENCRYPTION_ALGORITHM_AES_256_GCM);

      // 验证 integrity 字段
      expect(result.integrity.hashAlgorithm, HASH_ALGORITHM_SHA256);
    });
  });

  // ==========================================
  // writeStrawFile 测试
  // ==========================================
  group('FileIOService.writeStrawFile', () {
    test('成功将 JSON 字符串写入新文件', () async {
      // 测试：writeStrawFile 应能在指定路径创建新文件并写入内容
      // 文件内容应与传入的 JSON 字符串完全一致
      final newFilePath = '${tempDir.path}/new_card.straw';
      const testContent = '{"format_version": "1.0.0"}';

      await fileIOService.writeStrawFile(
        content: testContent,
        targetPath: newFilePath,
      );

      // 验证文件已创建且内容正确
      final createdFile = File(newFilePath);
      expect(await createdFile.exists(), true);
      expect(await createdFile.readAsString(), testContent);
    });

    test('成功覆盖已存在的文件', () async {
      // 测试：当目标文件已存在时，writeStrawFile 应覆盖原有内容
      // 而不是追加或抛出异常
      final existingFilePath = '${tempDir.path}/existing.straw';
      final existingFile = File(existingFilePath);

      // 先创建一个已存在的文件
      await existingFile.writeAsString('旧内容');

      // 写入新内容应覆盖旧内容
      const newContent = '{"format_version": "1.0.0", "new": true}';
      await fileIOService.writeStrawFile(
        content: newContent,
        targetPath: existingFilePath,
      );

      // 验证文件内容已被完全替换
      expect(await existingFile.readAsString(), newContent);
    });

    test(
        '对于无效路径（如将目录作为目标）应抛出 FileException，code 为 WRITE_FAILED',
        () async {
      // 测试：当目标路径无效时（例如指向一个已存在的目录），
      // 应抛出 WRITE_FAILED 异常，而不是静默失败或导致文件系统损坏
      final directoryPath = tempDir.path;

      expect(
        () async => fileIOService.writeStrawFile(
          content: '{"test": true}',
          targetPath: directoryPath,
        ),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'WRITE_FAILED',
        )),
      );
    });
  });

  // ==========================================
  // readKeyFile 测试
  // ==========================================
  group('FileIOService.readKeyFile', () {
    test('对于非 .key 文件应抛出 FileException，code 为 INVALID_EXTENSION',
        () async {
      // 测试：密钥文件的扩展名校验与 .straw 文件相同，
      // 必须在读取前拒绝非 .key 文件，防止误读敏感文件
      expect(
        () async => fileIOService.readKeyFile('/path/to/file.straw'),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'INVALID_EXTENSION',
        )),
      );
    });

    test('对于不存在的 .key 文件应抛出 FileException，code 为 FILE_NOT_FOUND',
        () async {
      // 测试：扩展名正确但文件不存在时应快速失败
      final nonExistentPath = '${tempDir.path}/nonexistent.key';

      expect(
        () async => fileIOService.readKeyFile(nonExistentPath),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'FILE_NOT_FOUND',
        )),
      );
    });

    test('对于包含无效 JSON 的文件应抛出 FileException，code 为 INVALID_FORMAT',
        () async {
      // 测试：密钥文件的 JSON 格式错误是非常严重的安全问题，
      // 可能意味着密钥文件被篡改或损坏
      final invalidJsonFile = File('${tempDir.path}/invalid.key');
      await invalidJsonFile.writeAsString(generateInvalidJson());

      expect(
        () async => fileIOService.readKeyFile(invalidJsonFile.path),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'INVALID_FORMAT',
        )),
      );
    });

    test(
        '对于有效 JSON 但缺少必填字段的文件应抛出 FileException，code 为 VALIDATION_FAILED',
        () async {
      // 测试：密钥文件缺少必填字段（如 key_metadata、key_data、integrity）时，
      // FormatValidator 应检测到并拒绝，防止使用不完整的密钥进行解密
      final incompleteFile = File('${tempDir.path}/incomplete.key');
      await incompleteFile.writeAsString(generateIncompleteKeyJson());

      expect(
        () async => fileIOService.readKeyFile(incompleteFile.path),
        throwsA(isA<FileException>().having(
          (e) => e.code,
          'code',
          'VALIDATION_FAILED',
        )),
      );
    });

    test('成功读取并解析有效的 .key 文件', () async {
      // 测试：完整的 6 步流程应成功解析有效的 .key 文件
      final validJson = generateValidKeyJson();
      final validFile = File('${tempDir.path}/valid.key');
      await validFile.writeAsString(validJson);

      final result = await fileIOService.readKeyFile(validFile.path);

      expect(result, isA<KeyFile>());
    });

    test('返回的 KeyFile 对象应包含所有正确填充的字段', () async {
      // 测试：反序列化后的 KeyFile 对象应完整还原文件中的所有数据
      final validFile = File('${tempDir.path}/detailed.key');
      await validFile.writeAsString(generateValidKeyJson(
        keyId: 'k_20260501120000000_test123',
        associatedCardTitle: '我的知识卡片',
      ));

      final result = await fileIOService.readKeyFile(validFile.path);

      // 验证顶层字段
      expect(result.formatVersion.toString(), '1.0.0');

      // 验证 key_metadata 字段
      expect(result.keyMetadata.keyId, 'k_20260501120000000_test123');
      expect(result.keyMetadata.associatedCardTitle, '我的知识卡片');
      expect(result.keyMetadata.keyAlgorithm, ENCRYPTION_ALGORITHM_AES_256_GCM);
      expect(result.keyMetadata.keyLengthBits, 256);

      // 验证 key_data 字段
      expect(result.keyData.keyBase64, '5T2skvZAuZkwvc3/Qom+bTxDrmQQb061Z+EyeQ1y3Xk=');
      expect(result.keyData.encoding, 'base64');

      // 验证 integrity 字段
      expect(result.integrity.hashAlgorithm, HASH_ALGORITHM_SHA256);
    });
  });

  // ==========================================
  // writeKeyFile 测试
  // ==========================================
  group('FileIOService.writeKeyFile', () {
    test('成功将 JSON 字符串写入新文件', () async {
      // 测试：writeKeyFile 应能在指定路径创建新的 .key 文件
      final newFilePath = '${tempDir.path}/new_key.key';
      const testContent = '{"format_version": "1.0.0"}';

      await fileIOService.writeKeyFile(
        content: testContent,
        targetPath: newFilePath,
      );

      // 验证文件已创建且内容正确
      final createdFile = File(newFilePath);
      expect(await createdFile.exists(), true);
      expect(await createdFile.readAsString(), testContent);
    });

    test('成功覆盖已存在的文件', () async {
      // 测试：当 .key 文件已存在时，应能完全覆盖原有内容
      final existingFilePath = '${tempDir.path}/existing.key';
      final existingFile = File(existingFilePath);

      // 先创建已存在的文件
      await existingFile.writeAsString('旧密钥内容');

      // 写入新密钥内容
      const newContent = '{"format_version": "1.0.0", "new_key": true}';
      await fileIOService.writeKeyFile(
        content: newContent,
        targetPath: existingFilePath,
      );

      // 验证文件内容已被完全替换
      expect(await existingFile.readAsString(), newContent);
    });
  });

  // ==========================================
  // 往返测试（Round-trip Tests）
  // ==========================================
  group('往返测试（Round-trip Tests）', () {
    test('写入有效的 .straw 文件后再读取回来，数据应完全匹配', () async {
      // 测试：写入和读取的完整往返流程应保证数据完整性
      // 这是验证序列化/反序列化一致性的关键测试
      final filePath = '${tempDir.path}/roundtrip.straw';

      // 使用辅助方法构建完整的 JSON
      final validStrawJson = generateValidStrawJson(
        title: '往返测试卡片',
        description: '用于验证读写一致性的测试卡片',
        tags: ['往返测试', '数据完整性'],
        isAnonymous: true,
      );

      // 写入文件
      await fileIOService.writeStrawFile(
        content: validStrawJson,
        targetPath: filePath,
      );

      // 读取回来
      final result = await fileIOService.readStrawFile(filePath);

      // 验证数据完整性
      expect(result.formatVersion.toString(), '1.0.0');
      expect(result.meta.title, '往返测试卡片');
      expect(result.meta.description, '用于验证读写一致性的测试卡片');
      expect(result.meta.tags, ['往返测试', '数据完整性']);
      expect(result.meta.isAnonymous, true);
      expect(result.meta.publisherAlias, 'Anonymous_a3f7b2c1');
      expect(result.content.encryptedDataBase64, 'dGVzdA==');
      expect(result.content.algorithm, ENCRYPTION_ALGORITHM_AES_256_GCM);
      expect(
        result.integrity.hash,
        'sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      );
      expect(result.integrity.hashAlgorithm, HASH_ALGORITHM_SHA256);
    });

    test('写入有效的 .key 文件后再读取回来，数据应完全匹配', () async {
      // 测试：.key 文件的往返流程同样应保证数据完整性
      // 密钥数据的任何偏差都会导致解密失败，因此这个测试尤为重要
      final filePath = '${tempDir.path}/roundtrip.key';

      // 使用辅助方法构建完整的 JSON
      final validKeyJson = generateValidKeyJson(
        keyId: 'k_20260501120000000_roundtrip',
        associatedCardTitle: '往返测试卡片',
      );

      // 写入文件
      await fileIOService.writeKeyFile(
        content: validKeyJson,
        targetPath: filePath,
      );

      // 读取回来
      final result = await fileIOService.readKeyFile(filePath);

      // 验证数据完整性
      expect(result.formatVersion.toString(), '1.0.0');
      expect(result.keyMetadata.keyId, 'k_20260501120000000_roundtrip');
      expect(result.keyMetadata.associatedCardTitle, '往返测试卡片');
      expect(result.keyMetadata.keyAlgorithm, ENCRYPTION_ALGORITHM_AES_256_GCM);
      expect(result.keyMetadata.keyLengthBits, 256);
      expect(result.keyData.keyBase64, '5T2skvZAuZkwvc3/Qom+bTxDrmQQb061Z+EyeQ1y3Xk=');
      expect(result.keyData.encoding, 'base64');
      expect(result.integrity.hashAlgorithm, HASH_ALGORITHM_SHA256);
    });
  });
}
