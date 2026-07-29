import 'package:strawhut/core/errors/format_exception.dart';

/// 日期工具类
class DateUtils {
  DateUtils._();

  /// 将当前 UTC 时间格式化为 ISO 8601 字符串
  /// 格式示例: 2026-05-02T12:30:45.123Z
  static String formatToISO8601() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// 解析 ISO 8601 格式的日期字符串为 DateTime 对象
  ///
  /// 参数：
  /// - [isoString]: ISO 8601 格式的日期字符串，不能为 null 或空
  ///
  /// 返回值：解析后的 DateTime 对象
  ///
  /// 异常：
  /// - [StrawFormatException] 当输入格式无效或为空时抛出
  static DateTime parseISO8601(String isoString) {
    if (isoString.isEmpty) {
      throw const StrawFormatException(
        '日期字符串不能为空',
        code: 'EMPTY_DATE_STRING',
      );
    }

    try {
      return DateTime.parse(isoString);
    } on FormatException {
      throw StrawFormatException(
        '无效的日期格式: "$isoString"，应为 ISO 8601 格式（如 2026-05-02T12:30:45.123Z）',
        code: 'INVALID_DATE_FORMAT',
      );
    }
  }
}
