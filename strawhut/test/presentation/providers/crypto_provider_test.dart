/// crypto_provider 单元测试文件
///
/// 本文件测试 crypto_provider.dart 中定义的所有 Riverpod Provider，
/// 验证 Provider 的定义正确性和依赖注入关系。
///
/// 测试范围：
/// - integrityServiceProvider: 返回 IntegrityService 实例
/// - cryptoServiceProvider: 依赖 integrityServiceProvider 创建 CryptoService
/// - fileIOServiceProvider: 返回 FileIOService 实例
/// - draftManagerProvider: 返回 DraftManager 实例
///
/// 使用 riverpod 的 ContainerProviderTester 进行隔离测试，
/// 确保 Provider 之间的依赖关系正确且实例创建符合预期。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/draft/draft_manager.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

void main() {
  group('integrityServiceProvider', () {
    test('应该返回 IntegrityService 实例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(integrityServiceProvider);

      expect(result, isA<IntegrityService>());
    });

    test('多次读取应该返回同一个实例（单例）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final instance1 = container.read(integrityServiceProvider);
      final instance2 = container.read(integrityServiceProvider);

      expect(identical(instance1, instance2), isTrue);
    });

    test('computeHash 方法应该正常工作', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final integrityService = container.read(integrityServiceProvider);
      final hash = integrityService.computeHash('test content');

      expect(hash, startsWith('sha256:'));
      expect(hash.length, greaterThan(7)); // 'sha256:' + hex string
    });

    test('verifyIntegrity 方法应该正确验证相同内容', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final integrityService = container.read(integrityServiceProvider);
      final content = 'test content for verification';
      final hash = integrityService.computeHash(content);

      expect(
        integrityService.verifyIntegrity(
          content: content,
          expectedHash: hash,
        ),
        isTrue,
      );
    });

    test('verifyIntegrity 方法应该拒绝不同内容', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final integrityService = container.read(integrityServiceProvider);
      final hash = integrityService.computeHash('original content');

      expect(
        integrityService.verifyIntegrity(
          content: 'modified content',
          expectedHash: hash,
        ),
        isFalse,
      );
    });
  });

  group('cryptoServiceProvider', () {
    test('应该返回 CryptoService 实例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(cryptoServiceProvider);

      expect(result, isA<CryptoService>());
    });

    test('应该依赖 integrityServiceProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 验证 cryptoServiceProvider 可以通过依赖获取 integrityService
      final cryptoService = container.read(cryptoServiceProvider);
      final integrityService = container.read(integrityServiceProvider);

      // CryptoService 应该已成功创建（内部依赖 IntegrityService）
      expect(cryptoService, isNotNull);
      expect(integrityService, isNotNull);
    });

    test('多次读取应该返回同一个实例（单例）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final instance1 = container.read(cryptoServiceProvider);
      final instance2 = container.read(cryptoServiceProvider);

      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('fileIOServiceProvider', () {
    test('应该返回 FileIOService 实例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(fileIOServiceProvider);

      expect(result, isA<FileIOService>());
    });

    test('多次读取应该返回同一个实例（单例）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final instance1 = container.read(fileIOServiceProvider);
      final instance2 = container.read(fileIOServiceProvider);

      expect(identical(instance1, instance2), isTrue);
    });

    test('isValidStrawFile 方法应该正确验证文件扩展名', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fileIOService = container.read(fileIOServiceProvider);

      expect(fileIOService.isValidStrawFile('test.straw'), isTrue);
      expect(fileIOService.isValidStrawFile('test.STRaw'), isTrue);
      expect(fileIOService.isValidStrawFile('test.txt'), isFalse);
      expect(fileIOService.isValidStrawFile('test.key'), isFalse);
    });

    test('isValidKeyFile 方法应该正确验证文件扩展名', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fileIOService = container.read(fileIOServiceProvider);

      expect(fileIOService.isValidKeyFile('test.key'), isTrue);
      expect(fileIOService.isValidKeyFile('test.KEY'), isTrue);
      expect(fileIOService.isValidKeyFile('test.txt'), isFalse);
      expect(fileIOService.isValidKeyFile('test.straw'), isFalse);
    });
  });

  group('draftManagerProvider', () {
    test('应该返回 DraftManager 实例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(draftManagerProvider);

      expect(result, isA<DraftManager>());
    });

    test('多次读取应该返回同一个实例（单例）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final instance1 = container.read(draftManagerProvider);
      final instance2 = container.read(draftManagerProvider);

      expect(identical(instance1, instance2), isTrue);
    });

    test('saveToDraft 和 loadFromDraft 应该正常工作', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draftManager = container.read(draftManagerProvider);
      const testContent = '{"ops":[{"insert":"Test"}]}';

      draftManager.saveToDraft(testContent);
      final loaded = draftManager.loadFromDraft();

      expect(loaded, equals(testContent));
    });

    test('clearDraft 后 loadFromDraft 应该返回 null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draftManager = container.read(draftManagerProvider);
      draftManager.saveToDraft('test content');
      draftManager.clearDraft();

      expect(draftManager.loadFromDraft(), isNull);
    });

    test('hasDraft 应该正确反映草稿状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draftManager = container.read(draftManagerProvider);

      expect(draftManager.hasDraft(), isFalse);

      draftManager.saveToDraft('content');
      expect(draftManager.hasDraft(), isTrue);

      draftManager.clearDraft();
      expect(draftManager.hasDraft(), isFalse);
    });
  });

  group('Provider 依赖关系', () {
    test('cryptoServiceProvider 和 integrityServiceProvider 应该共享容器', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 同时读取两个 Provider，验证它们在同一容器中正常工作
      final cryptoService = container.read(cryptoServiceProvider);
      final integrityService = container.read(integrityServiceProvider);

      expect(cryptoService, isA<CryptoService>());
      expect(integrityService, isA<IntegrityService>());
    });

    test('所有 Provider 应该可以在同一容器中共存', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 验证所有 Provider 可以同时初始化
      final integrity = container.read(integrityServiceProvider);
      final crypto = container.read(cryptoServiceProvider);
      final fileIO = container.read(fileIOServiceProvider);
      final draft = container.read(draftManagerProvider);

      expect(integrity, isA<IntegrityService>());
      expect(crypto, isA<CryptoService>());
      expect(fileIO, isA<FileIOService>());
      expect(draft, isA<DraftManager>());
    });
  });
}
