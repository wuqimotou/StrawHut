import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/errors/strawhut_exception.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_exception.dart';

void main() {
  group('PassphraseVaultException 继承关系', () {
    test('应继承自 StrawHutException', () {
      const exception = PassphraseVaultException('测试异常');

      expect(exception, isA<StrawHutException>());
    });

    test('应实现 Exception', () {
      const exception = PassphraseVaultException('测试异常');

      expect(exception, isA<Exception>());
    });
  });

  group('PassphraseVaultException 构造函数', () {
    test('应仅使用消息创建实例', () {
      const exception = PassphraseVaultException('保险库操作失败');

      expect(exception.message, '保险库操作失败');
      expect(exception.code, isNull);
    });

    test('应使用消息和错误代码创建实例', () {
      const exception = PassphraseVaultException(
        '保险库已满',
        code: 'VAULT_FULL',
      );

      expect(exception.message, '保险库已满');
      expect(exception.code, 'VAULT_FULL');
    });
  });

  group('PassphraseVaultException.toString', () {
    test('带错误代码时应格式化为 "PassphraseVaultException(code): message"', () {
      const exception = PassphraseVaultException(
        '保险库已满',
        code: 'VAULT_FULL',
      );

      expect(
        exception.toString(),
        'PassphraseVaultException(VAULT_FULL): 保险库已满',
      );
    });

    test('无错误代码时应格式化为 "PassphraseVaultException(null): message"', () {
      const exception = PassphraseVaultException('未知错误');

      expect(
        exception.toString(),
        'PassphraseVaultException(null): 未知错误',
      );
    });
  });

  group('PassphraseVaultException 错误代码', () {
    test('VAULT_FULL - 保险库已满', () {
      const exception = PassphraseVaultException(
        '保险库已满，最多保存 10 条暗号',
        code: 'VAULT_FULL',
      );

      expect(exception.code, 'VAULT_FULL');
      expect(exception.message, contains('保险库已满'));
    });

    test('DUPLICATE_PASSPHRASE - 暗号重复', () {
      const exception = PassphraseVaultException(
        '该暗号已存在于保险库中',
        code: 'DUPLICATE_PASSPHRASE',
      );

      expect(exception.code, 'DUPLICATE_PASSPHRASE');
      expect(exception.message, contains('已存在'));
    });

    test('INVALID_PASSPHRASE - 暗号强度不足', () {
      const exception = PassphraseVaultException(
        '暗号强度不足，请使用至少 8 个字符且不包含连续重复或递增序列的暗号',
        code: 'INVALID_PASSPHRASE',
      );

      expect(exception.code, 'INVALID_PASSPHRASE');
      expect(exception.message, contains('强度不足'));
    });

    test('NOT_FOUND - 条目不存在', () {
      const exception = PassphraseVaultException(
        '指定的暗号条目不存在',
        code: 'NOT_FOUND',
      );

      expect(exception.code, 'NOT_FOUND');
      expect(exception.message, contains('不存在'));
    });

    test('STORAGE_ERROR - 存储错误', () {
      const exception = PassphraseVaultException(
        '读取保险库数据失败',
        code: 'STORAGE_ERROR',
      );

      expect(exception.code, 'STORAGE_ERROR');
      expect(exception.message, contains('失败'));
    });
  });

  group('PassphraseVaultException 异常捕获', () {
    test('应可作为 StrawHutException 捕获', () {
      const exception = PassphraseVaultException(
        '测试',
        code: 'VAULT_FULL',
      );

      try {
        throw exception;
      } on StrawHutException catch (e) {
        expect(e, isA<PassphraseVaultException>());
        expect(e.code, 'VAULT_FULL');
        expect(e.message, '测试');
      }
    });

    test('应可作为 Exception 捕获', () {
      const exception = PassphraseVaultException('测试');

      try {
        throw exception;
      } on Exception catch (e) {
        expect(e, isA<PassphraseVaultException>());
      }
    });
  });
}
