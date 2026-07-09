import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:strawhut/core/utils/temp_file_manager.dart';

/// Fake PathProviderPlatform
///
/// 在测试环境中模拟 path_provider 的行为，
/// 返回系统临时目录作为测试目录。
class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getDownloadsPath() async {
    return Directory.systemTemp.path;
  }
}

/// TempFileManager 单元测试
///
/// 测试策略：
/// 由于 TempFileManager 直接使用 path_provider 获取系统临时目录，
/// 采用真实文件系统操作进行测试：
/// 1. 使用 createTempFile 创建临时文件
/// 2. 验证文件存在性和内容
/// 3. 在 tearDown 中清理所有临时文件
///
/// 覆盖场景：
/// - createTempFile 创建临时文件
/// - deleteTempFile 删除临时文件
/// - cleanAll 清理所有临时文件
/// - tempFileExists 检查文件存在
/// - getTempDirectory 获取临时目录
void main() {
  setUp(() {
    // 设置 fake path_provider 实现
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  tearDown(() async {
    // 每个测试后清理所有临时文件
    await TempFileManager.cleanAll();
  });

  // ==========================================
  // createTempFile 测试
  // ==========================================
  group('TempFileManager.createTempFile', () {
    test('应该成功创建临时文件', () async {
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final filePath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: testBytes,
      );

      // 验证文件路径不为空
      expect(filePath, isNotEmpty);

      // 验证文件存在
      final file = File(filePath);
      expect(await file.exists(), isTrue);

      // 验证文件扩展名
      expect(filePath.endsWith('.txt'), isTrue);

      // 验证文件内容
      final content = await file.readAsBytes();
      expect(content, equals(testBytes));
    });

    test('创建临时文件时应该自动清理旧文件', () async {
      // 创建第一个临时文件
      final firstBytes = Uint8List.fromList([1, 2, 3]);
      final firstPath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: firstBytes,
      );

      // 验证第一个文件存在
      expect(await File(firstPath).exists(), isTrue);

      // 创建第二个临时文件
      final secondBytes = Uint8List.fromList([4, 5, 6]);
      final secondPath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: secondBytes,
      );

      // 验证第二个文件存在
      expect(await File(secondPath).exists(), isTrue);

      // 验证第一个文件已被清理
      expect(await File(firstPath).exists(), isFalse);
    });

    test('应该支持不同的文件扩展名', () async {
      final testBytes = Uint8List.fromList([1, 2, 3]);

      final txtPath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: testBytes,
      );
      expect(txtPath.endsWith('.txt'), isTrue);

      await TempFileManager.cleanAll();

      final pdfPath = await TempFileManager.createTempFile(
        extension: 'pdf',
        bytes: testBytes,
      );
      expect(pdfPath.endsWith('.pdf'), isTrue);

      await TempFileManager.cleanAll();

      final binPath = await TempFileManager.createTempFile(
        extension: 'bin',
        bytes: testBytes,
      );
      expect(binPath.endsWith('.bin'), isTrue);
    });

    test('应该支持创建大文件', () async {
      // 创建 1MB 的测试数据
      final largeBytes = Uint8List(1024 * 1024);
      for (var i = 0; i < largeBytes.length; i++) {
        largeBytes[i] = i & 0xFF;
      }

      final filePath = await TempFileManager.createTempFile(
        extension: 'bin',
        bytes: largeBytes,
      );

      final file = File(filePath);
      expect(await file.exists(), isTrue);

      final content = await file.readAsBytes();
      expect(content.length, equals(largeBytes.length));
    });
  });

  // ==========================================
  // deleteTempFile 测试
  // ==========================================
  group('TempFileManager.deleteTempFile', () {
    test('应该成功删除指定的临时文件', () async {
      final testBytes = Uint8List.fromList([1, 2, 3]);
      final filePath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: testBytes,
      );

      // 验证文件存在
      expect(await File(filePath).exists(), isTrue);

      // 删除文件
      await TempFileManager.deleteTempFile(filePath);

      // 验证文件已被删除
      expect(await File(filePath).exists(), isFalse);
    });

    test('删除不存在的文件时不应该抛出异常', () async {
      // 尝试删除不存在的文件
      await TempFileManager.deleteTempFile('/nonexistent/path/file.txt');

      // 不应该抛出异常，测试通过
    });
  });

  // ==========================================
  // cleanAll 测试
  // ==========================================
  group('TempFileManager.cleanAll', () {
    test('应该清理所有临时文件', () async {
      // 注意：createTempFile 会在每次调用前清理旧文件
      // 所以我们需要直接创建文件来测试 cleanAll
      final tempDir = await TempFileManager.getTempDirectory();
      final paths = <String>[];

      // 直接创建多个文件（不通过 createTempFile）
      for (var i = 0; i < 5; i++) {
        final file = File('$tempDir/test_$i.txt');
        await file.writeAsString('test $i');
        paths.add(file.path);
      }

      // 验证所有文件都存在
      for (final path in paths) {
        expect(await File(path).exists(), isTrue);
      }

      // 清理所有文件
      await TempFileManager.cleanAll();

      // 验证所有文件都被删除
      for (final path in paths) {
        expect(await File(path).exists(), isFalse);
      }
    });

    test('清理空目录时不应该抛出异常', () async {
      // 先清理所有文件
      await TempFileManager.cleanAll();

      // 再次清理（此时目录为空）
      await TempFileManager.cleanAll();

      // 不应该抛出异常，测试通过
    });
  });

  // ==========================================
  // tempFileExists 测试
  // ==========================================
  group('TempFileManager.tempFileExists', () {
    test('应该正确检查文件存在', () async {
      final testBytes = Uint8List.fromList([1, 2, 3]);
      final filePath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: testBytes,
      );

      // 验证存在的文件
      expect(await TempFileManager.tempFileExists(filePath), isTrue);

      // 删除文件
      await TempFileManager.deleteTempFile(filePath);

      // 验证已删除的文件
      expect(await TempFileManager.tempFileExists(filePath), isFalse);
    });

    test('应该正确检查不存在的文件', () async {
      expect(
        await TempFileManager.tempFileExists('/nonexistent/path/file.txt'),
        isFalse,
      );
    });
  });

  // ==========================================
  // getTempDirectory 测试
  // ==========================================
  group('TempFileManager.getTempDirectory', () {
    test('应该返回有效的临时目录路径', () async {
      final tempDir = await TempFileManager.getTempDirectory();

      // 验证路径不为空
      expect(tempDir, isNotEmpty);

      // 验证目录存在
      final dir = Directory(tempDir);
      expect(await dir.exists(), isTrue);

      // 验证目录名称包含 strawhut_temp
      expect(tempDir.contains('strawhut_temp'), isTrue);
    });

    test('多次调用应该返回相同的路径', () async {
      final path1 = await TempFileManager.getTempDirectory();
      final path2 = await TempFileManager.getTempDirectory();

      expect(path1, equals(path2));
    });

    test('如果目录不存在应该自动创建', () async {
      final tempDir = await TempFileManager.getTempDirectory();
      final dir = Directory(tempDir);

      // 删除目录
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      // 验证目录已被删除
      expect(await dir.exists(), isFalse);

      // 再次获取临时目录
      final newTempDir = await TempFileManager.getTempDirectory();
      final newDir = Directory(newTempDir);

      // 验证目录已被重新创建
      expect(await newDir.exists(), isTrue);
    });
  });

  // ==========================================
  // 集成测试
  // ==========================================
  group('TempFileManager 集成测试', () {
    test('完整的文件生命周期：创建 -> 检查 -> 删除', () async {
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // 创建文件
      final filePath = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: testBytes,
      );

      // 验证文件存在
      expect(await TempFileManager.tempFileExists(filePath), isTrue);

      // 验证文件内容
      final file = File(filePath);
      final content = await file.readAsBytes();
      expect(content, equals(testBytes));

      // 删除文件
      await TempFileManager.deleteTempFile(filePath);

      // 验证文件已被删除
      expect(await TempFileManager.tempFileExists(filePath), isFalse);
    });

    test('多次创建和清理应该正常工作', () async {
      // 第一轮
      final path1 = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: Uint8List.fromList([1]),
      );
      expect(await File(path1).exists(), isTrue);

      await TempFileManager.cleanAll();
      expect(await File(path1).exists(), isFalse);

      // 第二轮
      final path2 = await TempFileManager.createTempFile(
        extension: 'txt',
        bytes: Uint8List.fromList([2]),
      );
      expect(await File(path2).exists(), isTrue);

      await TempFileManager.cleanAll();
      expect(await File(path2).exists(), isFalse);
    });
  });
}
