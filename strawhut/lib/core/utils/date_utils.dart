/// 日期工具类
class DateUtils {
  DateUtils._();

  static DateTime now() => DateTime.now();

  static String formatDateTime(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  static DateTime parseDateTime(String dateString) {
    return DateTime.parse(dateString);
  }
}
