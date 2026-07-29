/// editor_provider 单元测试文件
///
/// 本文件测试 editor_provider.dart 中的 EditorContent Riverpod Notifier，
/// 验证编辑器内容状态管理和与 DraftManager 的交互。
///
/// 测试范围：
/// - build(): 初始状态为空字符串
/// - updateContent(): 更新状态并保存到草稿
/// - loadFromDraft(): 从草稿加载内容
/// - clear(): 清空状态和草稿
///
/// 使用 riverpod 的 ContainerProviderTester 进行隔离测试，
/// 确保状态变化和草稿管理行为符合预期。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';

void main() {
  group('EditorContent 初始状态', () {
    test('build() 应该返回空字符串作为初始状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(editorContentProvider);

      expect(state, equals(''));
    });

    test('初始状态下草稿管理器应该没有草稿', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draftManager = container.read(draftManagerProvider);

      expect(draftManager.hasDraft(), isFalse);
      expect(draftManager.loadFromDraft(), isNull);
    });
  });

  group('EditorContent.updateContent', () {
    test('应该更新 Provider 状态为新的内容', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newContent = '{"ops":[{"insert":"Hello World"}]}';
      container.read(editorContentProvider.notifier).updateContent(newContent);

      expect(container.read(editorContentProvider), equals(newContent));
    });

    test('应该同时保存内容到草稿管理器', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testContent = '{"ops":[{"insert":"Test Content"}]}';
      container.read(editorContentProvider.notifier).updateContent(testContent);

      final draftManager = container.read(draftManagerProvider);
      expect(draftManager.hasDraft(), isTrue);
      expect(draftManager.loadFromDraft(), equals(testContent));
    });

    test('多次调用应该覆盖之前的草稿', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const firstContent = '{"ops":[{"insert":"First"}]}';
      const secondContent = '{"ops":[{"insert":"Second"}]}';

      container.read(editorContentProvider.notifier).updateContent(firstContent);
      container.read(editorContentProvider.notifier).updateContent(secondContent);

      expect(container.read(editorContentProvider), equals(secondContent));
      expect(
        container.read(draftManagerProvider).loadFromDraft(),
        equals(secondContent),
      );
    });

    test('应该能够保存空字符串', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(editorContentProvider.notifier).updateContent('');

      expect(container.read(editorContentProvider), equals(''));
      expect(container.read(draftManagerProvider).loadFromDraft(), equals(''));
    });

    test('应该能够保存包含特殊字符的内容', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const specialContent = r'{"ops":[{"insert":"测试\n特殊字符\t@#$%^&*()"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(specialContent);

      expect(container.read(editorContentProvider), equals(specialContent));
      expect(
        container.read(draftManagerProvider).loadFromDraft(),
        equals(specialContent),
      );
    });
  });

  group('EditorContent.loadFromDraft', () {
    test('当存在草稿时应该加载并更新状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先保存一些草稿内容
      const draftContent = '{"ops":[{"insert":"Restored Content"}]}';
      container.read(draftManagerProvider).saveToDraft(draftContent);

      // 加载草稿
      container.read(editorContentProvider.notifier).loadFromDraft();

      expect(container.read(editorContentProvider), equals(draftContent));
    });

    test('当不存在草稿时状态应该保持不变', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 确保没有草稿
      expect(container.read(draftManagerProvider).loadFromDraft(), isNull);

      // 设置一个初始内容
      container
          .read(editorContentProvider.notifier)
          .updateContent('{"ops":[{"insert":"Original"}]}');

      // 尝试从空草稿加载
      container.read(editorContentProvider.notifier).loadFromDraft();

      // 状态应该仍然是之前设置的内容
      expect(
        container.read(editorContentProvider),
        equals('{"ops":[{"insert":"Original"}]}'),
      );
    });

    test('loadFromDraft 后草稿管理器中的草稿仍然保留', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testContent = '{"ops":[{"insert":"To Load"}]}';
      container.read(draftManagerProvider).saveToDraft(testContent);

      container.read(editorContentProvider.notifier).loadFromDraft();

      // 草稿不应被清除
      expect(container.read(draftManagerProvider).hasDraft(), isTrue);
      expect(
        container.read(draftManagerProvider).loadFromDraft(),
        equals(testContent),
      );
    });
  });

  group('EditorContent.clear', () {
    test('应该将状态重置为空字符串', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(editorContentProvider.notifier)
          .updateContent('{"ops":[{"insert":"Some Content"}]}');
      expect(container.read(editorContentProvider), isNot(equals('')));

      container.read(editorContentProvider.notifier).clear();

      expect(container.read(editorContentProvider), equals(''));
    });

    test('应该同时清除草稿管理器中的草稿', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先创建草稿
      container
          .read(editorContentProvider.notifier)
          .updateContent('{"ops":[{"insert":"Draft"}]}');
      expect(container.read(draftManagerProvider).hasDraft(), isTrue);

      // 清除
      container.read(editorContentProvider.notifier).clear();

      // 验证草稿已被清除
      expect(container.read(draftManagerProvider).hasDraft(), isFalse);
      expect(container.read(draftManagerProvider).loadFromDraft(), isNull);
    });

    test('clear 后再次 loadFromDraft 应该保持空状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(editorContentProvider.notifier)
          .updateContent('{"ops":[{"insert":"Content"}]}');
      container.read(editorContentProvider.notifier).clear();
      container.read(editorContentProvider.notifier).loadFromDraft();

      expect(container.read(editorContentProvider), equals(''));
    });

    test('对空状态的编辑器调用 clear 不应该抛出异常', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(editorContentProvider.notifier).clear(),
        returnsNormally,
      );

      expect(container.read(editorContentProvider), equals(''));
    });
  });

  group('EditorContent 完整生命周期', () {
    test('完整的编辑-保存-加载-清除流程', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. 初始状态
      expect(container.read(editorContentProvider), equals(''));

      // 2. 编辑内容
      const content1 = '{"ops":[{"insert":"Step 1"}]}';
      container.read(editorContentProvider.notifier).updateContent(content1);
      expect(container.read(editorContentProvider), equals(content1));
      expect(
        container.read(draftManagerProvider).loadFromDraft(),
        equals(content1),
      );

      // 3. 继续编辑
      const content2 = '{"ops":[{"insert":"Step 2"}]}';
      container.read(editorContentProvider.notifier).updateContent(content2);
      expect(container.read(editorContentProvider), equals(content2));
      expect(
        container.read(draftManagerProvider).loadFromDraft(),
        equals(content2),
      );

      // 4. 模拟关闭后重新打开，从草稿加载
      container.read(editorContentProvider.notifier).clear();
      expect(container.read(editorContentProvider), equals(''));

      // 注意：由于 clear() 也清除了草稿，这里不会有草稿可加载
      // 这是预期行为，测试 clear 的正确性
      container.read(editorContentProvider.notifier).loadFromDraft();
      expect(container.read(editorContentProvider), equals(''));

      // 5. 重新开始编辑
      const content3 = '{"ops":[{"insert":"New Session"}]}';
      container.read(editorContentProvider.notifier).updateContent(content3);
      expect(container.read(editorContentProvider), equals(content3));
    });

    test('更新后不清除，加载草稿应该成功恢复', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 编辑内容
      const testContent = '{"ops":[{"insert":"Important"}]}';
      container.read(editorContentProvider.notifier).updateContent(testContent);

      // 注意：不调用 clear()
      // 直接加载草稿（模拟重新打开编辑器）
      container.read(editorContentProvider.notifier).loadFromDraft();

      // 状态应该仍然是测试内容
      expect(container.read(editorContentProvider), equals(testContent));
      expect(container.read(draftManagerProvider).hasDraft(), isTrue);
    });
  });
}
