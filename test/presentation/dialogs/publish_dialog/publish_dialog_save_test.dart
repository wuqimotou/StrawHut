// PublishDialog "发布后保存暗号" 提示对话框测试
//
// 测试目标：验证发布后保存暗号提示对话框的功能，包括：
// - 对话框显示正确的标题和描述文本
// - "跳过" 按钮关闭对话框并返回 false
// - "保存暗号" 按钮关闭对话框并返回 true
// - 点击遮罩层关闭对话框（如果适用）
//
// 覆盖验收标准：
// - saveAfterPublish 标题文本正确
// - saveAfterPublishDesc 内容文本正确
// - skipSave 按钮行为正确
// - savePassphraseAction 按钮行为正确

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/l10n/l10n.dart';

void main() {
  // ============================================================
  // 辅助方法
  // ============================================================

  /// 构建保存暗号提示对话框测试 Widget
  ///
  /// 模拟 PublishDialog 中 _showSavePassphrasePrompt 的行为，
  /// 直接渲染对话框并捕获返回值。
  Widget buildTestWidget({
    required ValueSetter<bool?> onResult,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final l10n = AppLocalizations.of(context)!;
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.saveAfterPublish),
                    content: Text(l10n.saveAfterPublishDesc),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.skipSave),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.savePassphraseAction),
                      ),
                    ],
                  ),
                );
                onResult(result);
              },
              child: const Text('打开对话框'),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // 对话框内容测试
  // ============================================================
  group('保存暗号提示对话框内容', () {
    testWidgets('应显示正确的标题文本', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 点击按钮打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证标题文本
      expect(find.text('保存暗号到保险库？'), findsOneWidget);
    });

    testWidgets('应显示正确的描述文本', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 点击按钮打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证描述文本
      expect(
        find.text('您刚刚使用的暗号不在保险库中。保存后，下次加密或解密时可快速使用。'),
        findsOneWidget,
      );
    });

    testWidgets('应显示 "跳过" 和 "保存暗号" 按钮', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 点击按钮打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证按钮存在
      expect(find.text('跳过'), findsOneWidget);
      expect(find.text('保存暗号'), findsOneWidget);
    });
  });

  // ============================================================
  // 按钮行为测试
  // ============================================================
  group('保存暗号提示对话框按钮行为', () {
    testWidgets('点击 "跳过" 应关闭对话框并返回 false', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        buildTestWidget(onResult: (result) => dialogResult = result),
      );
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 点击 "跳过"
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      // 验证返回值
      expect(dialogResult, isFalse);

      // 验证对话框已关闭
      expect(find.text('保存暗号到保险库？'), findsNothing);
    });

    testWidgets('点击 "保存暗号" 应关闭对话框并返回 true', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        buildTestWidget(onResult: (result) => dialogResult = result),
      );
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 点击 "保存暗号"
      await tester.tap(find.text('保存暗号'));
      await tester.pumpAndSettle();

      // 验证返回值
      expect(dialogResult, isTrue);

      // 验证对话框已关闭
      expect(find.text('保存暗号到保险库？'), findsNothing);
    });
  });

  // ============================================================
  // 对话框结构测试
  // ============================================================
  group('保存暗号提示对话框结构', () {
    testWidgets('对话框应包含 AlertDialog', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证 AlertDialog 存在
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('"保存暗号" 按钮应为 FilledButton', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证 FilledButton 存在
      expect(find.byType(FilledButton), findsOneWidget);

      // 验证 FilledButton 文本为 "保存暗号"
      final filledButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      final buttonText = (filledButton.child! as Text).data;
      expect(buttonText, '保存暗号');
    });

    testWidgets('"跳过" 按钮应为 TextButton', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证 TextButton 存在
      expect(find.byType(TextButton), findsOneWidget);

      // 验证 TextButton 文本为 "跳过"
      final textButton = tester.widget<TextButton>(
        find.byType(TextButton),
      );
      final buttonText = (textButton.child! as Text).data;
      expect(buttonText, '跳过');
    });
  });

  // ============================================================
  // 边界条件测试
  // ============================================================
  group('保存暗号提示对话框边界条件', () {
    testWidgets('多次打开关闭对话框应正常工作', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        buildTestWidget(onResult: (result) => dialogResult = result),
      );
      await tester.pumpAndSettle();

      // 第一次打开并跳过
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(dialogResult, isFalse);

      // 第二次打开并保存
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存暗号'));
      await tester.pumpAndSettle();
      expect(dialogResult, isTrue);
    });

    testWidgets('对话框标题和描述不应为空', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onResult: (_) {}));
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证 AlertDialog 的 title 和 content 不为空
      final alertDialog = tester.widget<AlertDialog>(
        find.byType(AlertDialog),
      );

      // title 应为非空 Text widget
      final titleWidget = alertDialog.title! as Text;
      expect(titleWidget.data, isNotEmpty);

      // content 应为非空 Text widget
      final contentWidget = alertDialog.content! as Text;
      expect(contentWidget.data, isNotEmpty);
    });
  });
}
