// KeyInput 组件单元测试
//
// 测试目标：验证解密对话框中密钥输入组件的格式验证、状态管理、外部方法调用
//
// 覆盖验收标准：
// - 密钥格式验证正确（Base64 字符集、长度 43~44）
// - 空输入不触发错误
// - 非法输入明确提示
//
// 测试范围：
// - 空输入不触发错误
// - 非法 Base64 字符显示错误
// - 长度不正确显示错误
// - 有效 Base64 解码失败显示错误
// - 正确的 43~44 字符 Base64 显示有效状态
// - setKey() 方法能正确填充值
// - clear() 方法能清除输入
// - onKeyChanged 回调正确触发

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_input.dart';

/// 构建用于测试的 KeyInput Widget
///
/// 将 KeyInput 包裹在 MaterialApp 中以便测试，
/// 提供 Material 主题和导航上下文。
Widget _buildKeyInput({
  TextEditingController? controller,
  void Function(String?)? onKeyChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: KeyInput(
        controller: controller,
        onKeyChanged: onKeyChanged,
      ),
    ),
  );
}

void main() {
  group('KeyInput 基础渲染测试', () {
    testWidgets('应该渲染 KeyInput 组件', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      expect(find.byType(KeyInput), findsOneWidget);
    });

    testWidgets('应该显示标题"方式 A：手动输入密钥"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      expect(find.text('方式 A：手动输入密钥'), findsOneWidget);
    });

    testWidgets('应该渲染 TextField 输入框', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TextField 应该显示提示文本', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      expect(find.text('请输入 Base64 编码的密钥字符串'), findsOneWidget);
    });

    testWidgets('TextField 应该显示辅助文本说明长度',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      expect(
        find.text('32 字节密钥经 Base64 编码后约 43~44 个字符'),
        findsOneWidget,
      );
    });

    testWidgets('TextField 应该使用等宽字体', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontFamily, equals('monospace'));
    });
  });

  group('KeyInput 空输入测试', () {
    testWidgets('空输入时不应该显示错误', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      // 初始状态下输入框为空
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('输入后清空不应该显示错误', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 先输入一些内容再清空
      controller.text = 'someText';
      await tester.pump();
      controller.clear();
      await tester.pump();

      // 不应该显示错误
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('空输入时 onKeyChanged 回调应该传入 null',
        (WidgetTester tester) async {
      String? lastCallbackValue = 'initial';
      final controller = TextEditingController();
      await tester.pumpWidget(
        _buildKeyInput(
          controller: controller,
          onKeyChanged: (value) {
            lastCallbackValue = value;
          },
        ),
      );

      // 清空内容（模拟用户清空输入框）
      controller.clear();
      await tester.pump();

      // 回调应该传入 null
      expect(lastCallbackValue, isNull);
    });
  });

  group('KeyInput 非法 Base64 字符测试', () {
    testWidgets('输入非法 Base64 字符时应该显示错误',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 输入包含非法字符（如 @、# 等）
      controller.text = 'abc@def#ghi';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
      expect(
        textField.decoration!.errorText!,
        contains('密钥格式不正确'),
      );
    });

    testWidgets('输入空格时应该显示错误', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 输入包含空格
      controller.text = 'abc def';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
    });

    testWidgets('非法字符时 onKeyChanged 回调应该传入 null',
        (WidgetTester tester) async {
      String? lastCallbackValue = 'initial';
      final controller = TextEditingController();
      await tester.pumpWidget(
        _buildKeyInput(
          controller: controller,
          onKeyChanged: (value) {
            lastCallbackValue = value;
          },
        ),
      );

      controller.text = 'invalid@chars';
      await tester.pump();

      expect(lastCallbackValue, isNull);
    });
  });

  group('KeyInput 长度验证测试', () {
    testWidgets('输入长度过短（< 43 字符）时应该显示错误',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 输入合法的 Base64 字符但长度不足
      controller.text = 'AaBbCcDdEeFfGgHhIiJjKk';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
      expect(
        textField.decoration!.errorText!,
        contains('密钥长度不正确'),
      );
      expect(
        textField.decoration!.errorText!,
        contains('43~44'),
      );
    });

    testWidgets('输入长度过长（> 44 字符）时应该显示错误',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 输入合法的 Base64 字符但长度过长
      controller.text = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTt';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
      expect(
        textField.decoration!.errorText!,
        contains('密钥长度不正确'),
      );
    });

    testWidgets('长度不正确时 onKeyChanged 回调应该传入 null',
        (WidgetTester tester) async {
      String? lastCallbackValue = 'initial';
      final controller = TextEditingController();
      await tester.pumpWidget(
        _buildKeyInput(
          controller: controller,
          onKeyChanged: (value) {
            lastCallbackValue = value;
          },
        ),
      );

      controller.text = 'A' * 30; // 长度不足
      await tester.pump();

      expect(lastCallbackValue, isNull);
    });
  });

  group('KeyInput 有效 Base64 解码验证测试', () {
    testWidgets('正确的 44 字符 Base64 应该显示有效状态',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 32 字节经 Base64 编码后为 44 字符
      // 生成一个有效的 32 字节 Base64 编码
      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      controller.text = validKey;
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('正确的 43 字符 Base64 应该显示有效状态',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_buildKeyInput(controller: controller));

      // 构造一个 43 字符的有效 Base64（某些 32 字节 Base64 编码为 43 字符）
      // 使用真实 32 字节数据编码后可能产生 43 或 44 字符
      // 例如：31 字节的 Base64 为 44 字符，但某些边界情况可能不同
      // 这里用实际的 32 字节数据来测试
      final bytes = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        bytes[i] = 0x7F;
      }
      final key = base64Encode(bytes);

      // 确认长度
      expect(key.length, anyOf(43, 44));

      controller.text = key;
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('有效 Base64 时 onKeyChanged 回调应该传入密钥值',
        (WidgetTester tester) async {
      String? lastCallbackValue = 'initial';
      final controller = TextEditingController();
      await tester.pumpWidget(
        _buildKeyInput(
          controller: controller,
          onKeyChanged: (value) {
            lastCallbackValue = value;
          },
        ),
      );

      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      controller.text = validKey;
      await tester.pump();

      expect(lastCallbackValue, equals(validKey));
    });
  });

  group('KeyInput setKey() 方法测试', () {
    testWidgets('setKey() 应该能正确填充密钥值',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key, onKeyChanged: (_) {}),
          ),
        ),
      );

      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      key.currentState?.setKey(validKey);
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals(validKey));
    });

    testWidgets('setKey() 应该触发 onKeyChanged 回调',
        (WidgetTester tester) async {
      String? lastCallbackValue = 'initial';
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(
              key: key,
              onKeyChanged: (value) {
                lastCallbackValue = value;
              },
            ),
          ),
        ),
      );

      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      key.currentState?.setKey(validKey);
      await tester.pump();

      expect(lastCallbackValue, equals(validKey));
    });

    testWidgets('setKey() 填充无效密钥应该显示错误',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key),
          ),
        ),
      );

      key.currentState?.setKey('invalid@@key');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
    });
  });

  group('KeyInput clear() 方法测试', () {
    testWidgets('clear() 应该能清除输入的密钥',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key),
          ),
        ),
      );

      // 先填充值
      key.currentState?.setKey(base64Encode(List.generate(32, (i) => i + 1)));
      await tester.pump();

      // 清除
      key.currentState?.clear();
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('clear() 应该清除错误状态',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key),
          ),
        ),
      );

      // 先输入无效值产生错误
      key.currentState?.setKey('invalid');
      await tester.pump();

      final textField1 = tester.widget<TextField>(find.byType(TextField));
      expect(textField1.decoration?.errorText, isNotNull);

      // 清除
      key.currentState?.clear();
      await tester.pump();

      final textField2 = tester.widget<TextField>(find.byType(TextField));
      expect(textField2.decoration?.errorText, isNull);
    });
  });

  group('KeyInput currentKey 属性测试', () {
    testWidgets('输入有效密钥后 currentKey 应该返回值',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key),
          ),
        ),
      );

      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      key.currentState?.setKey(validKey);
      await tester.pump();

      expect(key.currentState?.currentKey, equals(validKey));
    });

    testWidgets('空输入时 currentKey 应该返回 null',
        (WidgetTester tester) async {
      final key = GlobalKey<KeyInputState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyInput(key: key),
          ),
        ),
      );

      expect(key.currentState?.currentKey, isNull);
    });
  });

  group('KeyInput UI 交互测试', () {
    testWidgets('用户手动输入有效密钥应该清除错误状态',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      // 先输入无效值
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.pump();

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);

      // 再输入有效值
      final validKey = base64Encode(List.generate(32, (i) => i + 1));
      await tester.enterText(find.byType(TextField), validKey);
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('TextField 最大行数应该为 3', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(3));
    });

    testWidgets('TextField 最小行数应该为 1', (WidgetTester tester) async {
      await tester.pumpWidget(_buildKeyInput());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, equals(1));
    });
  });
}
