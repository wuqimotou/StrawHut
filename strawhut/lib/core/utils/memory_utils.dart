import 'dart:typed_data';

/// 内存管理工具类
///
/// 提供安全清除敏感数据的方法，降低内存泄露风险。
///
/// 架构位置：核心工具层（Core Utils Layer）
///
/// 安全背景：
/// - Dart 的垃圾回收（GC）机制不可控，无法强制立即回收对象
/// - 敏感数据（如密钥字节）可能在内存中残留较长时间
/// - 通过逐字节置零，即使对象未被 GC 回收，也无法读取原始数据
///
/// 设计特点：
/// - 私有构造函数，防止实例化（纯工具类）
/// - 静态方法，无需创建实例即可调用
///
/// 使用场景：
/// - 加密/解密操作完成后清除密钥字节
/// - 发布流程完成后清除明文内容
/// - CryptoService.clearSensitiveData() 内部调用
///
/// 使用示例：
/// ```dart
/// // 清除密钥字节
/// MemoryUtils.wipeBytes(keyBytes);
/// // 安全清除 Map 中的敏感数据
/// MemoryUtils.secureClearMap(sensitiveDataMap);
/// ```
class MemoryUtils {
  /// 私有构造函数，防止实例化
  MemoryUtils._();

  /// 将字节数组逐字节置零，用于清除敏感数据
  ///
  /// 将传入的 Uint8List 中的每个字节都设置为 0，
  /// 确保即使内存未被 GC 回收，也无法读取原始敏感数据。
  ///
  /// 参数：[bytes] - 要清除的字节数组
  /// 性能：O(n)，n 为字节数组长度
  static void wipeBytes(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  /// 安全清除 Map 中的所有值
  ///
  /// 遍历 Map 中的所有键值对：
  /// - 如果值为 Uint8List，调用 wipeBytes 逐字节置零
  /// - 如果值为 List<int>，逐元素置零
  /// - 所有值最终设置为 null
  ///
  /// 参数：[map] - 要安全清除的 Map
  /// 性能：O(n)，n 为 Map 中的元素数量
  static void secureClearMap(Map<String, dynamic> map) {
    final keysToRemove = map.keys.toList();
    for (final key in keysToRemove) {
      final value = map[key];
      if (value is Uint8List) {
        wipeBytes(value);
      } else if (value is List<int>) {
        for (var i = 0; i < value.length; i++) {
          value[i] = 0;
        }
      }
      map[key] = null;
    }
  }
}
