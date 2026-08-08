import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';

void main() {
  group('PassphraseEntry 构造函数', () {
    test('应正确创建包含所有字段的实例', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '测试暗号',
        createdAt: '2024-01-15T08:30:00.000Z',
        useCount: 5,
        lastUsedAt: '2024-01-20T10:00:00.000Z',
      );

      expect(entry.id, 'pv_1700000000000_a1b2');
      expect(entry.passphrase, 'MySecretPass');
      expect(entry.label, '测试暗号');
      expect(entry.createdAt, '2024-01-15T08:30:00.000Z');
      expect(entry.useCount, 5);
      expect(entry.lastUsedAt, '2024-01-20T10:00:00.000Z');
    });

    test('应使用默认值创建实例（useCount=0, lastUsedAt=null）', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      expect(entry.useCount, 0);
      expect(entry.lastUsedAt, isNull);
    });
  });

  group('PassphraseEntry.fromJson', () {
    test('应正确反序列化包含所有字段的 JSON', () {
      final json = {
        'id': 'pv_1700000000000_a1b2',
        'passphrase': 'MySecretPass',
        'label': '暗号 #1',
        'created_at': '2024-01-15T08:30:00.000Z',
        'use_count': 3,
        'last_used_at': '2024-01-20T10:00:00.000Z',
      };

      final entry = PassphraseEntry.fromJson(json);

      expect(entry.id, 'pv_1700000000000_a1b2');
      expect(entry.passphrase, 'MySecretPass');
      expect(entry.label, '暗号 #1');
      expect(entry.createdAt, '2024-01-15T08:30:00.000Z');
      expect(entry.useCount, 3);
      expect(entry.lastUsedAt, '2024-01-20T10:00:00.000Z');
    });

    test('应正确反序列化缺少可选字段的 JSON', () {
      final json = {
        'id': 'pv_1700000000000_a1b2',
        'passphrase': 'MySecretPass',
        'label': '暗号 #1',
        'created_at': '2024-01-15T08:30:00.000Z',
      };

      final entry = PassphraseEntry.fromJson(json);

      expect(entry.useCount, 0);
      expect(entry.lastUsedAt, isNull);
    });
  });

  group('PassphraseEntry.toJson', () {
    test('应正确序列化为包含所有键的 JSON', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
        useCount: 3,
        lastUsedAt: '2024-01-20T10:00:00.000Z',
      );

      final json = entry.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('passphrase'), isTrue);
      expect(json.containsKey('label'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
      expect(json.containsKey('use_count'), isTrue);
      expect(json.containsKey('last_used_at'), isTrue);

      expect(json['id'], 'pv_1700000000000_a1b2');
      expect(json['passphrase'], 'MySecretPass');
      expect(json['label'], '暗号 #1');
      expect(json['created_at'], '2024-01-15T08:30:00.000Z');
      expect(json['use_count'], 3);
      expect(json['last_used_at'], '2024-01-20T10:00:00.000Z');
    });

    test('last_used_at 为 null 时应序列化为 null', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      final json = entry.toJson();

      expect(json['last_used_at'], isNull);
    });
  });

  group('PassphraseEntry 往返序列化', () {
    test('fromJson(toJson()) 应产生相等的条目', () {
      const original = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
        useCount: 3,
        lastUsedAt: '2024-01-20T10:00:00.000Z',
      );

      final json = original.toJson();
      final restored = PassphraseEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.passphrase, original.passphrase);
      expect(restored.label, original.label);
      expect(restored.createdAt, original.createdAt);
      expect(restored.useCount, original.useCount);
      expect(restored.lastUsedAt, original.lastUsedAt);
    });

    test('JSON 往返序列化应保持数据完整性', () {
      final json = {
        'id': 'pv_1700000000000_c3d4',
        'passphrase': 'AnotherPass',
        'label': '工作暗号',
        'created_at': '2024-06-01T12:00:00.000Z',
        'use_count': 0,
        'last_used_at': null,
      };

      final entry = PassphraseEntry.fromJson(json);
      final outputJson = entry.toJson();

      // 验证 JSON 字符串级别的往返一致性
      final inputStr = jsonEncode(json);
      final outputStr = jsonEncode(outputJson);
      expect(outputStr, inputStr);
    });
  });

  group('PassphraseEntry.copyWithUsage', () {
    test('应创建新实例并更新 useCount 和 lastUsedAt', () {
      const original = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      final updated = original.copyWithUsage(
        newUseCount: 1,
        newLastUsedAt: '2024-02-01T10:00:00.000Z',
      );

      // 新实例应更新 useCount 和 lastUsedAt
      expect(updated.useCount, 1);
      expect(updated.lastUsedAt, '2024-02-01T10:00:00.000Z');

      // 其他字段应保持不变
      expect(updated.id, original.id);
      expect(updated.passphrase, original.passphrase);
      expect(updated.label, original.label);
      expect(updated.createdAt, original.createdAt);
    });

    test('不应修改原始实例', () {
      const original = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      original.copyWithUsage(
        newUseCount: 5,
        newLastUsedAt: '2024-02-01T10:00:00.000Z',
      );

      // 原始实例应保持不变
      expect(original.useCount, 0);
      expect(original.lastUsedAt, isNull);
    });
  });

  group('PassphraseEntry 相等性', () {
    test('相同 id 的条目应相等', () {
      const entry1 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'Pass1',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );
      const entry2 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'Pass2',
        label: '暗号 #2',
        createdAt: '2024-02-15T08:30:00.000Z',
        useCount: 10,
        lastUsedAt: '2024-03-01T00:00:00.000Z',
      );

      expect(entry1 == entry2, isTrue);
    });

    test('不同 id 的条目应不相等', () {
      const entry1 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'SamePass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );
      const entry2 = PassphraseEntry(
        id: 'pv_1700000000000_c3d4',
        passphrase: 'SamePass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      expect(entry1 == entry2, isFalse);
    });

    test('同一实例应与自身相等', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      expect(entry == entry, isTrue);
    });

    test('与非 PassphraseEntry 对象比较应不相等', () {
      const entry = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      const Object nonEntry = 'not an entry';
      expect(entry == nonEntry, isFalse);
    });
  });

  group('PassphraseEntry hashCode', () {
    test('相同 id 的条目应有相同的 hashCode', () {
      const entry1 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'Pass1',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );
      const entry2 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'Pass2',
        label: '暗号 #2',
        createdAt: '2024-02-15T08:30:00.000Z',
      );

      expect(entry1.hashCode, entry2.hashCode);
    });

    test('不同 id 的条目通常应有不同的 hashCode', () {
      const entry1 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'SamePass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );
      const entry2 = PassphraseEntry(
        id: 'pv_1700000000000_c3d4',
        passphrase: 'SamePass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );

      // 不同 id 通常产生不同 hashCode（非严格保证，但实际中几乎总是成立）
      expect(entry1.hashCode, isNot(equals(entry2.hashCode)));
    });

    test('hashCode 应与相等性一致', () {
      const entry1 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'MySecretPass',
        label: '暗号 #1',
        createdAt: '2024-01-15T08:30:00.000Z',
      );
      const entry2 = PassphraseEntry(
        id: 'pv_1700000000000_a1b2',
        passphrase: 'DifferentPass',
        label: '暗号 #2',
        createdAt: '2024-06-01T00:00:00.000Z',
        useCount: 100,
        lastUsedAt: '2024-06-15T00:00:00.000Z',
      );

      // 相等的对象必须有相同的 hashCode
      expect(entry1 == entry2, isTrue);
      expect(entry1.hashCode, entry2.hashCode);
    });
  });
}
