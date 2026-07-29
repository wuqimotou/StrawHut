import 'package:flutter/foundation.dart';

/// 文件格式版本模型
///
/// 表示 .straw 和 .key 文件的版本号，采用语义化版本控制（Semantic Versioning）：
/// - [major]: 主版本号，不兼容的格式变更
/// - [minor]: 次版本号，向后兼容的功能新增
/// - [patch]: 修订号，向后兼容的 Bug 修复
///
/// 兼容性规则：
/// - 主版本相同 → 兼容
/// - 主版本不同 → 不兼容
///
/// 使用示例：
/// ```dart
/// final version = FormatVersion(1, 0, 0);
/// print(version); // "1.0.0"
/// ```
@immutable
class FormatVersion {
  /// 创建版本实例
  ///
  /// 参数说明：
  /// - [major]: 主版本号，必填，不能为负数
  /// - [minor]: 次版本号，必填，不能为负数
  /// - [patch]: 修订号，必填，不能为负数
  const FormatVersion(this.major, this.minor, this.patch);

  /// 从版本字符串解析版本对象
  ///
  /// 将 "major.minor.patch" 格式的字符串解析为 [FormatVersion] 对象。
  ///
  /// 参数：[versionStr] - 版本号字符串，例如 "1.0.0"
  /// 返回：解析后的 FormatVersion 对象
  ///
  /// 异常：
  /// - [FormatException] 当格式无效、包含非数字或版本号为负数时抛出
  ///
  /// 注意事项：
  /// - 输入必须符合 "x.y.z" 格式
  /// - 各部分必须为有效的非负整数
  factory FormatVersion.fromString(String versionStr) {
    final parts = versionStr.split('.');

    if (parts.length != 3) {
      throw FormatException(
        '无效的版本格式: "$versionStr"。期望格式为 "major.minor.patch"，例如 "1.0.0"',
      );
    }

    int tryParse(String part, String name) {
      final parsed = int.tryParse(part);
      if (parsed == null) {
        throw FormatException(
          '无效的版本号: "$versionStr"。'
          '$name 必须为整数',
        );
      }
      if (parsed < 0) {
        throw FormatException(
          '无效的版本号: "$versionStr"。'
          '$name 不能为负数',
        );
      }
      return parsed;
    }

    return FormatVersion(
      tryParse(parts[0], 'major'),
      tryParse(parts[1], 'minor'),
      tryParse(parts[2], 'patch'),
    );
  }

  /// 从 JSON 创建版本对象
  ///
  /// JSON 中的版本号以字符串形式存储（如 `"1.0.0"`）。
  ///
  /// 参数：[json] - JSON 字符串值
  /// 返回：解析后的 FormatVersion 对象
  factory FormatVersion.fromJson(String json) {
    return FormatVersion.fromString(json);
  }

  /// 主版本号：不兼容的格式变更
  ///
  /// 当文件格式发生不向后兼容的变化时递增。
  /// 例如：删除必填字段、更改字段类型。
  /// 不同主版本之间的文件无法互相读取。
  final int major;

  /// 次版本号：向后兼容的功能新增
  ///
  /// 当添加新的可选字段或扩展功能时递增。
  /// 旧版本软件可以忽略新增字段正常读取文件。
  final int minor;

  /// 修订号：向后兼容的 Bug 修复
  ///
  /// 当修复文件格式定义中的错误或澄清规范时递增。
  final int patch;

  /// 判断两个版本对象是否相等
  ///
  /// 当 major、minor、patch 三个字段都相等时，两个版本对象相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormatVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  /// 计算版本对象的哈希值
  ///
  /// 基于 major、minor、patch 三个字段计算。
  @override
  int get hashCode => Object.hash(major, minor, patch);

  /// 返回版本号的字符串表示
  ///
  /// 格式："major.minor.patch"，例如 "1.0.0"
  @override
  String toString() => '$major.$minor.$patch';

  /// 检查版本兼容性
  ///
  /// 判断当前版本与另一版本是否兼容。
  /// 兼容性规则：主版本号相同即兼容。
  ///
  /// 参数：[other] - 要比较的另一版本
  /// 返回：true 表示兼容，false 表示不兼容
  bool isCompatibleWith(FormatVersion other) => major == other.major;
}
