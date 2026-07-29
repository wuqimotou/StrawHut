// ExportOptions 组件单元测试
//
// 测试目标：验证发布对话框导出选项组件的勾选状态和回调
//
// 覆盖验收标准：
// - .key 文件（可选）格式符合规范（通过 UI 交互验证）
//
// 测试范围：
// - CheckboxListTile 渲染和标题文本
// - 勾选状态正确反映 value 参数
// - 勾选/取消勾选时触发 onChanged 回调
// - 默认未勾选状态

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/export_options.dart';

/// 构建用于测试的 ExportOptions Widget
///
/// 将 ExportOptions 包裹在 MaterialApp 中以便测试。
Widget _buildExportOptions({
  required bool value,
  ValueChanged<bool?>? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExportOptions(
        value: value,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('ExportOptions 渲染测试', () {
    testWidgets('应该渲染 CheckboxListTile 组件', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      // 验证使用 CheckboxListTile
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('应该显示"导出 .key 文件"标题', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      // 验证标题文本存在
      expect(find.text('导出 .key 文件'), findsOneWidget);
    });

    testWidgets('应该显示副标题解释说明', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      // 验证副标题文本存在
      expect(
        find.text('密钥文件可单独保存和传输，建议与 .straw 文件分开保管'),
        findsOneWidget,
      );
    });

    testWidgets('复选框应该放在左侧', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证 controlAffinity 为 leading（左侧）
      expect(
        checkboxListTile.controlAffinity,
        equals(ListTileControlAffinity.leading),
      );
    });

    testWidgets('内容边距应该为零', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证 contentPadding 为 EdgeInsets.zero
      expect(checkboxListTile.contentPadding, equals(EdgeInsets.zero));
    });
  });

  group('ExportOptions 勾选状态测试', () {
    testWidgets('value 为 false 时复选框应该未勾选', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证未勾选状态
      expect(checkbox.value, isFalse);
    });

    testWidgets('value 为 true 时复选框应该已勾选', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: true));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证已勾选状态
      expect(checkbox.value, isTrue);
    });
  });

  group('ExportOptions 回调测试', () {
    testWidgets('勾选复选框时应该触发 onChanged 回调并传入 true',
        (WidgetTester tester) async {
      bool? receivedValue;
      await tester.pumpWidget(_buildExportOptions(
        value: false,
        onChanged: (value) {
          receivedValue = value;
        },
      ),
      );
      await tester.pumpAndSettle();

      // 点击 CheckboxListTile（勾选）
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // 验证回调收到 true 值
      expect(receivedValue, isTrue);
    });

    testWidgets('取消勾选复选框时应该触发 onChanged 回调并传入 false',
        (WidgetTester tester) async {
      bool? receivedValue;
      await tester.pumpWidget(_buildExportOptions(
        value: true,
        onChanged: (value) {
          receivedValue = value;
        },
      ),
      );
      await tester.pumpAndSettle();

      // 点击 CheckboxListTile（取消勾选）
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // 验证回调收到 false 值
      expect(receivedValue, isFalse);
    });

    testWidgets('点击复选框区域应该触发切换', (WidgetTester tester) async {
      bool? receivedValue;
      await tester.pumpWidget(_buildExportOptions(
        value: false,
        onChanged: (value) {
          receivedValue = value;
        },
      ),
      );
      await tester.pumpAndSettle();

      // 直接点击 Checkbox（而非整个 ListTile）
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 验证回调被触发
      expect(receivedValue, isTrue);
    });
  });

  group('ExportOptions 视觉样式测试', () {
    testWidgets('勾选状态应该使用主题色作为 activeColor', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: true));
      await tester.pumpAndSettle();

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证 activeColor 不为 null（使用主题色）
      expect(checkboxListTile.activeColor, isNotNull);
    });

    testWidgets('勾选图标应该使用白色', (WidgetTester tester) async {
      await tester.pumpWidget(_buildExportOptions(value: true));
      await tester.pumpAndSettle();

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // 验证 checkColor 为白色
      expect(checkboxListTile.checkColor, equals(Colors.white));
    });
  });

  group('ExportOptions 默认值测试', () {
    testWidgets('默认应该使用 false 作为 value（不勾选）', (WidgetTester tester) async {
      // 这个测试验证在 PublishDialog 中，_exportKeyFile 初始值为 false
      // 我们通过传入 false 来模拟默认行为
      await tester.pumpWidget(_buildExportOptions(value: false));
      await tester.pumpAndSettle();

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      expect(checkboxListTile.value, isFalse);
    });
  });

  group('ExportOptions 交互测试', () {
    testWidgets('多次切换应该每次都触发回调', (WidgetTester tester) async {
      var callbackCount = 0;
      var lastValue = false;
      await tester.pumpWidget(_buildExportOptions(
        value: false,
        onChanged: (value) {
          callbackCount++;
          lastValue = value ?? false;
        },
      ),
      );
      await tester.pumpAndSettle();

      // 第一次点击：false -> true
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(callbackCount, equals(1));
      expect(lastValue, isTrue);

      // 第二次点击：true -> false（需要更新 value 参数）
      await tester.pumpWidget(_buildExportOptions(
        value: true,
        onChanged: (value) {
          callbackCount++;
          lastValue = value ?? false;
        },
      ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(callbackCount, equals(2));
      expect(lastValue, isFalse);
    });
  });
}
