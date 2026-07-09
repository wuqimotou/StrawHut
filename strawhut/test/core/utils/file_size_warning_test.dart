import 'package:flutter_test/flutter_test.dart';

/// 文件大小警告级别
///
/// 与 PublishDialog 中 _FileSizeWarningLevel 对应的测试枚举。
/// 因原始定义在私有作用域内，此处复制定义用于单元测试。
enum FileSizeWarningLevel {
  /// 提示（10-50MB）
  hint,

  /// 警告（50-200MB）
  warning,

  /// 强烈警告（200MB-1GB）
  strongWarning,

  /// 严重警告（>= 1GB）
  severe,
}

/// 文件大小警告信息
class FileSizeWarning {
  const FileSizeWarning({
    required this.level,
    required this.message,
  });

  final FileSizeWarningLevel level;
  final String message;
}

/// 文件大小警告判断逻辑
///
/// 从 PublishDialog._getFileSizeWarning 提取的纯函数，
/// 阈值规则：
/// - < 10MB: 无警告
/// - 10-50MB: 提示
/// - 50-200MB: 警告
/// - 200MB-1GB: 强烈警告
/// - >= 1GB: 严重警告
FileSizeWarning? getFileSizeWarning(int fileSizeBytes) {
  const mb = 1024 * 1024;
  if (fileSizeBytes < 10 * mb) return null;
  if (fileSizeBytes < 50 * mb) {
    return FileSizeWarning(
      level: FileSizeWarningLevel.hint,
      message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密可能需要较长时间',
    );
  }
  if (fileSizeBytes < 200 * mb) {
    return FileSizeWarning(
      level: FileSizeWarningLevel.warning,
      message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密耗时较长，请耐心等待',
    );
  }
  if (fileSizeBytes < 1024 * mb) {
    return FileSizeWarning(
      level: FileSizeWarningLevel.strongWarning,
      message: '文件非常大（${_formatFileSize(fileSizeBytes)}），加密/解密将非常耗时，建议使用流式加密',
    );
  }
  return FileSizeWarning(
    level: FileSizeWarningLevel.severe,
    message: '文件极大（${_formatFileSize(fileSizeBytes)}），可能占用大量内存和时间，是否继续？',
  );
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

void main() {
  group('getFileSizeWarning - 无警告区间', () {
    test('0 字节不应产生警告', () {
      expect(getFileSizeWarning(0), isNull);
    });

    test('1 字节不应产生警告', () {
      expect(getFileSizeWarning(1), isNull);
    });

    test('5MB 不应产生警告', () {
      const fiveMB = 5 * 1024 * 1024;
      expect(getFileSizeWarning(fiveMB), isNull);
    });

    test('9MB 不应产生警告', () {
      const nineMB = 9 * 1024 * 1024;
      expect(getFileSizeWarning(nineMB), isNull);
    });

    test('9.99MB 不应产生警告', () {
      final size = (9.99 * 1024 * 1024).toInt();
      expect(getFileSizeWarning(size), isNull);
    });
  });

  group('getFileSizeWarning - 提示区间（10-50MB）', () {
    test('10MB 应产生提示', () {
      const tenMB = 10 * 1024 * 1024;
      final warning = getFileSizeWarning(tenMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });

    test('20MB 应产生提示', () {
      const twentyMB = 20 * 1024 * 1024;
      final warning = getFileSizeWarning(twentyMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });

    test('49MB 应产生提示', () {
      const fortyNineMB = 49 * 1024 * 1024;
      final warning = getFileSizeWarning(fortyNineMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });

    test('49.99MB 应产生提示', () {
      final size = (49.99 * 1024 * 1024).toInt();
      final warning = getFileSizeWarning(size);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });
  });

  group('getFileSizeWarning - 警告区间（50-200MB）', () {
    test('50MB 应产生警告', () {
      const fiftyMB = 50 * 1024 * 1024;
      final warning = getFileSizeWarning(fiftyMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.warning);
    });

    test('100MB 应产生警告', () {
      const hundredMB = 100 * 1024 * 1024;
      final warning = getFileSizeWarning(hundredMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.warning);
    });

    test('199MB 应产生警告', () {
      const oneNineNineMB = 199 * 1024 * 1024;
      final warning = getFileSizeWarning(oneNineNineMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.warning);
    });
  });

  group('getFileSizeWarning - 强烈警告区间（200MB-1GB）', () {
    test('200MB 应产生强烈警告', () {
      const twoHundredMB = 200 * 1024 * 1024;
      final warning = getFileSizeWarning(twoHundredMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });

    test('500MB 应产生强烈警告', () {
      const fiveHundredMB = 500 * 1024 * 1024;
      final warning = getFileSizeWarning(fiveHundredMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });

    test('999MB 应产生强烈警告', () {
      const nineNineNineMB = 999 * 1024 * 1024;
      final warning = getFileSizeWarning(nineNineNineMB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });

    test('1023MB 应产生强烈警告', () {
      const size = 1023 * 1024 * 1024;
      final warning = getFileSizeWarning(size);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });
  });

  group('getFileSizeWarning - 严重警告区间（>= 1GB）', () {
    test('1GB 应产生严重警告', () {
      const oneGB = 1024 * 1024 * 1024;
      final warning = getFileSizeWarning(oneGB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.severe);
    });

    test('2GB 应产生严重警告', () {
      const twoGB = 2 * 1024 * 1024 * 1024;
      final warning = getFileSizeWarning(twoGB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.severe);
    });

    test('10GB 应产生严重警告', () {
      const tenGB = 10 * 1024 * 1024 * 1024;
      final warning = getFileSizeWarning(tenGB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.severe);
    });
  });

  group('getFileSizeWarning - 边界值', () {
    test('10MB - 1 字节不应产生警告', () {
      // 恰好小于 10MB 的边界
      const justBelow10MB = 10 * 1024 * 1024 - 1;
      expect(getFileSizeWarning(justBelow10MB), isNull);
    });

    test('10MB 恰好应产生提示', () {
      const exactly10MB = 10 * 1024 * 1024;
      final warning = getFileSizeWarning(exactly10MB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });

    test('50MB - 1 字节应产生提示', () {
      const justBelow50MB = 50 * 1024 * 1024 - 1;
      final warning = getFileSizeWarning(justBelow50MB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.hint);
    });

    test('50MB 恰好应产生警告', () {
      const exactly50MB = 50 * 1024 * 1024;
      final warning = getFileSizeWarning(exactly50MB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.warning);
    });

    test('200MB - 1 字节应产生警告', () {
      const justBelow200MB = 200 * 1024 * 1024 - 1;
      final warning = getFileSizeWarning(justBelow200MB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.warning);
    });

    test('200MB 恰好应产生强烈警告', () {
      const exactly200MB = 200 * 1024 * 1024;
      final warning = getFileSizeWarning(exactly200MB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });

    test('1GB - 1 字节应产生强烈警告', () {
      const justBelow1GB = 1024 * 1024 * 1024 - 1;
      final warning = getFileSizeWarning(justBelow1GB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.strongWarning);
    });

    test('1GB 恰好应产生严重警告', () {
      const exactly1GB = 1024 * 1024 * 1024;
      final warning = getFileSizeWarning(exactly1GB);
      expect(warning, isNotNull);
      expect(warning!.level, FileSizeWarningLevel.severe);
    });
  });

  group('getFileSizeWarning - 警告消息', () {
    test('提示消息应包含 "较长时间"', () {
      const tenMB = 10 * 1024 * 1024;
      final warning = getFileSizeWarning(tenMB);
      expect(warning, isNotNull);
      expect(warning!.message, contains('较长时间'));
    });

    test('警告消息应包含 "耗时较长"', () {
      const fiftyMB = 50 * 1024 * 1024;
      final warning = getFileSizeWarning(fiftyMB);
      expect(warning, isNotNull);
      expect(warning!.message, contains('耗时较长'));
    });

    test('强烈警告消息应包含 "流式加密"', () {
      const twoHundredMB = 200 * 1024 * 1024;
      final warning = getFileSizeWarning(twoHundredMB);
      expect(warning, isNotNull);
      expect(warning!.message, contains('流式加密'));
    });

    test('严重警告消息应包含 "是否继续"', () {
      const oneGB = 1024 * 1024 * 1024;
      final warning = getFileSizeWarning(oneGB);
      expect(warning, isNotNull);
      expect(warning!.message, contains('是否继续'));
    });
  });
}
