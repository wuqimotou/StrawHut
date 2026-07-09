import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 分块信息
///
/// 表示一个加密分块，包含独立的 IV 和加密后的数据。
@immutable
class ChunkInfo {
  const ChunkInfo({
    required this.iv,
    required this.encryptedData,
  });

  /// 分块 IV（16 字节）
  final Uint8List iv;

  /// 加密后的分块数据（含 GCM Tag）
  final Uint8List encryptedData;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkInfo &&
          _listEquals(iv, other.iv) &&
          _listEquals(encryptedData, other.encryptedData);

  @override
  int get hashCode => Object.hash(iv.length, encryptedData.length);

  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
