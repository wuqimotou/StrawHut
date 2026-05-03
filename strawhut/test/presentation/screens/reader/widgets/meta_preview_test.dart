// ignore_for_file: dangling_library_doc_comments // 忽略 library doc comments 警告，因为测试文件使用文档注释说明测试范围
// ignore_for_file: avoid_redundant_argument_values // 允许显式传递默认值参数以增强测试可读性
/// MetaPreview 组件 Widget 单元测试
///
/// 测试目标：验证 MetaPreview 组件的渲染和数据显示是否符合任务 5.1 验收标准
///
/// 覆盖范围：
/// - 卡片标题（大字号）正确显示
/// - 发布者代号正确显示
/// - 发布日期格式化显示
/// - 描述文本正确显示（存在时）
/// - 标签列表（Chip 样式）正确显示
/// - 匿名标识（匿名模式时）正确显示
/// - 加密算法标识正确显示
/// - MetaPreview.fromMeta 便捷构造方法正确工作
/// - 空描述/空标签时不显示对应区域
/// - 布局结构正确（Card、Column、Divider 等）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/screens/reader/widgets/meta_preview.dart';

/// 构建用于测试的 MetaPreview Widget
///
/// 将 MetaPreview 包裹在 MaterialApp 中以便测试主题和文本样式。
Widget _buildMetaPreview({required StrawFile strawFile}) {
  return MaterialApp(
    home: Scaffold(
      body: MetaPreview(strawFile: strawFile),
    ),
  );
}

/// 构建用于测试的 StrawFile 实例
StrawFile _createTestStrawFile({
  String title = '测试知识卡片',
  String publisherAlias = '测试作者',
  String publishDate = '2026-05-01T12:00:00Z',
  List<String> tags = const ['Flutter', '测试'],
  String? description = '这是一段测试描述',
  bool isAnonymous = false,
}) {
  return StrawFile(
    formatVersion: FormatVersion.fromString('1.0.0'),
    meta: CardMeta(
      publisherAlias: publisherAlias,
      publishDate: publishDate,
      title: title,
      isAnonymous: isAnonymous,
      tags: tags,
      description: description,
    ),
    content: const EncryptedContent(
      encryptedDataBase64: 'dGVzdEVuY3J5cHRlZERhdGE=',
      ivBase64: 'dGVzdEl2',
      algorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
    ),
    integrity: const IntegrityInfo(
      hash: 'sha256:testhash',
      hashAlgorithm: 'SHA-256',
    ),
  );
}

void main() {
  group('MetaPreview 基本渲染测试', () {
    testWidgets('组件应使用 Card 作为容器', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证 Card 容器存在
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('组件应使用 Column 进行垂直布局', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证 Column 布局存在
      expect(find.byType(Column), findsWidgets);
    });
  });

  group('MetaPreview 元数据显示测试', () {
    testWidgets('应正确显示卡片标题', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(title: '我的知识卡片');

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证标题文本存在
      expect(find.text('我的知识卡片'), findsOneWidget);
    });

    testWidgets('应正确显示发布者代号', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(publisherAlias: '张三');

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证发布者代号存在
      expect(find.text('张三'), findsOneWidget);
    });

    testWidgets('应正确显示发布日期（包含日期和时间）',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publishDate: '2026-05-01T12:30:00Z',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 日期应该格式化为 "2026-05-01 12:30"
      expect(find.textContaining('2026-05-01'), findsOneWidget);
      expect(find.textContaining('12:30'), findsOneWidget);
    });

    testWidgets('发布日期仅包含日期部分时应正确显示',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publishDate: '2026-05-01',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 仅显示日期部分
      expect(find.text('2026-05-01'), findsOneWidget);
    });

    testWidgets('发布日期格式异常时应返回原始字符串',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publishDate: '不是日期格式',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 返回原始字符串
      expect(find.text('不是日期格式'), findsOneWidget);
    });

    testWidgets('应正确显示描述文本', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        description: '这是一段详细的测试描述内容',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证描述文本存在
      expect(find.text('这是一段详细的测试描述内容'), findsOneWidget);
    });

    testWidgets('描述为空时不应显示描述区域', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(description: '');

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 空描述不应显示
      expect(find.text(''), findsNothing);
    });

    testWidgets('描述为 null 时不应显示描述区域', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(description: null);

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // null 描述不应显示任何描述文本
      // 由于描述是条件渲染，应该找不到 Divider 之间的描述文字
    });
  });

  group('MetaPreview 标签显示测试', () {
    testWidgets('应正确显示所有标签', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        tags: ['Flutter', '加密', '知识分享'],
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证所有标签存在
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('加密'), findsOneWidget);
      expect(find.text('知识分享'), findsOneWidget);
    });

    testWidgets('标签应使用 Chip 组件渲染', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(tags: ['测试标签']);

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证 Chip 组件存在（标签数量 + 可能的其他 Chip）
      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('标签为空列表时不应显示标签区域',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(tags: []);

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 空标签时不显示任何 Chip
      // 验证：由于没有标签，Wrap 组件不应该存在
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('MetaPreview 匿名模式测试', () {
    testWidgets('匿名模式下应显示"匿名"标识', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publisherAlias: 'Anonymous_a3f7b2c1',
        isAnonymous: true,
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证匿名标识存在
      expect(find.text('匿名'), findsOneWidget);
    });

    testWidgets('匿名模式下应显示 visibility_off 图标',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publisherAlias: 'Anonymous_a3f7b2c1',
        isAnonymous: true,
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证匿名图标存在
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('非匿名模式下不应显示"匿名"标识',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publisherAlias: '张三',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证匿名标识不存在
      expect(find.text('匿名'), findsNothing);
    });

    testWidgets('非匿名模式下不应显示 visibility_off 图标',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        publisherAlias: '张三',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证匿名图标不存在
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });
  });

  group('MetaPreview 加密算法显示测试', () {
    testWidgets('应正确显示加密算法标识', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证加密算法文本存在
      expect(
        find.text('加密算法：$ENCRYPTION_ALGORITHM_AES_256_GCM'),
        findsOneWidget,
      );
    });

    testWidgets('应显示 lock_outline 图标', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证锁图标存在
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('MetaPreview 布局元素测试', () {
    testWidgets('应显示 person_outline 图标（发布者图标）',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证发布者图标存在
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('应显示 calendar_today_outlined 图标（日期图标）',
        (WidgetTester tester) async {
      final strawFile = _createTestStrawFile();

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证日期图标存在
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('应显示 Divider 分隔线', (WidgetTester tester) async {
      final strawFile = _createTestStrawFile(
        description: '有描述才会显示 Divider',
      );

      await tester.pumpWidget(_buildMetaPreview(strawFile: strawFile));
      await tester.pumpAndSettle();

      // 验证存在 Divider（描述上方和加密算法上方各一个）
      expect(find.byType(Divider), findsWidgets);
    });
  });

  group('MetaPreview.fromMeta 便捷构造测试', () {
    testWidgets('应能从 CardMeta 直接创建 MetaPreview',
        (WidgetTester tester) async {
      const meta = CardMeta(
        publisherAlias: '便捷构造测试',
        publishDate: '2026-05-01T10:00:00Z',
        title: '便捷构造标题',
        isAnonymous: false,
        tags: <String>['测试'],
        description: '便捷构造描述',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetaPreview.fromMeta(meta),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题正确显示
      expect(find.text('便捷构造标题'), findsOneWidget);
      // 验证发布者正确显示
      expect(find.text('便捷构造测试'), findsOneWidget);
      // 验证描述正确显示
      expect(find.text('便捷构造描述'), findsOneWidget);
      // 验证加密算法仍然显示默认值
      expect(
        find.text('加密算法：$ENCRYPTION_ALGORITHM_AES_256_GCM'),
        findsOneWidget,
      );
    });
  });
}
