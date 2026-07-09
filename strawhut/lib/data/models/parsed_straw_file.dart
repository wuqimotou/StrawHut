import 'package:flutter/foundation.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 解析后的 .straw 文件
///
/// 包含 JSON Header 解析后的 StrawFile 和二进制分块数据。
@immutable
class ParsedStrawFile {
  const ParsedStrawFile({
    required this.strawFile,
    required this.chunks,
  });

  /// JSON Header 解析结果
  final StrawFile strawFile;

  /// 加密分块列表
  final List<ChunkInfo> chunks;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedStrawFile &&
          runtimeType == other.runtimeType &&
          strawFile == other.strawFile &&
          _listEquals(chunks, other.chunks);

  @override
  int get hashCode => Object.hash(strawFile, Object.hashAll(chunks));

  static bool _listEquals(List<ChunkInfo> a, List<ChunkInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
