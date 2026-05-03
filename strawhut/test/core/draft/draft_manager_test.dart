/// DraftManager 单元测试文件
///
/// 本文件包含对 DraftManager 类的全面单元测试，覆盖以下核心功能：
/// - saveToDraft: 保存 Delta JSON 字符串到内存
/// - loadFromDraft: 从内存读取草稿内容
/// - clearDraft: 清除草稿内容
/// - hasDraft: 检查是否存在有效草稿
///
/// DraftManager 是 StrawHut 应用的草稿管理核心组件，
/// 采用纯内存存储方案，符合"零持久化"架构原则。
/// 这些测试确保草稿管理器在各种边界条件下行为正确，
/// 为用户数据安全和编辑体验提供可靠保障。

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/draft/draft_manager.dart';

void main() {
  // 测试分组：保存草稿功能
  group('saveToDraft', () {
    test('能够正确保存 Delta JSON 字符串内容到内存', () {
      // 构建一个模拟 Quill Delta JSON 格式的测试字符串
      const testContent = '{"ops":[{"insert":"Hello World"}]}';
      final manager = DraftManager();

      manager.saveToDraft(testContent);
      final result = manager.loadFromDraft();

      expect(result, equals(testContent));
    });

    test('保存空字符串时应该成功存储空字符串而非 null', () {
      // 验证空字符串被正确保存，不自动转换为 null
      // 这确保了用户清空编辑器内容后仍能区分"空草稿"和"无草稿"
      final manager = DraftManager();

      manager.saveToDraft('');
      final result = manager.loadFromDraft();

      expect(result, isEmpty);
      expect(result, isNotNull);
    });

    test('保存内容应该覆盖之前的草稿内容', () {
      // 验证重复调用 saveToDraft 时，新内容会完全替换旧内容
      // 这是防止草稿数据混乱的关键行为
      final manager = DraftManager();
      const firstContent = '{"ops":[{"insert":"First Content"}]}';
      const secondContent = '{"ops":[{"insert":"Second Content"}]}';

      manager.saveToDraft(firstContent);
      manager.saveToDraft(secondContent);

      expect(manager.loadFromDraft(), equals(secondContent));
    });

    test('保存包含特殊字符的 Delta JSON 字符串', () {
      // 验证复杂 JSON 内容（包含 Unicode 字符、换行符等）能正确保存
      // 这模拟了实际编辑场景中的富文本内容
      const complexContent = r'''{"ops":[{"insert":"测试内容：\n你好世界！\nSpecial chars: @#$%^&*()\nUnicode: 日本語テスト"}]}''';
      final manager = DraftManager();

      manager.saveToDraft(complexContent);

      expect(manager.loadFromDraft(), equals(complexContent));
    });

    test('保存较长的 Delta JSON 字符串内容', () {
      // 验证大数据量场景下的保存功能
      // 模拟包含大量文本的编辑器内容
      final manager = DraftManager();
      final longContent = '{"ops":[${List.generate(
        1000,
        (i) => '{"insert":"Paragraph $i\\n"}',
      ).join(',')}]}';

      manager.saveToDraft(longContent);

      expect(manager.loadFromDraft(), equals(longContent));
    });

    test('多次保存后加载的内容应该与最后一次保存完全一致', () {
      // 验证连续多次保存操作的最终一致性
      // 确保不存在状态残留或数据损坏问题
      final manager = DraftManager();

      for (var i = 0; i < 10; i++) {
        manager.saveToDraft('{"ops":[{"insert":"Version $i"}]}');
      }

      expect(manager.loadFromDraft(), equals('{"ops":[{"insert":"Version 9"}]}'));
    });
  });

  // 测试分组：加载草稿功能
  group('loadFromDraft', () {
    test('当存在草稿时返回保存的内容', () {
      // 验证基本的加载流程：保存后能正确读取
      const testContent = '{"ops":[{"insert":"Test Data"}]}';
      final manager = DraftManager();

      manager.saveToDraft(testContent);

      expect(manager.loadFromDraft(), equals(testContent));
    });

    test('当不存在草稿时（新实例）返回 null', () {
      // 验证新建 DraftManager 实例的初始状态
      // 这是确保应用首次启动时不加载无效草稿的关键测试
      final manager = DraftManager();

      expect(manager.loadFromDraft(), isNull);
    });

    test('clearDraft 后 loadFromDraft 返回 null', () {
      // 验证清除草稿后加载行为正确
      // 这是用户发布成功后清除草稿场景的核心保障
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"To be cleared"}]}');

      manager.clearDraft();

      expect(manager.loadFromDraft(), isNull);
    });

    test('多次连续加载返回相同的内容', () {
      // 验证 loadFromDraft 是幂等操作，不会修改内部状态
      const testContent = '{"ops":[{"insert":"Stable Content"}]}';
      final manager = DraftManager();

      manager.saveToDraft(testContent);

      expect(manager.loadFromDraft(), equals(testContent));
      expect(manager.loadFromDraft(), equals(testContent));
      expect(manager.loadFromDraft(), equals(testContent));
    });

    test('保存空字符串后 loadFromDraft 返回空字符串', () {
      // 验证空字符串草稿的加载行为
      // 注意：hasDraft 对空字符串返回 false，但 loadFromDraft 返回空字符串
      final manager = DraftManager();

      manager.saveToDraft('');

      expect(manager.loadFromDraft(), isEmpty);
      expect(manager.loadFromDraft(), isNotNull);
    });
  });

  // 测试分组：清除草稿功能
  group('clearDraft', () {
    test('清除后草稿内容变为 null', () {
      // 验证 clearDraft 的核心功能：彻底移除草稿数据
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"Important Draft"}]}');

      manager.clearDraft();

      expect(manager.loadFromDraft(), isNull);
    });

    test('对已清除的草稿再次调用 clearDraft 不会抛出异常', () {
      // 验证 clearDraft 的幂等性：重复调用应该安全无副作用
      // 这确保上层调用者无需检查草稿状态即可安全调用 clearDraft
      final manager = DraftManager();

      manager.clearDraft();
      manager.clearDraft();

      expect(manager.loadFromDraft(), isNull);
    });

    test('对新实例调用 clearDraft 不会抛出异常', () {
      // 验证新建实例直接调用 clearDraft 的安全性
      final manager = DraftManager();

      expect(() => manager.clearDraft(), returnsNormally);
    });

    test('清除草稿后 hasDraft 返回 false', () {
      // 验证清除草稿后状态检查的一致性
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"Draft to clear"}]}');

      manager.clearDraft();

      expect(manager.hasDraft(), isFalse);
    });

    test('清除草稿后仍可继续保存新草稿', () {
      // 验证清除草稿不会破坏 DraftManager 的后续使用能力
      // 确保清除操作只是重置状态，而非销毁功能
      final manager = DraftManager();
      const oldContent = '{"ops":[{"insert":"Old"}]}';
      const newContent = '{"ops":[{"insert":"New"}]}';

      manager.saveToDraft(oldContent);
      manager.clearDraft();
      manager.saveToDraft(newContent);

      expect(manager.loadFromDraft(), equals(newContent));
    });
  });

  // 测试分组：检查草稿功能
  group('hasDraft', () {
    test('新实例没有草稿时返回 false', () {
      // 验证应用首次启动时的默认状态
      // 这是决定是否显示"恢复草稿"提示的关键依据
      final manager = DraftManager();

      expect(manager.hasDraft(), isFalse);
    });

    test('保存内容后返回 true', () {
      // 验证保存操作后草稿状态正确更新
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"Valid Draft"}]}');

      expect(manager.hasDraft(), isTrue);
    });

    test('清除草稿后返回 false', () {
      // 验证清除操作后草稿状态正确更新
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"Draft"}]}');

      manager.clearDraft();

      expect(manager.hasDraft(), isFalse);
    });

    test('保存空字符串时返回 false', () {
      // 验证空字符串不被视为有效草稿
      // 这是关键的业务逻辑：编辑器为空时不应提示恢复草稿
      final manager = DraftManager();
      manager.saveToDraft('');

      expect(manager.hasDraft(), isFalse);
    });

    test('清除后再次保存内容返回 true', () {
      // 验证草稿状态在清除-重新保存循环中的正确性
      final manager = DraftManager();
      manager.saveToDraft('{"ops":[{"insert":"First Draft"}]}');

      manager.clearDraft();
      manager.saveToDraft('{"ops":[{"insert":"Second Draft"}]}');

      expect(manager.hasDraft(), isTrue);
    });

    test('保存非空白内容后返回 true', () {
      // 验证各种合法 Delta JSON 格式都能被正确识别为有效草稿
      final manager = DraftManager();

      // 简单文本
      manager.saveToDraft('{"ops":[{"insert":"Text"}]}');
      expect(manager.hasDraft(), isTrue);

      // 复杂富文本
      manager.saveToDraft(
        '{"ops":[{"insert":"Bold","attributes":{"bold":true}},{"insert":"\\n"}]}',
      );
      expect(manager.hasDraft(), isTrue);
    });
  });

  // 测试分组：完整的草稿生命周期
  group('草稿生命周期', () {
    test('完整的保存-加载-清除-重新保存周期', () {
      // 模拟用户实际使用草稿功能的完整流程：
      // 1. 开始编辑并保存草稿
      // 2. 检查草稿存在
      // 3. 加载草稿恢复内容
      // 4. 清除草稿（模拟发布成功）
      // 5. 重新开始编辑并保存新草稿
      final manager = DraftManager();

      // 初始状态：无草稿
      expect(manager.hasDraft(), isFalse);
      expect(manager.loadFromDraft(), isNull);

      // 保存第一个草稿
      const draft1 = '{"ops":[{"insert":"First Session Content"}]}';
      manager.saveToDraft(draft1);
      expect(manager.hasDraft(), isTrue);
      expect(manager.loadFromDraft(), equals(draft1));

      // 清除草稿（模拟发布）
      manager.clearDraft();
      expect(manager.hasDraft(), isFalse);
      expect(manager.loadFromDraft(), isNull);

      // 保存第二个草稿
      const draft2 = '{"ops":[{"insert":"Second Session Content"}]}';
      manager.saveToDraft(draft2);
      expect(manager.hasDraft(), isTrue);
      expect(manager.loadFromDraft(), equals(draft2));
    });

    test('多次保存-加载循环保持数据一致性', () {
      // 验证 DraftManager 在长时间使用过程中的稳定性
      // 模拟用户多次编辑、保存、加载的循环操作
      final manager = DraftManager();
      const testContents = [
        '{"ops":[{"insert":"Content 1"}]}',
        '{"ops":[{"insert":"Content 2"}]}',
        '{"ops":[{"insert":"Content 3"}]}',
        '{"ops":[{"insert":"Content 4"}]}',
        '{"ops":[{"insert":"Content 5"}]}',
      ];

      for (var i = 0; i < testContents.length; i++) {
        // 保存新内容
        manager.saveToDraft(testContents[i]);
        expect(manager.hasDraft(), isTrue);

        // 验证加载的内容与保存的内容完全一致
        final loaded = manager.loadFromDraft();
        expect(loaded, equals(testContents[i]));

        // 模拟继续编辑并覆盖保存
        final updatedContent = '${testContents[i]}_updated';
        manager.saveToDraft(updatedContent);
        expect(manager.loadFromDraft(), equals(updatedContent));
      }
    });
  });

  // 测试分组：边界情况
  group('边界情况', () {
    test('保存仅包含空白字符的字符串', () {
      // 验证空白字符串的处理方式
      // 空白字符串虽然技术上非空，但业务上可能被视为无效内容
      final manager = DraftManager();

      manager.saveToDraft('   ');

      // hasDraft 返回 true，因为字符串非空（包含空白字符）
      expect(manager.hasDraft(), isTrue);
      expect(manager.loadFromDraft(), equals('   '));
    });

    test('保存换行符内容', () {
      // 验证换行符等特殊空白字符能正确保存
      final manager = DraftManager();
      const newlinesContent = '\n\n\n';

      manager.saveToDraft(newlinesContent);

      expect(manager.hasDraft(), isTrue);
      expect(manager.loadFromDraft(), equals(newlinesContent));
    });

    test('交替调用各个方法不会导致状态混乱', () {
      // 验证各种方法调用顺序组合下的状态一致性
      final manager = DraftManager();

      // 加载不存在的草稿
      expect(manager.loadFromDraft(), isNull);

      // 清除不存在的草稿
      manager.clearDraft();
      expect(manager.loadFromDraft(), isNull);

      // 检查不存在的草稿
      expect(manager.hasDraft(), isFalse);

      // 保存后检查
      manager.saveToDraft('{"ops":[{"insert":"Test"}]}');
      expect(manager.hasDraft(), isTrue);

      // 清除后再检查
      manager.clearDraft();
      expect(manager.hasDraft(), isFalse);

      // 保存空字符串后检查
      manager.saveToDraft('');
      expect(manager.hasDraft(), isFalse);

      // 保存有效内容后检查
      manager.saveToDraft('{"ops":[{"insert":"Valid"}]}');
      expect(manager.hasDraft(), isTrue);
    });
  });
}
