import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:strawhut/core/crypto/crypto_models/passphrase_strength.dart';
import 'package:strawhut/core/crypto/passphrase_strength_service.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_constants.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';

/// 暗号保险库服务接口
///
/// 定义暗号保险库的核心操作契约，提供暗号的增删查功能。
///
/// 设计原则：
/// - 接口与实现分离，便于测试和替换实现
/// - 所有操作均为异步，适配 flutter_secure_storage 的异步 API
///
/// 架构位置：核心服务层 - 暗号保险库模块
/// 被依赖方：应用层通过 Riverpod Provider 调用
abstract class IPassphraseVaultService {
  /// 获取所有暗号条目
  ///
  /// 返回保险库中所有暗号条目，按创建时间降序排列（最新创建的排在前面）。
  ///
  /// 返回值：暗号条目列表，如果保险库为空则返回空列表
  ///
  /// 异常：
  /// - [PassphraseVaultException]：存储读取失败时抛出，错误代码 `STORAGE_ERROR`
  Future<List<PassphraseEntry>> getAllEntries();

  /// 保存暗号
  ///
  /// 将用户输入的暗号保存到保险库中，自动生成唯一 ID 和时间戳。
  ///
  /// 参数说明：
  /// - [passphrase]: 用户输入的暗号字符串
  /// - [label]: 可选的备注名称，如果为空则自动生成 "暗号 #N"
  ///
  /// 返回值：保存成功的 [PassphraseEntry] 实例
  ///
  /// 保存规则（按检查顺序）：
  /// 1. 检查暗号强度，veryWeak 不允许保存
  /// 2. 检查暗号是否已存在，不允许重复
  /// 3. 检查保险库是否已满（最多 10 条）
  /// 4. 生成唯一 ID 并保存
  ///
  /// 异常：
  /// - [PassphraseVaultException]：错误代码 `INVALID_PASSPHRASE`（强度不足）
  /// - [PassphraseVaultException]：错误代码 `DUPLICATE_PASSPHRASE`（暗号重复）
  /// - [PassphraseVaultException]：错误代码 `VAULT_FULL`（保险库已满）
  /// - [PassphraseVaultException]：错误代码 `STORAGE_ERROR`（存储写入失败）
  Future<PassphraseEntry> savePassphrase({
    required String passphrase,
    String? label,
  });

  /// 删除暗号
  ///
  /// 根据条目 ID 从保险库中删除指定的暗号。
  ///
  /// 参数说明：
  /// - [id]: 要删除的暗号条目 ID
  ///
  /// 异常：
  /// - [PassphraseVaultException]：错误代码 `NOT_FOUND`（条目不存在）
  /// - [PassphraseVaultException]：错误代码 `STORAGE_ERROR`（存储写入失败）
  Future<void> deletePassphrase(String id);

  /// 清空所有暗号
  ///
  /// 删除保险库中的所有暗号条目。
  ///
  /// 异常：
  /// - [PassphraseVaultException]：错误代码 `STORAGE_ERROR`（存储操作失败）
  Future<void> clearAll();

  /// 检查暗号是否已存在
  ///
  /// 判断保险库中是否已存在指定的暗号内容（精确匹配）。
  ///
  /// 参数说明：
  /// - [passphrase]: 要检查的暗号字符串
  ///
  /// 返回值：如果暗号已存在返回 true，否则返回 false
  Future<bool> containsPassphrase(String passphrase);

  /// 获取暗号条目数量
  ///
  /// 返回保险库中当前保存的暗号条目数量。
  ///
  /// 返回值：暗号条目数量
  Future<int> getEntryCount();

  /// Records a successful explicit use of a saved passphrase.
  Future<void> markUsed(String entryId);
}

/// 暗号保险库服务实现
///
/// 实现 [IPassphraseVaultService] 接口，提供完整的暗号保险库功能。
///
/// 依赖的第三方库：
/// - `flutter_secure_storage`：提供加密安全的本地存储
///
/// 存储格式：
/// ```json
/// {
///   "version": 1,
///   "entries": [
///     {
///       "id": "pv_1700000000000_a1b2",
///       "passphrase": "MySecretPass",
///       "label": "暗号 #1",
///       "created_at": "2024-01-15T08:30:00.000Z",
///       "use_count": 0,
///       "last_used_at": null
///     }
///   ]
/// }
/// ```
///
/// 并发控制：
/// - 使用基于 Completer 的互斥锁，防止并发读写导致数据不一致
/// - 所有读写操作通过 [_withLock] 方法获取锁后执行
///
/// 使用示例：
/// ```dart
/// final vaultService = PassphraseVaultService();
/// final entry = await vaultService.savePassphrase(
///   passphrase: 'MyP@ssw0rd2024!',
///   label: '工作暗号',
/// );
/// ```
class PassphraseVaultService implements IPassphraseVaultService {
  /// 创建暗号保险库服务实例
  ///
  /// 参数说明：
  /// - [secureStorage]: 可选的 FlutterSecureStorage 实例，
  ///   不提供时使用默认配置创建。注入自定义实例便于单元测试。
  PassphraseVaultService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// flutter_secure_storage 实例
  final FlutterSecureStorage _secureStorage;

  /// 互斥锁，防止并发读写
  ///
  /// 使用 Completer 实现简单的互斥锁机制：
  /// - 当锁未被持有时，_lock 为 null
  /// - 当锁被持有时，_lock 为一个未完成的 Completer
  /// - 其他操作通过 await _lock!.future 等待锁释放
  Completer<void>? _lock;

  /// 获取所有暗号条目
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 从 flutter_secure_storage 读取保险库数据
  /// 3. 解析 JSON，提取 entries 数组
  /// 4. 按 createdAt 降序排列（最新创建的排在前面）
  /// 5. 释放互斥锁
  @override
  Future<List<PassphraseEntry>> getAllEntries() async {
    return _withLock(() async {
      final vaultData = await _readVaultData();
      final entries = vaultData['entries'] as List<dynamic>? ?? [];

      final passphraseEntries =
          entries
              .map((e) => PassphraseEntry.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return passphraseEntries;
    });
  }

  /// 保存暗号
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 检查暗号强度，veryWeak 不允许保存
  /// 3. 检查暗号是否已存在
  /// 4. 检查保险库是否已满
  /// 5. 生成唯一 ID：`pv_{毫秒时间戳}_{4位随机十六进制}`
  /// 6. 如果 label 为空，自动生成 "暗号 #N"
  /// 7. 创建条目并保存到 flutter_secure_storage
  /// 8. 释放互斥锁
  @override
  Future<PassphraseEntry> savePassphrase({
    required String passphrase,
    String? label,
  }) async {
    return _withLock(() async {
      // 1. 检查暗号强度
      final strength = PassphraseStrengthService.evaluate(passphrase);
      if (strength == PassphraseStrength.veryWeak) {
        throw const PassphraseVaultException(
          '暗号强度不足，请使用至少 8 个字符且不包含连续重复或递增序列的暗号',
          code: 'INVALID_PASSPHRASE',
        );
      }

      // 2. 检查暗号是否已存在
      final vaultData = await _readVaultData();
      final entries = (vaultData['entries'] as List<dynamic>? ?? [])
          .map((e) => PassphraseEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final isDuplicate = entries.any(
        (entry) => entry.passphrase == passphrase,
      );
      if (isDuplicate) {
        throw const PassphraseVaultException(
          '该暗号已存在于保险库中',
          code: 'DUPLICATE_PASSPHRASE',
        );
      }

      // 3. 检查保险库是否已满
      if (entries.length >= PassphraseVaultConstants.maxPassphraseEntries) {
        throw const PassphraseVaultException(
          '保险库已满，最多保存 ${PassphraseVaultConstants.maxPassphraseEntries} 条暗号',
          code: 'VAULT_FULL',
        );
      }

      // 4. 生成唯一 ID
      final id = _generateEntryId();

      // 5. 处理 label
      final effectiveLabel = (label == null || label.trim().isEmpty)
          ? _generateAutoLabel(entries)
          : label.trim();

      // 6. 创建条目
      final now = DateTime.now().toUtc();
      final entry = PassphraseEntry(
        id: id,
        passphrase: passphrase,
        label: effectiveLabel,
        createdAt: now.toIso8601String(),
      );

      // 7. 保存到存储
      entries.add(entry);
      await _writeVaultData(entries);

      return entry;
    });
  }

  /// 删除暗号
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 读取保险库数据
  /// 3. 查找指定 ID 的条目，不存在则抛出异常
  /// 4. 从列表中移除条目
  /// 5. 保存更新后的数据到 flutter_secure_storage
  /// 6. 释放互斥锁
  @override
  Future<void> deletePassphrase(String id) async {
    return _withLock(() async {
      final vaultData = await _readVaultData();
      final entries = (vaultData['entries'] as List<dynamic>? ?? [])
          .map((e) => PassphraseEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final index = entries.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        throw const PassphraseVaultException('指定的暗号条目不存在', code: 'NOT_FOUND');
      }

      entries.removeAt(index);
      await _writeVaultData(entries);
    });
  }

  /// 清空所有暗号
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 删除 flutter_secure_storage 中的保险库数据
  /// 3. 释放互斥锁
  @override
  Future<void> clearAll() async {
    return _withLock(() async {
      await _secureStorage.delete(
        key: PassphraseVaultConstants.vaultStorageKey,
      );
    });
  }

  /// 检查暗号是否已存在
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 读取保险库数据
  /// 3. 遍历条目，精确匹配暗号内容
  /// 4. 释放互斥锁
  @override
  Future<bool> containsPassphrase(String passphrase) async {
    return _withLock(() async {
      final vaultData = await _readVaultData();
      final entries = (vaultData['entries'] as List<dynamic>? ?? [])
          .map((e) => PassphraseEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      return entries.any((entry) => entry.passphrase == passphrase);
    });
  }

  @override
  Future<void> markUsed(String entryId) async {
    return _withLock(() async {
      final vaultData = await _readVaultData();
      final entries = (vaultData['entries'] as List<dynamic>? ?? [])
          .map((e) => PassphraseEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      await _updateEntryUsage(entryId, entries);
    });
  }

  /// 获取暗号条目数量
  ///
  /// 实现步骤：
  /// 1. 获取互斥锁
  /// 2. 读取保险库数据
  /// 3. 返回条目数量
  /// 4. 释放互斥锁
  @override
  Future<int> getEntryCount() async {
    return _withLock(() async {
      final vaultData = await _readVaultData();
      final entries = vaultData['entries'] as List<dynamic>? ?? [];
      return entries.length;
    });
  }

  /// 更新条目使用统计
  ///
  /// 在暗号成功解密后，更新对应条目的 useCount（+1）和 lastUsedAt。
  ///
  /// 参数说明：
  /// - [entryId]: 成功解密的暗号条目 ID
  /// - [entries]: 当前的条目列表
  Future<void> _updateEntryUsage(
    String entryId,
    List<PassphraseEntry> entries,
  ) async {
    final index = entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final entry = entries[index];
    final now = DateTime.now().toUtc().toIso8601String();
    entries[index] = entry.copyWithUsage(
      newUseCount: entry.useCount + 1,
      newLastUsedAt: now,
    );

    await _writeVaultData(entries);
  }

  /// 生成唯一条目 ID
  ///
  /// 格式：`pv_{毫秒时间戳}_{4位随机十六进制}`
  /// 例如：`pv_1700000000000_a1b2`
  ///
  /// 毫秒时间戳提供时间维度唯一性，
  /// 4位随机十六进制提供同毫秒内的碰撞避免。
  String _generateEntryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final hexDigits = List.generate(
      4,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return 'pv_${timestamp}_$hexDigits';
  }

  /// 自动生成备注名称
  ///
  /// 格式："暗号 #N"，其中 N 为下一个序号。
  /// 序号基于当前已有条目数量 + 1。
  ///
  /// 参数说明：
  /// - [existingEntries]: 当前已有的条目列表
  String _generateAutoLabel(List<PassphraseEntry> existingEntries) {
    final nextNumber = existingEntries.length + 1;
    return '暗号 #$nextNumber';
  }

  /// 从 flutter_secure_storage 读取保险库数据
  ///
  /// 读取并解析存储的 JSON 数据。如果存储为空或格式错误，
  /// 返回默认的空保险库结构。
  ///
  /// 返回值：包含 version 和 entries 的 Map
  Future<Map<String, dynamic>> _readVaultData() async {
    try {
      final jsonString = await _secureStorage.read(
        key: PassphraseVaultConstants.vaultStorageKey,
      );

      if (jsonString == null) {
        return _emptyVaultData();
      }

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      // 版本检查：如果版本不匹配，未来可在此处进行数据迁移
      final version = decoded['version'] as int? ?? 1;
      if (version != PassphraseVaultConstants.vaultVersion) {
        // 当前仅支持版本 1，未来版本可在此处添加迁移逻辑
      }

      return decoded;
    } catch (e) {
      throw PassphraseVaultException('读取保险库数据失败：$e', code: 'STORAGE_ERROR');
    }
  }

  /// 将保险库数据写入 flutter_secure_storage
  ///
  /// 将条目列表序列化为 JSON 并存储到 flutter_secure_storage。
  ///
  /// 参数说明：
  /// - [entries]: 要保存的暗号条目列表
  Future<void> _writeVaultData(List<PassphraseEntry> entries) async {
    try {
      final vaultData = {
        'version': PassphraseVaultConstants.vaultVersion,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

      final jsonString = jsonEncode(vaultData);
      await _secureStorage.write(
        key: PassphraseVaultConstants.vaultStorageKey,
        value: jsonString,
      );
    } catch (e) {
      throw PassphraseVaultException('写入保险库数据失败：$e', code: 'STORAGE_ERROR');
    }
  }

  /// 返回空的保险库数据结构
  ///
  /// 当存储中无数据时，返回此默认结构。
  Map<String, dynamic> _emptyVaultData() => {
    'version': PassphraseVaultConstants.vaultVersion,
    'entries': <Map<String, dynamic>>[],
  };

  /// 使用互斥锁执行操作
  ///
  /// 确保同一时间只有一个读写操作在执行，防止并发访问导致数据不一致。
  ///
  /// 实现原理：
  /// - 当 [_lock] 为 null 时，表示锁未被持有，直接执行操作
  /// - 当 [_lock] 不为 null 时，等待其完成后执行操作
  /// - 操作完成后清除 [_lock]，释放锁
  ///
  /// 参数说明：
  /// - [action]: 需要在锁保护下执行的异步操作
  ///
  /// 返回值：操作的返回值
  Future<T> _withLock<T>(Future<T> Function() action) async {
    // 等待当前锁释放
    while (_lock != null) {
      try {
        await _lock!.future;
      } on Object catch (_) {
        // 忽略前一个操作抛出的异常，只需等待锁释放
      }
    }

    // 获取锁
    final completer = Completer<void>();
    _lock = completer;

    try {
      final result = await action();
      return result;
    } finally {
      // 释放锁
      _lock = null;
      completer.complete();
    }
  }
}
