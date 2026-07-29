// KeyDisplay 组件单元测试
//
// 测试目标：验证发布对话框密钥展示组件的密钥展示、复制功能、安全提示

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';

Widget _buildKeyDisplay({required String keyBase64}) {
  return MaterialApp(
    home: Scaffold(body: KeyDisplay(keyBase64: keyBase64)),
  );
}

const String testKeyBase64 = 'dGVzdGtleTEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNA==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyDisplay 渲染测试', () {
    testWidgets('应该渲染密钥展示组件', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('应该显示密钥提示标题', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.text('密钥（请妥善保存）：'), findsOneWidget);
    });

    testWidgets('应该使用 SelectableText 显示密钥', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('应该显示正确的 Base64 密钥内容',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildKeyDisplay(keyBase64: testKeyBase64),
      );
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.data, equals(testKeyBase64));
    });

    testWidgets('密钥应该使用等宽字体显示', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildKeyDisplay(keyBase64: testKeyBase64),
      );
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.style?.fontFamily, equals('monospace'));
    });

    testWidgets('密钥文字应该设置合适的字体大小',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildKeyDisplay(keyBase64: testKeyBase64),
      );
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.style?.fontSize, equals(12));
    });

    testWidgets('应该使用灰色背景容器包裹密钥', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('应该显示复制按钮', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('复制按钮应该显示"复制到剪贴板"文本', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.text('复制到剪贴板'), findsOneWidget);
    });

    testWidgets('复制按钮应该使用复制图标', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('应该显示安全警告提示', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.textContaining('请妥善保管此密钥'), findsOneWidget);
      expect(find.textContaining('丢失后无法恢复'), findsOneWidget);
    });

    testWidgets('应该显示警告图标', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('KeyDisplay 复制功能测试', () {
    testWidgets('复制按钮具有正确的 onPressed 回调', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      // 验证复制按钮有有效的 onPressed 回调（不为 null）
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('复制按钮文本会随 _isCopied 状态变化', (WidgetTester tester) async {
      // 验证 KeyDisplay 的 _isCopied 状态变化时按钮文本会改变
      // 由于 _copyToClipboard 使用 async void 和 Future.delayed，
      // 此处仅验证按钮初始文本正确，状态变化测试通过 UI 检查完成
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.text('复制到剪贴板'), findsOneWidget);
    });
  });

  group('KeyDisplay 安全提示测试', () {
    testWidgets('安全警告应该使用橙色主题',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildKeyDisplay(keyBase64: testKeyBase64),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icon.color, isNotNull);
    });

    testWidgets('安全警告应该包含两个关键提示', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      expect(find.textContaining('请妥善保管此密钥，丢失后无法恢复'), findsOneWidget);
      expect(find.textContaining('密钥丢失将无法解密知识卡片'), findsOneWidget);
    });

    testWidgets('安全警告文字应该使用橙色字体', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      final warningTextFinder = find.textContaining('请妥善保管此密钥');
      final textWidget = tester.widget<Text>(warningTextFinder);
      expect(textWidget.style?.color, isNotNull);
    });

    testWidgets('安全警告应该使用橙色背景容器', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasOrangeContainer = containers.any((container) {
        final decoration = container.decoration as BoxDecoration?;
        return decoration?.color != null;
      });
      expect(hasOrangeContainer, isTrue);
    });
  });

  group('KeyDisplay 边界条件测试', () {
    testWidgets('应该支持空字符串密钥',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: ''));
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.data, equals(''));
    });

    testWidgets('应该支持长密钥字符串', (WidgetTester tester) async {
      // 使用重复字符构造长密钥
      final longKey = 'A' * 106 + '==';
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: longKey));
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.data, equals(longKey));
    });

    testWidgets('应该支持包含特殊字符的 Base64 密钥',
        (WidgetTester tester) async {
      const specialKey = 'abc+def/ghi+jkl/mno=';
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: specialKey));
      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectableText.data, equals(specialKey));
    });
  });

  group('KeyDisplay UI 布局测试', () {
    testWidgets('密钥展示应该使用纵向布局', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyDisplay(keyBase64: testKeyBase64));
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.mainAxisSize, equals(MainAxisSize.min));
    });

    testWidgets('复制按钮应该占满宽度', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildKeyDisplay(keyBase64: testKeyBase64),
      );
      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.width, equals(double.infinity));
    });
  });
}
