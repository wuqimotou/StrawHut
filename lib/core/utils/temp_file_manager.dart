import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 临时文件管理服务
///
/// 管理解密后的临时文件，确保安全创建和删除。
/// 临时文件用于多媒体播放和其他文件查看场景。
class TempFileManager {
  TempFileManager._();

  /// 临时文件子目录名称
  static const _tempSubdir = 'strawhut_temp';

  /// 生成随机文件名
  ///
  /// 使用时间戳 + 安全随机数组合，避免依赖 uuid 包。
  static String _generateRandomName() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = List.generate(
      8,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return '${timestamp}_$randomPart';
  }

  /// 获取临时文件目录路径
  static Future<String> getTempDirectory() async {
    final baseDir = await getTemporaryDirectory();
    final tempDir = Directory(p.join(baseDir.path, _tempSubdir));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }

  /// 生成一个随机临时文件路径（不创建文件）
  ///
  /// 安全性：
  /// - 使用 [Random.secure] 生成不可预测的文件名，防止符号链接劫持攻击
  /// - 文件名包含 16 字节随机数据的 hex 编码（32 字符），攻击者无法预测
  ///
  /// 参数：
  /// - [extension]: 文件扩展名（不含点），如 'tmp'、'bin'
  ///
  /// 返回：临时目录下的完整随机文件路径
  static Future<String> generateRandomTempPath({String extension = 'tmp'}) async {
    final tempDir = await getTempDirectory();
    final random = Random.secure();
    final randomBytes = List.generate(16, (_) => random.nextInt(256));
    final hex = randomBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final fileName = 'decrypt_$hex.$extension';
    return p.join(tempDir, fileName);
  }

  /// 创建临时文件
  ///
  /// 在临时目录下创建一个随机命名的文件。
  /// 返回文件的完整路径。
  static Future<String> createTempFile({
    required String extension,
    required List<int> bytes,
  }) async {
    // 先清理旧文件
    await cleanAll();

    final tempDir = await getTempDirectory();
    final fileName = '${_generateRandomName()}.$extension';
    final filePath = p.join(tempDir, fileName);
    final file = File(filePath);

    // 流式写入大文件
    final sink = file.openWrite();
    sink.add(bytes);
    await sink.flush();
    await sink.close();

    return filePath;
  }

  /// 流式创建临时文件（用于大文件）
  static Future<String> createTempFileStream({
    required String extension,
    required Stream<List<int>> dataStream,
  }) async {
    // 先清理旧文件
    await cleanAll();

    final tempDir = await getTempDirectory();
    final fileName = '${_generateRandomName()}.$extension';
    final filePath = p.join(tempDir, fileName);
    final file = File(filePath);

    final sink = file.openWrite();
    await dataStream.pipe(sink);

    return filePath;
  }

  /// 删除指定临时文件
  static Future<void> deleteTempFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } on Exception {
        // 忽略删除失败，启动时会再次清理
      }
    }
  }

  /// 清理所有临时文件
  ///
  /// 删除 strawhut_temp/ 目录下的所有文件。
  static Future<void> cleanAll() async {
    try {
      final tempDir = await getTempDirectory();
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } on Exception {
            // 忽略单个文件删除失败
          }
        }
      }
    } on Exception {
      // 忽略清理失败
    }
  }

  /// 检查临时文件是否存在
  static Future<bool> tempFileExists(String filePath) async {
    final file = File(filePath);
    return file.exists();
  }
}
