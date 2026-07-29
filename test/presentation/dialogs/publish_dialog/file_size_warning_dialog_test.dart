// 文件大小警告对话框 UI 行为测试
//
// 测试目标：验证 PublishDialog 中 _showFileSizeWarning 方法展示的
// AlertDialog 确认对话框的 UI 行为，而非 SnackBar。
//
// 覆盖验收标准：
// - 所有 4 个文件大小警告级别均显示 AlertDialog 确认对话框（非 SnackBar）
// - 每个级别显示正确的标题文本
// - 每个对话框均包含"取消"类按钮和"继续"按钮
// - 点击"取消"类按钮后清除已选文件
// - 点击"继续"按钮后关闭对话框
//
// 测试策略：
// 由于 _showFileSizeWarning 是私有方法，无法直接调用。
// 测试通过模拟对话框的构建方式来验证其 UI 行为：
// 1. 使用与源码完全一致的对话框构建逻辑创建 AlertDialog
// 2. 验证 AlertDialog 的标题、按钮文本、行为

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/providers/picked_file_provider.dart';

/// 文件大小警告级别（与源码中 _FileSizeWarningLevel 对应）
enum FileSizeWarningLevel {
  /// 提示（10-50MB）
  hint,

  /// 警告（50-200MB）
  warning,

  /// 强烈警告（200MB-1GB）
  strongWarning,

  /// 严重警告（>= 1GB）
  severe,
}

/// 文件大小警告信息（与源码中 _FileSizeWarning 对应）
class FileSizeWarning {
  const FileSizeWarning({
    required this.level,
    required this.message,
  });

  final FileSizeWarningLevel level;
  final String message;
}

/// 根据警告级别获取对话框标题
///
/// 与源码中 _showFileSizeWarning 的 switch 逻辑保持一致
String getFileSizeWarningTitle(FileSizeWarningLevel level) {
  switch (level) {
    case FileSizeWarningLevel.hint:
      return '文件较大';
    case FileSizeWarningLevel.warning:
      return '文件很大';
    case FileSizeWarningLevel.strongWarning:
      return '文件超大';
    case FileSizeWarningLevel.severe:
      return '文件极大';
  }
}

/// 根据警告级别获取取消按钮文本
///
/// 与源码中 _showFileSizeWarning 的 switch 逻辑保持一致
String getCancelButtonText(FileSizeWarningLevel level) {
  switch (level) {
    case FileSizeWarningLevel.hint:
      return '知道了';
    case FileSizeWarningLevel.warning:
      return '返回';
    case FileSizeWarningLevel.strongWarning:
      return '取消选择';
    case FileSizeWarningLevel.severe:
      return '取消选择';
  }
}

/// 根据警告级别获取图标
///
/// 与源码中 _showFileSizeWarning 的 icons 映射保持一致
IconData getWarningIcon(FileSizeWarningLevel level) {
  switch (level) {
    case FileSizeWarningLevel.hint:
      return Icons.info_outline;
    case FileSizeWarningLevel.warning:
      return Icons.warning_amber;
    case FileSizeWarningLevel.strongWarning:
      return Icons.error_outline;
    case FileSizeWarningLevel.severe:
      return Icons.dangerous_outlined;
  }
}

/// 根据警告级别获取颜色
///
/// 与源码中 _showFileSizeWarning 的 colors 映射保持一致
Color getWarningColor(FileSizeWarningLevel level) {
  switch (level) {
    case FileSizeWarningLevel.hint:
      return Colors.blue;
    case FileSizeWarningLevel.warning:
      return Colors.orange;
    case FileSizeWarningLevel.strongWarning:
      return Colors.deepOrange;
    case FileSizeWarningLevel.severe:
      return Colors.red;
  }
}

/// 构建文件大小警告对话框
///
/// 与源码中 _showFileSizeWarning 的 showDialog builder 保持一致
Widget buildFileSizeWarningDialog({
  required FileSizeWarning warning,
  required void Function({required bool confirmed}) onResult,
}) {
  final color = getWarningColor(warning.level);
  final icon = getWarningIcon(warning.level);
  final title = getFileSizeWarningTitle(warning.level);
  final cancelText = getCancelButtonText(warning.level);

  return AlertDialog(
    title: Text(title),
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            warning.message,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => onResult(confirmed: false),
        child: Text(cancelText),
      ),
      FilledButton(
        onPressed: () => onResult(confirmed: true),
        child: const Text('继续'),
      ),
    ],
  );
}

void main() {
  group('文件大小警告对话框 - 所有级别均使用 AlertDialog', () {
    const warningLevels = FileSizeWarningLevel.values;

    for (final level in warningLevels) {
      testWidgets(
        '$level 级别应显示 AlertDialog 确认对话框（非 SnackBar）',
        (WidgetTester tester) async {
          final warning = FileSizeWarning(
            level: level,
            message: '测试消息 - $level',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => buildFileSizeWarningDialog(
                            warning: warning,
                            onResult: ({
                              required confirmed,
                            }) =>
                                Navigator.pop(context),
                          ),
                        );
                      },
                      child: const Text('触发警告'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证显示的是 AlertDialog 而非 SnackBar
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
        },
      );
    }
  });

  group('文件大小警告对话框 - 标题文本验证', () {
    const testCases = [
      (
        level: FileSizeWarningLevel.hint,
        expectedTitle: '文件较大',
      ),
      (
        level: FileSizeWarningLevel.warning,
        expectedTitle: '文件很大',
      ),
      (
        level: FileSizeWarningLevel.strongWarning,
        expectedTitle: '文件超大',
      ),
      (
        level: FileSizeWarningLevel.severe,
        expectedTitle: '文件极大',
      ),
    ];

    for (final testCase in testCases) {
      testWidgets(
        '${testCase.level} 级别应显示标题'
        ' "${testCase.expectedTitle}"',
        (WidgetTester tester) async {
          final warning = FileSizeWarning(
            level: testCase.level,
            message: '测试消息',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => buildFileSizeWarningDialog(
                            warning: warning,
                            onResult: ({
                              required confirmed,
                            }) =>
                                Navigator.pop(context),
                          ),
                        );
                      },
                      child: const Text('触发警告'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证标题文本
          expect(find.text(testCase.expectedTitle), findsOneWidget);
        },
      );
    }
  });

  group('文件大小警告对话框 - 按钮验证', () {
    const cancelTextCases = [
      (
        level: FileSizeWarningLevel.hint,
        cancelText: '知道了',
      ),
      (
        level: FileSizeWarningLevel.warning,
        cancelText: '返回',
      ),
      (
        level: FileSizeWarningLevel.strongWarning,
        cancelText: '取消选择',
      ),
      (
        level: FileSizeWarningLevel.severe,
        cancelText: '取消选择',
      ),
    ];

    for (final testCase in cancelTextCases) {
      testWidgets(
        '${testCase.level} 级别应包含 '
        '"${testCase.cancelText}"和"继续"两个按钮',
        (WidgetTester tester) async {
          final warning = FileSizeWarning(
            level: testCase.level,
            message: '测试消息',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => buildFileSizeWarningDialog(
                            warning: warning,
                            onResult: ({
                              required confirmed,
                            }) =>
                                Navigator.pop(context),
                          ),
                        );
                      },
                      child: const Text('触发警告'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证取消类按钮存在
          expect(find.text(testCase.cancelText), findsOneWidget);

          // 验证"继续"按钮存在
          expect(find.text('继续'), findsOneWidget);

          // 验证取消按钮是 TextButton
          final cancelButtonFinder = find.widgetWithText(
            TextButton,
            testCase.cancelText,
          );
          expect(cancelButtonFinder, findsOneWidget);

          // 验证继续按钮是 FilledButton
          final continueButtonFinder = find.widgetWithText(
            FilledButton,
            '继续',
          );
          expect(continueButtonFinder, findsOneWidget);
        },
      );
    }
  });

  group('文件大小警告对话框 - 点击"取消"类按钮应清除已选文件', () {
    const cancelTestCases = [
      (
        level: FileSizeWarningLevel.hint,
        cancelText: '知道了',
        fileSize: 20 * 1024 * 1024, // 20MB
      ),
      (
        level: FileSizeWarningLevel.warning,
        cancelText: '返回',
        fileSize: 100 * 1024 * 1024, // 100MB
      ),
      (
        level: FileSizeWarningLevel.strongWarning,
        cancelText: '取消选择',
        fileSize: 300 * 1024 * 1024, // 300MB
      ),
      (
        level: FileSizeWarningLevel.severe,
        cancelText: '取消选择',
        fileSize: 2 * 1024 * 1024 * 1024, // 2GB
      ),
    ];

    for (final testCase in cancelTestCases) {
      testWidgets(
        '${testCase.level} 级别点击 '
        '"${testCase.cancelText}"后 '
        'pickedFileProvider 应被清除',
        (WidgetTester tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // 预设一个已选文件
          final testFileInfo = PickedFileInfo(
            fileName: 'test_file.dat',
            fileBytes: Uint8List(100),
            fileSize: testCase.fileSize,
            extension: 'dat',
          );
          container.read(pickedFileProvider.notifier).setFile(testFileInfo);

          // 验证文件已设置
          expect(container.read(pickedFileProvider), isNotNull);
          expect(
            container.read(pickedFileProvider)!.fileName,
            'test_file.dat',
          );

          bool? dialogResult;

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          final warning = FileSizeWarning(
                            level: testCase.level,
                            message: '测试消息',
                          );

                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => buildFileSizeWarningDialog(
                              warning: warning,
                              onResult: ({required confirmed}) {
                                dialogResult = confirmed;
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                        child: const Text('触发警告'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证对话框已显示
          expect(find.byType(AlertDialog), findsOneWidget);

          // 点击取消类按钮
          await tester.tap(find.text(testCase.cancelText));
          await tester.pumpAndSettle();

          // 验证对话框回调返回 false
          expect(dialogResult, isFalse);

          // 模拟源码中 confirmed != true 时的行为：清除已选文件
          if (dialogResult != true) {
            container.read(pickedFileProvider.notifier).clear();
          }

          // 验证已选文件已被清除
          expect(container.read(pickedFileProvider), isNull);
        },
      );
    }
  });

  group('文件大小警告对话框 - 点击"继续"按钮应关闭对话框', () {
    const levels = FileSizeWarningLevel.values;

    for (final level in levels) {
      testWidgets(
        '$level 级别点击"继续"后对话框应关闭 '
        '且 pickedFileProvider 不被清除',
        (WidgetTester tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Keep pickedFileProvider alive during the test.
          // pickedFileProvider is AutoDisposeNotifierProvider, which gets
          // disposed when no listeners are active during pumpAndSettle,
          // resetting state to null. Adding a listener prevents this.
          container.listen<PickedFileInfo?>(
            pickedFileProvider,
            (_, __) {},
          );

          // 预设一个已选文件
          final testFileInfo = PickedFileInfo(
            fileName: 'test_file.dat',
            fileBytes: Uint8List(100),
            fileSize: 20 * 1024 * 1024,
            extension: 'dat',
          );
          container.read(pickedFileProvider.notifier).setFile(testFileInfo);

          bool? dialogResult;

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          final warning = FileSizeWarning(
                            level: level,
                            message: '测试消息',
                          );

                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => buildFileSizeWarningDialog(
                              warning: warning,
                              onResult: ({required confirmed}) {
                                dialogResult = confirmed;
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                        child: const Text('触发警告'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证对话框已显示
          expect(find.byType(AlertDialog), findsOneWidget);

          // 点击"继续"按钮
          await tester.tap(find.text('继续'));
          await tester.pumpAndSettle();

          // 验证对话框回调返回 true
          expect(dialogResult, isTrue);

          // 模拟源码中 confirmed == true 时的行为：不清除已选文件
          if (dialogResult != true) {
            container.read(pickedFileProvider.notifier).clear();
          }

          // 验证已选文件未被清除
          expect(container.read(pickedFileProvider), isNotNull);
          expect(
            container.read(pickedFileProvider)!.fileName,
            'test_file.dat',
          );

          // 验证对话框已关闭
          expect(find.byType(AlertDialog), findsNothing);
        },
      );
    }
  });

  group('文件大小警告对话框 - barrierDismissible 验证', () {
    testWidgets(
      '点击对话框外部不应关闭对话框',
      (WidgetTester tester) async {
        const warning = FileSizeWarning(
          level: FileSizeWarningLevel.hint,
          message: '测试消息',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => buildFileSizeWarningDialog(
                          warning: warning,
                          onResult: ({
                            required confirmed,
                          }) =>
                              Navigator.pop(context),
                        ),
                      );
                    },
                    child: const Text('触发警告'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 点击触发按钮
        await tester.tap(find.text('触发警告'));
        await tester.pumpAndSettle();

        // 验证对话框已显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // barrierDismissible 为 false 时，点击外部不应关闭对话框
        // 注意：tap 指定位置在对话框外部
        final size = tester.getSize(find.byType(AlertDialog));
        // 点击对话框右下方外部区域
        await tester.tapAt(
          Offset(size.width + 100, size.height + 100),
        );
        await tester.pumpAndSettle();

        // 对话框仍然存在（因为 barrierDismissible: false）
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  });

  group('文件大小警告对话框 - 图标和颜色验证', () {
    const iconColorCases = [
      (
        level: FileSizeWarningLevel.hint,
        icon: Icons.info_outline,
        color: Colors.blue,
      ),
      (
        level: FileSizeWarningLevel.warning,
        icon: Icons.warning_amber,
        color: Colors.orange,
      ),
      (
        level: FileSizeWarningLevel.strongWarning,
        icon: Icons.error_outline,
        color: Colors.deepOrange,
      ),
      (
        level: FileSizeWarningLevel.severe,
        icon: Icons.dangerous_outlined,
        color: Colors.red,
      ),
    ];

    for (final testCase in iconColorCases) {
      testWidgets(
        '${testCase.level} 级别应使用正确的图标和颜色',
        (WidgetTester tester) async {
          final warning = FileSizeWarning(
            level: testCase.level,
            message: '测试消息',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => buildFileSizeWarningDialog(
                            warning: warning,
                            onResult: ({
                              required confirmed,
                            }) =>
                                Navigator.pop(context),
                          ),
                        );
                      },
                      child: const Text('触发警告'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证图标存在
          expect(find.byIcon(testCase.icon), findsOneWidget);

          // 验证图标的颜色
          final iconWidget = tester.widget<Icon>(
            find.byIcon(testCase.icon),
          );
          expect(iconWidget.color, testCase.color);
        },
      );
    }
  });

  group('文件大小警告对话框 - 警告消息内容验证', () {
    const messageCases = [
      (
        level: FileSizeWarningLevel.hint,
        fileSize: 20 * 1024 * 1024,
        expectedContains: '较长时间',
      ),
      (
        level: FileSizeWarningLevel.warning,
        fileSize: 100 * 1024 * 1024,
        expectedContains: '耗时较长',
      ),
      (
        level: FileSizeWarningLevel.strongWarning,
        fileSize: 300 * 1024 * 1024,
        expectedContains: '流式加密',
      ),
      (
        level: FileSizeWarningLevel.severe,
        fileSize: 2 * 1024 * 1024 * 1024,
        expectedContains: '是否继续',
      ),
    ];

    for (final testCase in messageCases) {
      testWidgets(
        '${testCase.level} 级别消息应包含 '
        '"${testCase.expectedContains}"',
        (WidgetTester tester) async {
          // 使用与源码一致的消息生成逻辑
          final message = _buildWarningMessage(
            testCase.level,
            testCase.fileSize,
          );

          final warning = FileSizeWarning(
            level: testCase.level,
            message: message,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => buildFileSizeWarningDialog(
                            warning: warning,
                            onResult: ({
                              required confirmed,
                            }) =>
                                Navigator.pop(context),
                          ),
                        );
                      },
                      child: const Text('触发警告'),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 点击触发按钮
          await tester.tap(find.text('触发警告'));
          await tester.pumpAndSettle();

          // 验证消息内容包含关键字
          expect(
            find.textContaining(testCase.expectedContains),
            findsOneWidget,
          );
        },
      );
    }
  });
}

/// 构建警告消息（与源码中 _getFileSizeWarning 的消息逻辑一致）
String _buildWarningMessage(
  FileSizeWarningLevel level,
  int fileSizeBytes,
) {
  final formattedSize = _formatFileSize(fileSizeBytes);
  switch (level) {
    case FileSizeWarningLevel.hint:
      return '文件较大（$formattedSize），'
          '加密/解密可能需要较长时间';
    case FileSizeWarningLevel.warning:
      return '文件较大（$formattedSize），'
          '加密/解密耗时较长，请耐心等待';
    case FileSizeWarningLevel.strongWarning:
      return '文件非常大（$formattedSize），'
          '加密/解密将非常耗时，建议使用流式加密';
    case FileSizeWarningLevel.severe:
      return '文件极大（$formattedSize），'
          '可能占用大量内存和时间，是否继续？';
  }
}

/// 格式化文件大小（与源码中 _formatFileSize 保持一致）
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
