import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/data/models/key_file.dart';

/// 文件 I/O 服务接口
abstract class IFileIOService {
  Future<StrawFile> readStrawFile(String filePath);

  Future<void> writeStrawFile({
    required String content,
    required String targetPath,
  });

  Future<KeyFile> readKeyFile(String filePath);

  Future<void> writeKeyFile({
    required String content,
    required String targetPath,
  });

  bool isValidStrawFile(String filePath);

  bool isValidKeyFile(String filePath);
}

/// 文件 I/O 服务实现（Phase 0 占位实现）
class FileIOService implements IFileIOService {
  @override
  Future<StrawFile> readStrawFile(String filePath) {
    // TODO: 实现真实的文件读取
    throw UnimplementedError('FileIOService.readStrawFile 尚未实现');
  }

  @override
  Future<void> writeStrawFile({
    required String content,
    required String targetPath,
  }) {
    // TODO: 实现真实的文件写入
    throw UnimplementedError('FileIOService.writeStrawFile 尚未实现');
  }

  @override
  Future<KeyFile> readKeyFile(String filePath) {
    // TODO: 实现真实的密钥文件读取
    throw UnimplementedError('FileIOService.readKeyFile 尚未实现');
  }

  @override
  Future<void> writeKeyFile({
    required String content,
    required String targetPath,
  }) {
    // TODO: 实现真实的密钥文件写入
    throw UnimplementedError('FileIOService.writeKeyFile 尚未实现');
  }

  @override
  bool isValidStrawFile(String filePath) {
    // TODO: 实现真实的 Straw 文件验证
    throw UnimplementedError('FileIOService.isValidStrawFile 尚未实现');
  }

  @override
  bool isValidKeyFile(String filePath) {
    // TODO: 实现真实的密钥文件验证
    throw UnimplementedError('FileIOService.isValidKeyFile 尚未实现');
  }
}
