/// 内存管理工具类
class MemoryUtils {
  MemoryUtils._();

  static void secureClear(List<int> buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}
