// MetaForm 组件单元测试
//
// 测试目标：验证发布对话框元数据表单的表单验证、匿名模式切换、数据获取
//
// 覆盖验收标准：
// - 表单验证正确（必填项、长度限制）
// - 匿名模式切换正常
// - .straw 文件格式符合规范（通过 meta 数据验证）
//
// 测试范围：
// - 标题输入框：必填验证
// - 发布者代号输入框：非匿名模式下必填、匿名模式下禁用
// - 描述输入框：最多 200 字符限制
// - 标签输入框：最多 10 个标签，每个最多 20 字符
// - 匿名模式开关：切换状态、影响表单数据
// - 数据获取：title、publisherAlias、description、tags、isAnonymous

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/meta_form.dart';

/// 构建用于测试的 MetaForm Widget
///
/// 将 MetaForm 包裹在 MaterialApp 中以便测试，
/// 提供 Material 主题和导航上下文。
Widget _buildMetaForm({
  VoidCallback? onChanged,
  String? initialTitle,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MetaForm(
        onChanged: onChanged,
        initialTitle: initialTitle,
      ),
    ),
  );
}

void main() {
  group('MetaForm 表单渲染测试', () {
    testWidgets('应该渲染所有表单字段', (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm());

      // 验证标题输入框存在
      expect(find.byType(TextFormField), findsNWidgets(4));

      // 验证标签文本存在
      expect(find.text('卡片标题'), findsOneWidget);
      expect(find.text('发布者代号'), findsOneWidget);
      expect(find.text('匿名发布'), findsOneWidget);
      expect(find.text('描述（可选）'), findsOneWidget);
      expect(find.text('标签（可选，用逗号分隔）'), findsOneWidget);
    });

    testWidgets('应该支持设置初始标题', (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm(initialTitle: '测试标题'));
      await tester.pumpAndSettle();

      // 查找第一个 TextFormField（标题输入框）
      final titleField = tester.widget<TextFormField>(
        find.descendant(
          of: find.byType(Form),
          matching: find.byType(TextFormField),
        ).first,
      );

      // 验证初始值已设置
      expect(titleField.controller?.text, equals('测试标题'));
    });

    testWidgets('默认情况下匿名模式应该关闭', (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm());
      await tester.pumpAndSettle();

      // 查找 SwitchListTile
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );

      // 验证初始状态为关闭（false）
      expect(switchTile.value, isFalse);
    });

    testWidgets('默认情况下发布者输入框应该启用',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm());
      await tester.pumpAndSettle();

      // 获取所有 TextFormField，第二个是发布者输入框
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      final publisherField = fields[1];

      // 验证发布者输入框启用
      expect(publisherField.enabled, isTrue);
    });
  });

  group('MetaForm 表单验证测试', () {
    testWidgets('标题为空时验证应该失败', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 触发验证（通过点击表单外部来触发 FormState 的验证）
      // 直接调用 validate() 方法
      final isValid = formKey.currentState?.validate() ?? false;

      // 需要 pump 一次让错误提示渲染
      await tester.pump();

      // 验证应该失败
      expect(isValid, isFalse);

      // 验证错误提示显示
      expect(find.text('请输入卡片标题'), findsOneWidget);
    });

    testWidgets('标题填写后验证应该通过标题检查', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '我的知识卡片');
      await tester.pumpAndSettle();

      // 非匿名模式下，输入发布者代号
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 应该验证通过（标题和发布者都有值，描述和标签为空是允许的）
      expect(isValid, isTrue);
    });

    testWidgets('非匿名模式下发布者为空时验证应该失败',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题但不输入发布者
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '我的知识卡片');
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 需要 pump 一次让错误提示渲染
      await tester.pump();

      // 验证应该失败（发布者代号为空）
      expect(isValid, isFalse);

      // 验证错误提示显示
      expect(find.text('请输入发布者代号'), findsOneWidget);
    });

    testWidgets('匿名模式下发布者为空时验证应该通过',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '我的知识卡片');
      await tester.pumpAndSettle();

      // 开启匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 匿名模式下发布者可以为空，应该验证通过
      expect(isValid, isTrue);
    });

    testWidgets('描述超过 200 字符时验证应该失败', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 注意：TextFormField 的 maxLength 属性会自动截断输入，
      // 因此无法通过 enterText 输入超过 200 字符的文本
      // 这里改为测试验证器逻辑：直接通过控制器设置超长文本，
      // 模拟绕过 maxLength 的场景
      final descriptionField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      descriptionField.controller?.text = 'a' * (MAX_DESCRIPTION_LENGTH + 1);
      await tester.pump();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;
      await tester.pump();

      // 验证应该失败（因为验证器检查长度）
      expect(isValid, isFalse);
    });

    testWidgets('描述不超过 200 字符时验证应该通过',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 输入刚好 200 字符的描述
      final descriptionField = find.byType(TextFormField).at(2);
      final exactLengthDescription = 'a' * MAX_DESCRIPTION_LENGTH;
      await tester.enterText(descriptionField, exactLengthDescription);
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 验证应该通过
      expect(isValid, isTrue);
    });

    testWidgets('标签数量超过 10 个时验证应该失败',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 输入 11 个标签（超过最大数量）
      final tagsField = find.byType(TextFormField).at(3);
      final tooManyTags = List.generate(11, (i) => 'tag$i').join(',');
      await tester.enterText(tagsField, tooManyTags);
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 需要 pump 一次让错误提示渲染
      await tester.pump();

      // 验证应该失败
      expect(isValid, isFalse);

      // 验证错误提示显示
      expect(find.text('标签数量不能超过 $MAX_TAGS_COUNT 个'), findsOneWidget);
    });

    testWidgets('单个标签超过 20 字符时验证应该失败',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 输入包含超长标签的标签列表
      final tagsField = find.byType(TextFormField).at(3);
      final longTag = 'a' * (MAX_TAG_LENGTH + 1);
      await tester.enterText(tagsField, '正常标签, $longTag');
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 需要 pump 一次让错误提示渲染
      await tester.pump();

      // 验证应该失败
      expect(isValid, isFalse);

      // 验证错误提示包含标签长度限制信息
      expect(find.textContaining('每个标签不能超过'), findsOneWidget);
    });

    testWidgets('标签为空时验证应该通过', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 标签保持为空

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 标签为空是允许的，应该验证通过
      expect(isValid, isTrue);
    });

    testWidgets('标签数量刚好 10 个时验证应该通过',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入标题
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试标题');
      await tester.pumpAndSettle();

      // 输入发布者
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '测试作者');
      await tester.pumpAndSettle();

      // 输入刚好 10 个标签
      final tagsField = find.byType(TextFormField).at(3);
      final exactTags = List.generate(10, (i) => 'tag$i').join(',');
      await tester.enterText(tagsField, exactTags);
      await tester.pumpAndSettle();

      // 触发验证
      final isValid = formKey.currentState?.validate() ?? false;

      // 验证应该通过
      expect(isValid, isTrue);
    });
  });

  group('MetaForm 匿名模式切换测试', () {
    testWidgets('开启匿名模式应该禁用发布者输入框',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm());
      await tester.pumpAndSettle();

      // 验证初始状态：发布者输入框启用
      var fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[1].enabled, isTrue);

      // 开启匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证发布者输入框禁用
      fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[1].enabled, isFalse);
    });

    testWidgets('关闭匿名模式应该启用发布者输入框',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMetaForm());
      await tester.pumpAndSettle();

      // 先开启匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证发布者输入框禁用
      var fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[1].enabled, isFalse);

      // 关闭匿名模式
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证发布者输入框重新启用
      fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[1].enabled, isTrue);
    });

    testWidgets('匿名模式下 publisherAlias 应该返回 null',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 开启匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证匿名模式下 publisherAlias 返回 null
      expect(formKey.currentState?.publisherAlias, isNull);
    });

    testWidgets('非匿名模式下 publisherAlias 应该返回输入值',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 输入发布者代号
      final publisherField = find.byType(TextFormField).at(1);
      await tester.enterText(publisherField, '我的代号');
      await tester.pumpAndSettle();

      // 验证非匿名模式下 publisherAlias 返回输入值
      expect(formKey.currentState?.publisherAlias, equals('我的代号'));
    });

    testWidgets('匿名模式切换时应该触发 onChanged 回调',
        (WidgetTester tester) async {
      var callbackCallCount = 0;
      await tester.pumpWidget(
        _buildMetaForm(
          onChanged: () {
            callbackCallCount++;
          },
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = callbackCallCount;

      // 切换匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证回调被触发
      expect(callbackCallCount, greaterThan(initialCount));
    });
  });

  group('MetaForm 数据获取测试', () {
    testWidgets('应该正确获取标题数据', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '我的知识卡片');
      await tester.pumpAndSettle();

      expect(formKey.currentState?.title, equals('我的知识卡片'));
    });

    testWidgets('标题应该自动去除首尾空格', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '  测试标题  ');
      await tester.pumpAndSettle();

      expect(formKey.currentState?.title, equals('测试标题'));
    });

    testWidgets('应该正确获取描述数据', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionField = find.byType(TextFormField).at(2);
      await tester.enterText(descriptionField, '这是一段测试描述');
      await tester.pumpAndSettle();

      expect(formKey.currentState?.description, equals('这是一段测试描述'));
    });

    testWidgets('描述为空时应该返回空字符串', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(formKey.currentState?.description, equals(''));
    });

    testWidgets('应该正确解析逗号分隔的标签', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tagsField = find.byType(TextFormField).at(3);
      await tester.enterText(tagsField, 'Flutter, 加密, 笔记');
      await tester.pumpAndSettle();

      final tags = formKey.currentState?.tags ?? [];
      expect(tags, equals(['Flutter', '加密', '笔记']));
    });

    testWidgets('标签应该自动过滤空字符串和去除首尾空格',
        (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tagsField = find.byType(TextFormField).at(3);
      await tester.enterText(tagsField, '  标签1 , ,  标签2  ,');
      await tester.pumpAndSettle();

      final tags = formKey.currentState?.tags ?? [];
      expect(tags, equals(['标签1', '标签2']));
    });

    testWidgets('标签为空时应该返回空列表', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(formKey.currentState?.tags, isEmpty);
    });

    testWidgets('应该正确获取匿名模式状态', (WidgetTester tester) async {
      final formKey = GlobalKey<MetaFormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return MetaForm(key: formKey);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始状态：非匿名
      expect(formKey.currentState?.isAnonymous, isFalse);

      // 开启匿名模式
      final switchFinder = find.byType(SwitchListTile);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // 验证匿名模式已开启
      expect(formKey.currentState?.isAnonymous, isTrue);
    });
  });

  group('MetaForm 表单变化回调测试', () {
    testWidgets('输入标题时应该触发 onChanged 回调',
        (WidgetTester tester) async {
      var callbackCallCount = 0;
      await tester.pumpWidget(
        _buildMetaForm(
          onChanged: () {
            callbackCallCount++;
          },
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = callbackCallCount;

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '测试');
      await tester.pumpAndSettle();

      expect(callbackCallCount, greaterThan(initialCount));
    });

    testWidgets('输入描述时应该触发 onChanged 回调',
        (WidgetTester tester) async {
      var callbackCallCount = 0;
      await tester.pumpWidget(
        _buildMetaForm(
          onChanged: () {
            callbackCallCount++;
          },
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = callbackCallCount;

      final descriptionField = find.byType(TextFormField).at(2);
      await tester.enterText(descriptionField, '测试描述');
      await tester.pumpAndSettle();

      expect(callbackCallCount, greaterThan(initialCount));
    });

    testWidgets('输入标签时应该触发 onChanged 回调',
        (WidgetTester tester) async {
      var callbackCallCount = 0;
      await tester.pumpWidget(
        _buildMetaForm(
          onChanged: () {
            callbackCallCount++;
          },
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = callbackCallCount;

      final tagsField = find.byType(TextFormField).at(3);
      await tester.enterText(tagsField, '测试标签');
      await tester.pumpAndSettle();

      expect(callbackCallCount, greaterThan(initialCount));
    });
  });

  group('MetaForm 资源清理测试', () {
    testWidgets('dispose 时应该释放所有控制器资源',
        (WidgetTester tester) async {
      // 这个测试通过不抛出来验证 dispose 正常工作
      await tester.pumpWidget(_buildMetaForm());
      await tester.pumpAndSettle();

      // 替换 Widget 触发 dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // 如果没有抛出异常，说明 dispose 正常
      expect(true, isTrue);
    });
  });
}
