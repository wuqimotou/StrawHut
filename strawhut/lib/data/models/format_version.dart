/// 文件格式版本模型
class FormatVersion {
  final int major;
  final int minor;
  final int patch;

  const FormatVersion(this.major, this.minor, this.patch);

  factory FormatVersion.fromString(String versionStr) {
    final parts = versionStr.split('.');
    return FormatVersion(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  bool isCompatibleWith(FormatVersion other) => major == other.major;

  @override
  String toString() => '$major.$minor.$patch';
}
