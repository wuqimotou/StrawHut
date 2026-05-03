/// card_provider 单元测试文件
///
/// 本文件测试 card_provider.dart 中的 CurrentCard Riverpod Notifier，
/// 验证知识卡片文件加载的状态管理行为。
///
/// 测试范围：
/// - build(): 初始状态为 AsyncValue.data(null)
/// - loadFile(): 异步加载文件并更新状态
///
/// 使用 riverpod 的 ContainerProviderTester 进行隔离测试，
/// 使用 mocktail 模拟 FileIOService 的依赖。

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

import 'mocks.dart';

void main() {
  group('CurrentCard 初始状态', () {
    test('build() 应该返回 AsyncValue.data(null) 作为初始状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(currentCardProvider);

      expect(state, isA<AsyncValue<StrawFile?>>());
      expect(state.valueOrNull, isNull);
    });

    test('初始状态应该不是 loading 状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(currentCardProvider);

      expect(state.isLoading, isFalse);
    });

    test('初始状态应该不是 error 状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(currentCardProvider);

      expect(state.hasError, isFalse);
    });
  });

  group('CurrentCard.loadFile - 成功场景', () {
    test('成功加载文件后状态应该更新为 AsyncValue.data(file)', () async {
      final mockFileIO = MockFileIOService();
      final testStrawFile = createTestStrawFile();

      when(() => mockFileIO.readStrawFile(any())).thenAnswer(
        (_) async => testStrawFile,
      );

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentCardProvider.notifier)
          .loadFile('/path/to/test.straw');

      final state = container.read(currentCardProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, equals(testStrawFile));
    });

    test('应该调用 FileIOService.readStrawFile 并传入正确的文件路径',
        () async {
      final mockFileIO = MockFileIOService();
      final testStrawFile = createTestStrawFile();

      when(() => mockFileIO.readStrawFile(any())).thenAnswer(
        (_) async => testStrawFile,
      );

      const testFilePath = '/path/to/test.straw';
      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentCardProvider.notifier)
          .loadFile(testFilePath);

      verify(() => mockFileIO.readStrawFile(testFilePath)).called(1);
    });

    test('加载不同文件应该更新为新的文件数据', () async {
      final mockFileIO = MockFileIOService();
      final file1 = createTestStrawFile(title: 'Card 1');
      final file2 = createTestStrawFile(title: 'Card 2');

      var callCount = 0;
      when(() => mockFileIO.readStrawFile(any())).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? file1 : file2;
      });

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentCardProvider.notifier)
          .loadFile('/file1.straw');
      expect(
        container.read(currentCardProvider).value?.meta.title,
        equals('Card 1'),
      );

      await container
          .read(currentCardProvider.notifier)
          .loadFile('/file2.straw');
      expect(
        container.read(currentCardProvider).value?.meta.title,
        equals('Card 2'),
      );
    });
  });

  group('CurrentCard.loadFile - 失败场景', () {
    test('文件读取失败时状态应该更新为 AsyncValue.error', () async {
      final mockFileIO = MockFileIOService();
      final testError = Exception('File not found');

      when(() => mockFileIO.readStrawFile(any())).thenThrow(testError);

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentCardProvider.notifier)
          .loadFile('/path/to/missing.straw');

      final state = container.read(currentCardProvider);
      expect(state.hasError, isTrue);
      expect(state.error, equals(testError));
    });

    test('加载失败后再次加载成功文件应该恢复正常状态', () async {
      final mockFileIO = MockFileIOService();
      final testStrawFile = createTestStrawFile();

      var isFirstCall = true;
      when(() => mockFileIO.readStrawFile(any())).thenAnswer((_) async {
        if (isFirstCall) {
          isFirstCall = false;
          throw Exception('First call fails');
        }
        return testStrawFile;
      });

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      // 第一次加载失败
      await container.read(currentCardProvider.notifier).loadFile('/fail.straw');
      expect(container.read(currentCardProvider).hasError, isTrue);

      // 第二次加载成功
      await container
          .read(currentCardProvider.notifier)
          .loadFile('/success.straw');
      final state = container.read(currentCardProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, equals(testStrawFile));
    });
  });

  group('CurrentCard.loadFile - 边界情况', () {
    test('传入空路径应该尝试读取并可能失败', () async {
      final mockFileIO = MockFileIOService();

      when(() => mockFileIO.readStrawFile(any())).thenThrow(
        Exception('Empty path'),
      );

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentCardProvider.notifier).loadFile('');

      expect(container.read(currentCardProvider).hasError, isTrue);
      verify(() => mockFileIO.readStrawFile('')).called(1);
    });

    test('多次加载同一文件路径应该每次都调用 readStrawFile', () async {
      final mockFileIO = MockFileIOService();
      final testStrawFile = createTestStrawFile();

      when(() => mockFileIO.readStrawFile(any())).thenAnswer(
        (_) async => testStrawFile,
      );

      const testPath = '/path/to/test.straw';
      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentCardProvider.notifier).loadFile(testPath);
      await container.read(currentCardProvider.notifier).loadFile(testPath);
      await container.read(currentCardProvider.notifier).loadFile(testPath);

      verify(() => mockFileIO.readStrawFile(testPath)).called(3);
    });
  });

  group('CurrentCard 状态转换', () {
    test('可以使用 when 方法正确处理不同状态', () async {
      final mockFileIO = MockFileIOService();
      final testStrawFile = createTestStrawFile();

      when(() => mockFileIO.readStrawFile(any())).thenAnswer(
        (_) async => testStrawFile,
      );

      final container = ProviderContainer(
        overrides: [
          fileIOServiceProvider.overrideWith(
            (ref) => mockFileIO as FileIOService,
          ),
        ],
      );
      addTearDown(container.dispose);

      // 初始状态 - null
      var result = '';
      container.read(currentCardProvider).when(
        data: (file) => result = file == null ? 'null' : 'file',
        loading: () => result = 'loading',
        error: (_, __) => result = 'error',
      );
      expect(result, equals('null'));

      // 加载成功后
      await container.read(currentCardProvider.notifier).loadFile('/test.straw');
      container.read(currentCardProvider).when(
        data: (file) => result = file == null ? 'null' : 'file',
        loading: () => result = 'loading',
        error: (_, __) => result = 'error',
      );
      expect(result, equals('file'));
    });
  });
}
