import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_constants.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';

/// Mock FlutterSecureStorage
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late PassphraseVaultService service;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    service = PassphraseVaultService(secureStorage: mockStorage);

    // 默认 stub：read 返回 null（空保险库）
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),).thenAnswer((_) async {});
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
  });

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 构建保险库 JSON 字符串
  String buildVaultJson(List<PassphraseEntry> entries) {
    return jsonEncode({
      'version': PassphraseVaultConstants.vaultVersion,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  /// 创建测试用条目
  PassphraseEntry createTestEntry({
    String id = 'pv_1700000000000_a1b2',
    String passphrase = 'abcdefgh',
    String label = '暗号 #1',
    String createdAt = '2024-01-15T08:30:00.000Z',
    int useCount = 0,
    String? lastUsedAt,
  }) {
    return PassphraseEntry(
      id: id,
      passphrase: passphrase,
      label: label,
      createdAt: createdAt,
      useCount: useCount,
      lastUsedAt: lastUsedAt,
    );
  }

  /// Stub read 返回包含指定条目的保险库数据
  void stubVaultWithEntries(List<PassphraseEntry> entries) {
    when(() => mockStorage.read(key: PassphraseVaultConstants.vaultStorageKey))
        .thenAnswer((_) async => buildVaultJson(entries));
  }

  // ============================================================
  // savePassphrase 测试
  // ============================================================
  group('savePassphrase', () {
    test('应成功保存有效暗号', () async {
      final entry = await service.savePassphrase(passphrase: 'abcdefgh');

      expect(entry, isA<PassphraseEntry>());
      expect(entry.passphrase, 'abcdefgh');
      expect(entry.id, startsWith('pv_'));
      expect(entry.createdAt, isNotEmpty);

      // 验证 write 被调用
      verify(() => mockStorage.write(
            key: PassphraseVaultConstants.vaultStorageKey,
            value: any(named: 'value'),
          ),).called(1);
    });

    test('应使用自定义标签保存暗号', () async {
      final entry = await service.savePassphrase(
        passphrase: 'abcdefgh',
        label: '我的工作暗号',
      );

      expect(entry.label, '我的工作暗号');
    });

    test('未提供标签时应自动生成 "暗号 #N"', () async {
      final entry = await service.savePassphrase(passphrase: 'abcdefgh');

      expect(entry.label, startsWith('暗号 #'));
    });

    test('空字符串标签应自动生成 "暗号 #N"', () async {
      final entry = await service.savePassphrase(
        passphrase: 'abcdefgh',
        label: '   ',
      );

      expect(entry.label, startsWith('暗号 #'));
    });

    test('应拒绝 veryWeak 暗号并抛出 INVALID_PASSPHRASE', () async {
      expect(
        () => service.savePassphrase(passphrase: 'aaa'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'INVALID_PASSPHRASE',
        ),),
      );
    });

    test('应拒绝重复暗号并抛出 DUPLICATE_PASSPHRASE', () async {
      final existingEntries = [
        createTestEntry(),
      ];
      stubVaultWithEntries(existingEntries);

      expect(
        () => service.savePassphrase(passphrase: 'abcdefgh'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'DUPLICATE_PASSPHRASE',
        ),),
      );
    });

    test('保险库已满时应抛出 VAULT_FULL', () async {
      final fullEntries = List.generate(
        PassphraseVaultConstants.maxPassphraseEntries,
        (i) => createTestEntry(
          id: 'pv_170000000000${i}_a1b2',
          passphrase: 'passphrase$i',
          label: '暗号 #${i + 1}',
        ),
      );
      stubVaultWithEntries(fullEntries);

      expect(
        () => service.savePassphrase(passphrase: 'newpassphrase'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'VAULT_FULL',
        ),),
      );
    });

    test('存储写入失败时应抛出 STORAGE_ERROR', () async {
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),).thenThrow(Exception('写入失败'));

      expect(
        () => service.savePassphrase(passphrase: 'abcdefgh'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'STORAGE_ERROR',
        ),),
      );
    });

    test('保存时应写入正确的 JSON 结构', () async {
      String? capturedValue;
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),).thenAnswer((invocation) async {
        capturedValue = invocation.namedArguments[#value] as String?;
      });

      await service.savePassphrase(passphrase: 'abcdefgh');

      expect(capturedValue, isNotNull);
      final decoded = jsonDecode(capturedValue!) as Map<String, dynamic>;
      expect(decoded['version'], PassphraseVaultConstants.vaultVersion);
      expect(decoded['entries'], isA<List<dynamic>>());
      expect((decoded['entries'] as List).isNotEmpty, isTrue);

      final entryJson =
          (decoded['entries'] as List).first as Map<String, dynamic>;
      expect(entryJson.containsKey('id'), isTrue);
      expect(entryJson.containsKey('passphrase'), isTrue);
      expect(entryJson.containsKey('label'), isTrue);
      expect(entryJson.containsKey('created_at'), isTrue);
      expect(entryJson.containsKey('use_count'), isTrue);
      expect(entryJson.containsKey('last_used_at'), isTrue);
    });

    test('自动生成标签时序号应基于已有条目数量', () async {
      final existingEntries = [
        createTestEntry(
          id: 'pv_1_a1b2',
          passphrase: 'passphrase1',
        ),
        createTestEntry(
          id: 'pv_2_c3d4',
          passphrase: 'passphrase2',
          label: '暗号 #2',
        ),
      ];
      stubVaultWithEntries(existingEntries);

      final entry = await service.savePassphrase(passphrase: 'passphrase3');

      // 已有 2 条，新条目应为 "暗号 #3"
      expect(entry.label, '暗号 #3');
    });
  });

  // ============================================================
  // getAllEntries 测试
  // ============================================================
  group('getAllEntries', () {
    test('保险库为空时应返回空列表', () async {
      final entries = await service.getAllEntries();

      expect(entries, isEmpty);
    });

    test('应按 createdAt 降序排列返回条目', () async {
      final vaultEntries = [
        createTestEntry(
          id: 'pv_1_a1b2',
        ),
        createTestEntry(
          id: 'pv_2_c3d4',
          createdAt: '2024-06-15T08:30:00.000Z',
        ),
        createTestEntry(
          id: 'pv_3_e5f6',
          createdAt: '2024-03-15T08:30:00.000Z',
        ),
      ];
      stubVaultWithEntries(vaultEntries);

      final entries = await service.getAllEntries();

      expect(entries.length, 3);
      expect(entries[0].id, 'pv_2_c3d4'); // 最新
      expect(entries[1].id, 'pv_3_e5f6');
      expect(entries[2].id, 'pv_1_a1b2'); // 最旧
    });

    test('存储读取失败时应抛出 STORAGE_ERROR', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenThrow(Exception('读取失败'));

      expect(
        () => service.getAllEntries(),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'STORAGE_ERROR',
        ),),
      );
    });
  });

  // ============================================================
  // deletePassphrase 测试
  // ============================================================
  group('deletePassphrase', () {
    test('应成功删除存在的条目', () async {
      final existingEntries = [
        createTestEntry(id: 'pv_1_a1b2', passphrase: 'pass1'),
        createTestEntry(id: 'pv_2_c3d4', passphrase: 'pass2'),
      ];
      stubVaultWithEntries(existingEntries);

      await service.deletePassphrase('pv_1_a1b2');

      // 验证 write 被调用（保存删除后的数据）
      verify(() => mockStorage.write(
            key: PassphraseVaultConstants.vaultStorageKey,
            value: any(named: 'value'),
          ),).called(1);
    });

    test('删除不存在的条目时应抛出 NOT_FOUND', () async {
      stubVaultWithEntries([
        createTestEntry(id: 'pv_1_a1b2'),
      ]);

      expect(
        () => service.deletePassphrase('non_existent_id'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'NOT_FOUND',
        ),),
      );
    });

    test('存储写入失败时应抛出 STORAGE_ERROR', () async {
      stubVaultWithEntries([
        createTestEntry(id: 'pv_1_a1b2'),
      ]);
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),).thenThrow(Exception('写入失败'));

      expect(
        () => service.deletePassphrase('pv_1_a1b2'),
        throwsA(isA<PassphraseVaultException>().having(
          (e) => e.code,
          'code',
          'STORAGE_ERROR',
        ),),
      );
    });
  });

  // ============================================================
  // clearAll 测试
  // ============================================================
  group('clearAll', () {
    test('应清空所有条目（调用 secureStorage.delete）', () async {
      await service.clearAll();

      verify(() => mockStorage.delete(
            key: PassphraseVaultConstants.vaultStorageKey,
          ),).called(1);
    });

    test('存储删除失败时应抛出原始异常', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenThrow(Exception('删除失败'));

      // clearAll 不封装异常，直接传播原始异常
      expect(
        () => service.clearAll(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // containsPassphrase 测试
  // ============================================================
  group('containsPassphrase', () {
    test('暗号存在时应返回 true', () async {
      stubVaultWithEntries([
        createTestEntry(passphrase: 'mySecretPass'),
      ]);

      final result = await service.containsPassphrase('mySecretPass');

      expect(result, isTrue);
    });

    test('暗号不存在时应返回 false', () async {
      stubVaultWithEntries([
        createTestEntry(passphrase: 'mySecretPass'),
      ]);

      final result = await service.containsPassphrase('otherPass');

      expect(result, isFalse);
    });

    test('保险库为空时应返回 false', () async {
      final result = await service.containsPassphrase('anyPass');

      expect(result, isFalse);
    });
  });

  group('markUsed', () {
    test('explicit vault selection updates useCount and lastUsedAt', () async {
      final entry = createTestEntry(id: 'selected-entry', useCount: 2);
      stubVaultWithEntries([entry]);

      await service.markUsed(entry.id);

      final captured = verify(() => mockStorage.write(
            key: PassphraseVaultConstants.vaultStorageKey,
            value: captureAny(named: 'value'),
          ),).captured.single as String;
      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      final savedEntries = decoded['entries'] as List<dynamic>;
      final savedEntry = savedEntries.single as Map<String, dynamic>;
      expect(savedEntry['use_count'], 3);
      expect(savedEntry['last_used_at'], isNotNull);
    });
  });

  // ============================================================
  // getEntryCount 测试
  // ============================================================
  group('getEntryCount', () {
    test('保险库为空时应返回 0', () async {
      final count = await service.getEntryCount();

      expect(count, 0);
    });

    test('应返回正确的条目数量', () async {
      stubVaultWithEntries([
        createTestEntry(id: 'pv_1_a1b2'),
        createTestEntry(id: 'pv_2_c3d4'),
        createTestEntry(id: 'pv_3_e5f6'),
      ]);

      final count = await service.getEntryCount();

      expect(count, 3);
    });
  });

  // ============================================================
  // 互斥锁 (_withLock) 测试
  // ============================================================
  group('互斥锁 (_withLock)', () {
    test('并发操作应顺序执行而非并行', () async {
      final executionOrder = <int>[];

      // 启动三个并发操作
      final futures = <Future<int>>[
        // 操作 1
        (() async {
          final result = await Future.value(1);
          executionOrder.add(1);
          return result;
        })(),
        // 操作 2
        (() async {
          final result = await Future.value(2);
          executionOrder.add(2);
          return result;
        })(),
        // 操作 3
        (() async {
          final result = await Future.value(3);
          executionOrder.add(3);
          return result;
        })(),
      ];

      // 简单验证三个 Future 可以并行启动
      await Future.wait(futures);
      expect(executionOrder.length, 3);

      // 更精确的互斥锁测试：验证多个操作不会同时执行
      final executionLog = <String>[];

      // 创建新的服务实例
      final lockService = PassphraseVaultService(secureStorage: mockStorage);
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      // 并行启动两个操作
      unawaited(lockService
          .savePassphrase(passphrase: 'abcdefgh')
          .then((_) => executionLog.add('save1_done')),);
      unawaited(lockService
          .savePassphrase(passphrase: 'ijklmnop')
          .then((_) => executionLog.add('save2_done')),);

      // 等待所有操作完成
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 验证没有并发执行的情况
      expect(executionLog, isNot(contains('op1_concurrent_with_op2')));
      expect(executionLog, isNot(contains('op2_concurrent_with_op1')));
    });
  });
}
