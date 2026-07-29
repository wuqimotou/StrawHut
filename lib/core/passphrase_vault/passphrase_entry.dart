import 'package:flutter/foundation.dart';

/// 暗号保险库条目模型
///
/// 表示暗号保险库中保存的一条暗号记录。
/// 每条记录包含暗号内容、备注名称、创建时间及使用统计信息。
///
/// 设计特点：
/// - 不可变对象（所有字段为 final），确保条目不被意外修改
/// - 使用 [id] 作为唯一标识，用于相等性判断
/// - 提供 [copyWithUsage] 方法，用于更新使用统计时创建新实例
/// - 提供 JSON 序列化/反序列化方法，便于持久化存储
///
/// ID 格式：`pv_{毫秒时间戳}_{4位随机十六进制}`
/// 例如：`pv_1700000000000_a1b2`
///
/// 时间格式：ISO 8601 UTC，例如 `2024-01-15T08:30:00.000Z`
@immutable
class PassphraseEntry {
  /// 创建暗号保险库条目实例
  ///
  /// 参数说明：
  /// - [id]: 唯一标识，格式：`pv_{毫秒时间戳}_{4位随机十六进制}`
  /// - [passphrase]: 暗号内容
  /// - [label]: 备注名称
  /// - [createdAt]: 创建时间（ISO 8601 UTC 格式）
  /// - [useCount]: 使用次数，默认为 0
  /// - [lastUsedAt]: 最近使用时间（ISO 8601 UTC 格式，可选）
  const PassphraseEntry({
    required this.id,
    required this.passphrase,
    required this.label,
    required this.createdAt,
    this.useCount = 0,
    this.lastUsedAt,
  });

  /// 从 JSON 映射反序列化为 [PassphraseEntry]
  ///
  /// 用于从 flutter_secure_storage 中读取存储的暗号条目数据。
  ///
  /// 输入格式：
  /// ```json
  /// {
  ///   "id": "pv_1700000000000_a1b2",
  ///   "passphrase": "MySecretPass",
  ///   "label": "暗号 #1",
  ///   "created_at": "2024-01-15T08:30:00.000Z",
  ///   "use_count": 3,
  ///   "last_used_at": "2024-01-20T10:00:00.000Z"
  /// }
  /// ```
  ///
  /// 参数：
  /// - [json]: 包含暗号条目字段的 JSON Map
  ///
  /// 返回：
  /// - 解析后的 [PassphraseEntry] 实例
  factory PassphraseEntry.fromJson(Map<String, dynamic> json) {
    return PassphraseEntry(
      id: json['id'] as String,
      passphrase: json['passphrase'] as String,
      label: json['label'] as String,
      createdAt: json['created_at'] as String,
      useCount: json['use_count'] as int? ?? 0,
      lastUsedAt: json['last_used_at'] as String?,
    );
  }

  /// 唯一标识，格式：`pv_{毫秒时间戳}_{4位随机十六进制}`
  ///
  /// 示例：`pv_1700000000000_a1b2`
  ///
  /// 此 ID 在保存时生成，保证全局唯一性：
  /// - 毫秒时间戳提供时间维度唯一性
  /// - 4位随机十六进制提供同毫秒内的碰撞避免
  final String id;

  /// 暗号内容
  ///
  /// 用户输入的暗号字符串，用于协商密钥加密模式下的密钥派生。
  /// 此字段为敏感数据，应避免在日志或 UI 中直接展示。
  final String passphrase;

  /// 备注名称
  ///
  /// 用户为暗号设置的易识别名称，如 "暗号 #1" 或自定义名称。
  /// 最大长度由 `PassphraseVaultConstants.passphraseLabelMaxLength` 限制。
  final String label;

  /// 创建时间（ISO 8601 UTC 格式）
  ///
  /// 条目创建时的时间戳，格式如 `2024-01-15T08:30:00.000Z`。
  /// 用于条目排序和展示。
  final String createdAt;

  /// 使用次数
  ///
  /// 记录该暗号成功解密的次数。
  /// 用于 `tryAutoDecrypt` 中的智能排序，使用次数多的暗号优先尝试。
  final int useCount;

  /// 最近使用时间（ISO 8601 UTC 格式，可选）
  ///
  /// 最近一次成功解密的时间戳。
  /// 用于 `tryAutoDecrypt` 中的智能排序，最近使用的暗号优先尝试。
  /// 在首次使用前为 null。
  final String? lastUsedAt;

  /// 创建用于更新使用统计的副本
  ///
  /// 在暗号成功解密后调用此方法，创建一个更新了使用次数和最近使用时间的新实例。
  /// 由于 [PassphraseEntry] 是不可变对象，通过创建新实例来更新状态。
  ///
  /// 参数说明：
  /// - [newUseCount]: 新的使用次数（通常为 useCount + 1）
  /// - [newLastUsedAt]: 新的最近使用时间（ISO 8601 UTC 格式）
  ///
  /// 返回：
  /// - 包含更新后使用统计的新 [PassphraseEntry] 实例
  PassphraseEntry copyWithUsage({
    required int newUseCount,
    required String newLastUsedAt,
  }) {
    return PassphraseEntry(
      id: id,
      passphrase: passphrase,
      label: label,
      createdAt: createdAt,
      useCount: newUseCount,
      lastUsedAt: newLastUsedAt,
    );
  }

  /// 将暗号条目序列化为 JSON 映射
  ///
  /// 返回的 Map 可直接嵌入保险库的 entries 数组中，
  /// 然后通过 JSON 编码存储到 flutter_secure_storage。
  ///
  /// 输出格式：
  /// ```json
  /// {
  ///   "id": "pv_1700000000000_a1b2",
  ///   "passphrase": "MySecretPass",
  ///   "label": "暗号 #1",
  ///   "created_at": "2024-01-15T08:30:00.000Z",
  ///   "use_count": 3,
  ///   "last_used_at": "2024-01-20T10:00:00.000Z"
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
        'id': id,
        'passphrase': passphrase,
        'label': label,
        'created_at': createdAt,
        'use_count': useCount,
        'last_used_at': lastUsedAt,
      };

  /// 相等性判断
  ///
  /// 仅通过 [id] 判断两个 [PassphraseEntry] 是否相等，
  /// 因为 ID 保证全局唯一。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassphraseEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// 哈希值
  ///
  /// 与 [operator ==] 一致，仅基于 [id] 生成哈希值。
  @override
  int get hashCode => id.hashCode;
}
