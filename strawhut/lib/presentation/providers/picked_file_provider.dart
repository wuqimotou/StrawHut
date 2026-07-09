import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'picked_file_provider.g.dart';

/// 内容来源模式
enum ContentSourceMode {
  /// 编辑器内容（富文本模式）
  editor,

  /// 上传文件（文件加密模式）
  fileUpload,
}

/// 已选文件信息
class PickedFileInfo {
  const PickedFileInfo({
    required this.fileName,
    this.fileBytes,
    required this.fileSize,
    required this.extension,
    this.filePath,
  });

  final String fileName;

  /// 文件字节（小文件时使用）
  /// 大文件时为 null，应使用 [filePath] 配合流式加密
  final Uint8List? fileBytes;

  final int fileSize;
  final String extension;

  /// 文件路径（大文件时使用流式加密）
  /// 安卓端可能为 content:// URI，需要平台处理
  final String? filePath;

  /// 是否应使用流式加密
  bool get useStreamEncryption => filePath != null && fileBytes == null;
}

@riverpod
class PickedFile extends _$PickedFile {
  @override
  PickedFileInfo? build() => null;

  void setFile(PickedFileInfo? info) {
    state = info;
  }

  void clear() {
    state = null;
  }
}
