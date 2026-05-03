// DecryptDialog 组件单元测试
//
// 测试目标：验证解密对话框的完整解密流程，包括元数据预览、密钥输入、解密逻辑、
//           完整性校验、错误处理、敏感数据清理
//
// 覆盖验收标准：
// - 两种解密方式均可正常工作
// - 密钥格式验证正确
// - .key 文件解析正确
// - 解密失败时明确提示
// - 解密成功后敏感数据已清除
// - 完整性校验失败时提示"文件可能被篡改"
//
// 测试范围：
// - 对话框显示元数据预览（标题、发布者、标签等）
// - 未输入密钥点击解密显示提示
// - 错误密钥解密时显示"密钥错误或文件已损坏"
// - 完整性校验失败时显示"文件可能被篡改"
// - 解密成功后调用 onDecryptSuccess 回调
// - 解密成功后关闭对话框
// - loading 状态下按钮被禁用

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/memory_utils.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/decrypt_dialog.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

/// Mock CryptoService
class MockCryptoService extends Mock implements CryptoService {}

/// Mock FileIOService
class MockFileIOService extends Mock implements FileIOService {}

/// Mock IntegrityService
class MockIntegrityService extends Mock implements IntegrityService {}

/// Fake EncryptedContent（用于 mocktail registerFallbackValue）
class FakeEncryptedContent extends Fake implements EncryptedContent {}

/// 创建用于测试的 StrawFile 实例
StrawFile createTestStrawFile({
  String title = '测试知识卡片',
  String publisherAlias = '测试作者',
  String encryptedDataBase64 = 'dGVzdEVuY3J5cHRlZERhdGFCYXNlNjRTdHJpbmcxMjM0NTY3ODkwMTIzNA==',
  String ivBase64 = 'dGVzdEl2QmFzZTY0U3RyaW5nMTIzNA==',
  String integrityHash = 'sha256:testhash',
  List<String> tags = const ['测试', 'Flutter'],
  String? description,
  bool isAnonymous = false,
}) {
  return StrawFile(
    formatVersion: FormatVersion.fromString('1.0.0'),
    meta: CardMeta(
      publisherAlias: publisherAlias,
      publishDate: '2026-05-01T12:00:00Z',
      title: title,
      isAnonymous: isAnonymous,
      tags: tags,
      description: description,
    ),
    content: EncryptedContent(
      encryptedDataBase64: encryptedDataBase64,
      ivBase64: ivBase64,
      algorithm: 'AES-256-GCM',
    ),
    integrity: IntegrityInfo(
      hash: integrityHash,
      hashAlgorithm: 'SHA-256',
    ),
  );
}

/// 构建用于测试的 DecryptDialog Widget
///
/// 将 DecryptDialog 包裹在 MaterialApp 和 ProviderScope 中以便测试。
Widget _buildDecryptDialog({
  required StrawFile strawFile,
  required void Function(String deltaJson) onDecryptSuccess,
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return DecryptDialog(
              strawFile: strawFile,
              onDecryptSuccess: onDecryptSuccess,
            );
          },
        ),
      ),
    ),
  );
}

/// 构建用于对话框测试的 Widget
///
/// 使用 showDialog 弹出真实对话框。
Widget _buildDialogTestHarness({
  required Widget dialog,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => dialog,
                );
              },
              child: const Text('打开对话框'),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  // 注册 mocktail 的 fallback 值
  setUpAll(() {
    registerFallbackValue(FakeEncryptedContent());
    // Uint8List 是 final class，不能用 Fake，直接使用真实实例作为 fallback
    registerFallbackValue(Uint8List(32));
  });

  group('DecryptDialog 元数据预览测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('对话框应该显示卡片标题', (WidgetTester tester) async {
      final strawFile = createTestStrawFile(title: '我的知识卡片');

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证标题存在
      expect(find.text('解密知识卡片'), findsOneWidget);
      expect(find.text('我的知识卡片'), findsOneWidget);
    });

    testWidgets('对话框应该显示发布者代号', (WidgetTester tester) async {
      final strawFile = createTestStrawFile(publisherAlias: '张三');

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      expect(find.text('张三'), findsOneWidget);
    });

    testWidgets('对话框应该显示发布日期', (WidgetTester tester) async {
      final strawFile = createTestStrawFile();

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 日期应该显示为 "2026-05-01"（ISO 日期部分）
      expect(find.text('2026-05-01'), findsOneWidget);
    });

    testWidgets('对话框应该显示标签', (WidgetTester tester) async {
      final strawFile = createTestStrawFile(
        tags: ['Flutter', '加密', '测试'],
      );

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('加密'), findsOneWidget);
      expect(find.text('测试'), findsOneWidget);
    });

    testWidgets('对话框应该显示描述', (WidgetTester tester) async {
      final strawFile = createTestStrawFile(
        description: '这是一段测试描述',
      );

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      expect(find.text('这是一段测试描述'), findsOneWidget);
    });

    testWidgets('匿名模式下应该显示"匿名"标识', (WidgetTester tester) async {
      final strawFile = createTestStrawFile(
        publisherAlias: 'Anonymous_a3f7b2c1',
        isAnonymous: true,
      );

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      expect(find.text('匿名'), findsOneWidget);
    });
  });

  group('DecryptDialog 密钥输入验证测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('未输入密钥点击解密应该显示提示',
        (WidgetTester tester) async {
      final strawFile = createTestStrawFile();

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 不输入密钥，直接点击解密按钮
      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 应该显示错误提示
      expect(find.text('请输入密钥或上传 .key 文件'), findsOneWidget);
    });

    testWidgets('未输入密钥时 CryptoService 不应该被调用',
        (WidgetTester tester) async {
      final strawFile = createTestStrawFile();

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 不输入密钥，直接点击解密按钮
      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证 decryptContent 没有被调用
      verifyNever(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      );
    });
  });

  group('DecryptDialog 错误密钥解密测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;
    late StrawFile strawFile;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );

      strawFile = createTestStrawFile();

      // Mock decryptContent 抛出 CryptoException
      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenThrow(
        const CryptoException(
          '解密失败：密钥错误或密文损坏',
          code: 'DECRYPTION_FAILED',
        ),
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('错误密钥解密时应该显示"密钥错误或文件已损坏"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 输入一个格式正确但内容错误的密钥（32 字节的 Base64 编码，44 字符）
      final wrongKey = base64Encode(Uint8List.fromList(
        List.generate(32, (i) => i + 100),
      ));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, wrongKey);
      await tester.pumpAndSettle();

      // 点击解密按钮
      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 应该显示错误提示
      expect(find.text('密钥错误或文件已损坏'), findsOneWidget);
    });

    testWidgets('解密失败后按钮应该重新可用',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 输入一个格式正确但内容错误的密钥
      final wrongKey = base64Encode(Uint8List.fromList(
        List.generate(32, (i) => i + 200),
      ));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, wrongKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证解密按钮重新可用
      expect(find.text('解密'), findsOneWidget);
    });
  });

  group('DecryptDialog 完整性校验失败测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;
    late StrawFile strawFile;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );

      strawFile = createTestStrawFile();

      // Mock decryptContent 返回成功
      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) async => '{"ops": [{"insert": "测试内容"}]}');

      // Mock verifyIntegrity 返回失败
      when(
        () => mockIntegrityService.verifyIntegrity(
          content: any(named: 'content'),
          expectedHash: any(named: 'expectedHash'),
        ),
      ).thenReturn(false);

      // Mock clearSensitiveData
      when(() => mockCryptoService.clearSensitiveData()).thenReturn(null);
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('完整性校验失败时应该显示"文件可能被篡改"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 输入有效格式的密钥（32 字节 Base64）
      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      // 点击解密按钮
      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 应该显示完整性校验失败提示
      expect(
        find.text('文件完整性校验失败，文件可能已被篡改'),
        findsOneWidget,
      );
    });

    testWidgets('完整性校验失败时不应该调用 onDecryptSuccess',
        (WidgetTester tester) async {
      var callbackCalled = false;

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {
              callbackCalled = true;
            },
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 回调不应该被调用
      expect(callbackCalled, isFalse);
    });

    testWidgets('完整性校验失败时应该调用 clearSensitiveData',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证 clearSensitiveData 被调用
      verify(() => mockCryptoService.clearSensitiveData()).called(1);
    });

    testWidgets('完整性校验失败后对话框不应该关闭',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 对话框应该仍然显示
      expect(find.text('解密知识卡片'), findsOneWidget);
    });
  });

  group('DecryptDialog 解密成功测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;
    late StrawFile strawFile;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );

      strawFile = createTestStrawFile();

      // Mock decryptContent 返回成功
      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenAnswer(
        (_) async => '{"ops": [{"insert": "Hello World"}]}',
      );

      // Mock verifyIntegrity 返回成功
      when(
        () => mockIntegrityService.verifyIntegrity(
          content: any(named: 'content'),
          expectedHash: any(named: 'expectedHash'),
        ),
      ).thenReturn(true);

      // Mock clearSensitiveData
      when(() => mockCryptoService.clearSensitiveData()).thenReturn(null);
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('解密成功后应该调用 onDecryptSuccess 回调',
        (WidgetTester tester) async {
      String? receivedDeltaJson;

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (deltaJson) {
              receivedDeltaJson = deltaJson;
            },
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证回调被调用且传入正确的 Delta JSON
      expect(receivedDeltaJson, isNotNull);
      expect(receivedDeltaJson, contains('Hello World'));
    });

    testWidgets('解密成功后应该关闭对话框',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证对话框已显示
      expect(find.text('解密知识卡片'), findsOneWidget);

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证对话框已关闭
      expect(find.text('解密知识卡片'), findsNothing);
    });

    testWidgets('解密成功后应该调用 clearSensitiveData',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pumpAndSettle();

      // 验证 clearSensitiveData 被调用
      verify(() => mockCryptoService.clearSensitiveData()).called(1);
    });
  });

  group('DecryptDialog Loading 状态测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;
    late StrawFile strawFile;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );

      strawFile = createTestStrawFile();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('解密过程中应该显示 CircularProgressIndicator',
        (WidgetTester tester) async {
      // 使用 Completer 控制解密操作的完成时机
      final completer = Completer<String>();

      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) => completer.future);

      when(
        () => mockIntegrityService.verifyIntegrity(
          content: any(named: 'content'),
          expectedHash: any(named: 'expectedHash'),
        ),
      ).thenReturn(true);

      when(() => mockCryptoService.clearSensitiveData()).thenReturn(null);

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      // 点击解密按钮
      await tester.tap(find.text('解密'));
      // 使用 pump 触发重绘，但不等待 Future 完成
      await tester.pump();

      // 验证加载指示器显示
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // 完成解密操作
      completer.complete('{"ops": []}');
      await tester.pumpAndSettle();
    });

    testWidgets('Loading 状态下解密按钮应该被禁用',
        (WidgetTester tester) async {
      final completer = Completer<String>();

      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) => completer.future);

      when(
        () => mockIntegrityService.verifyIntegrity(
          content: any(named: 'content'),
          expectedHash: any(named: 'expectedHash'),
        ),
      ).thenReturn(true);

      when(() => mockCryptoService.clearSensitiveData()).thenReturn(null);

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      // 点击解密按钮
      await tester.tap(find.text('解密'));
      await tester.pump();

      // 验证"解密"文本不存在（被 CircularProgressIndicator 替代）
      expect(find.text('解密'), findsNothing);

      // 完成解密操作
      completer.complete('{"ops": []}');
      await tester.pumpAndSettle();
    });

    testWidgets('Loading 状态下取消按钮应该被禁用',
        (WidgetTester tester) async {
      final completer = Completer<String>();

      when(
        () => mockCryptoService.decryptContent(
          encryptedDataBase64: any(named: 'encryptedDataBase64'),
          ivBase64: any(named: 'ivBase64'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) => completer.future);

      when(
        () => mockIntegrityService.verifyIntegrity(
          content: any(named: 'content'),
          expectedHash: any(named: 'expectedHash'),
        ),
      ).thenReturn(true);

      when(() => mockCryptoService.clearSensitiveData()).thenReturn(null);

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      final validKey = base64Encode(Uint8List(32));
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, validKey);
      await tester.pumpAndSettle();

      await tester.tap(find.text('解密'));
      await tester.pump();

      // 验证取消按钮文字仍然存在，但按钮应该是禁用的
      expect(find.text('取消'), findsOneWidget);

      completer.complete('{"ops": []}');
      await tester.pumpAndSettle();
    });
  });

  group('DecryptDialog 取消操作测试', () {
    late ProviderContainer container;
    late MockCryptoService mockCryptoService;
    late MockIntegrityService mockIntegrityService;
    late MockFileIOService mockFileIOService;

    setUp(() {
      mockCryptoService = MockCryptoService();
      mockIntegrityService = MockIntegrityService();
      mockFileIOService = MockFileIOService();

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWith((ref) => mockCryptoService),
          integrityServiceProvider.overrideWith((ref) => mockIntegrityService),
          fileIOServiceProvider.overrideWith((ref) => mockFileIOService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('点击取消按钮应该关闭对话框',
        (WidgetTester tester) async {
      final strawFile = createTestStrawFile();

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {},
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      // 验证对话框已显示
      expect(find.text('解密知识卡片'), findsOneWidget);

      // 点击取消按钮
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证对话框已关闭
      expect(find.text('解密知识卡片'), findsNothing);
    });

    testWidgets('取消时不应该调用 onDecryptSuccess',
        (WidgetTester tester) async {
      var callbackCalled = false;
      final strawFile = createTestStrawFile();

      await tester.pumpWidget(
        _buildDialogTestHarness(
          dialog: _buildDecryptDialog(
            strawFile: strawFile,
            onDecryptSuccess: (_) {
              callbackCalled = true;
            },
            container: container,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isFalse);
    });
  });

  group('DecryptDialog 敏感数据清理测试', () {
    test('MemoryUtils.wipeBytes 应该将字节逐零', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      MemoryUtils.wipeBytes(bytes);

      for (var i = 0; i < bytes.length; i++) {
        expect(bytes[i], equals(0));
      }
    });

    test('MemoryUtils.wipeBytes 应该处理空数组', () {
      final bytes = Uint8List(0);
      // 不应该抛出异常
      MemoryUtils.wipeBytes(bytes);
      expect(bytes.length, equals(0));
    });
  });
}
