/// 暗号保险库常量定义
///
/// 集中管理暗号保险库模块的所有配置常量，
/// 确保各处引用一致，便于统一调整。
///
/// 设计特点：
/// - 私有构造函数，防止实例化（纯常量类）
/// - 所有字段为 static const，编译期常量
///
/// 架构位置：核心服务层 - 暗号保险库模块
class PassphraseVaultConstants {
  PassphraseVaultConstants._();

  /// flutter_secure_storage 存储键名
  ///
  /// 用于在 flutter_secure_storage 中存储暗号保险库数据的键名。
  /// 存储的数据格式为 JSON，包含版本号和条目列表。
  ///
  /// 存储数据格式：
  /// ```json
  /// {
  ///   "version": 1,
  ///   "entries": [...]
  /// }
  /// ```
  static const String vaultStorageKey = 'strawhut_passphrase_vault';

  /// 存储数据格式版本
  ///
  /// 用于未来数据格式迁移时的版本识别。
  /// 当存储格式发生不兼容变更时，递增此版本号，
  /// 并在读取时进行版本检查和数据迁移。
  static const int vaultVersion = 1;

  /// 最大暗号保存数量
  ///
  /// 限制保险库中最多保存的暗号条目数量。
  /// 此限制基于以下考虑：
  /// - 避免用户保存过多暗号导致管理困难
  /// - flutter_secure_storage 存储空间有限
  static const int maxPassphraseEntries = 10;

  /// 备注名称最大长度
  ///
  /// 限制暗号备注名称的最大字符数，防止过长的标签影响 UI 展示。
  static const int passphraseLabelMaxLength = 50;
}
