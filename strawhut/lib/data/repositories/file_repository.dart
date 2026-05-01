import 'dart:convert';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/data/models/key_file.dart';

/// 文件仓库，封装文件操作
class FileRepository {
  final IFileIOService _fileIOService;

  FileRepository(this._fileIOService);

  Future<StrawFile> loadStrawFile(String filePath) async {
    return _fileIOService.readStrawFile(filePath);
  }

  Future<void> saveStrawFile({
    required StrawFile strawFile,
    required String targetPath,
  }) async {
    final content = strawFile.assembleToJson();
    await _fileIOService.writeStrawFile(content: content, targetPath: targetPath);
  }

  Future<KeyFile> loadKeyFile(String filePath) async {
    return _fileIOService.readKeyFile(filePath);
  }

  Future<void> saveKeyFile({
    required KeyFile keyFile,
    required String targetPath,
  }) async {
    final content = jsonEncode(keyFile.toJson());
    await _fileIOService.writeKeyFile(content: content, targetPath: targetPath);
  }
}
