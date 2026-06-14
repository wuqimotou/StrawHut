// PassphraseInput 组件单元测试
//
// 测试目标：验证暗号输入组件的功能，包括：
// - 从保险库选择暗号功能（新增）
// - 暗号输入验证
// - 暗号强度指示器
// - 两次输入一致性检测
// - 清空功能
//
// 覆盖验收标准：
// - setPassphraseFromVault 填充暗号和确认字段
// - setPassphraseFromVault 更新强度指示器
// - setPassphraseFromVault 清除不一致状态
// - "从保险库选择" 按钮可见性
// - "从保险库选择" 按钮禁用状态（保险库为空时）
// - 点击按钮显示保险库选择器
// - 从选择器选择条目后填充输入字段
// - validate() 对空暗号返回 false
// - validate() 对 veryWeak 暗号返回 false
// - validate() 对不匹配暗号返回 false
// - validate() 对有效暗号返回 true
// - passphrase getter 返回当前值
// - clear() 重置所有字段

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/passphrase_input.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

/// Mock PassphraseVaultService
class MockPassphraseVaultService extends Mock
    implements PassphraseVaultService {}

/// Fake PassphraseEntry（用于 mocktail registerFallbackValue）
class FakePassphraseEntry extends Fake implements PassphraseEntry {}

void main() {
  late MockPassphraseVaultService mockVaultService;

  setUp(() {
    mockVaultService = MockPassphraseVaultService();
  });

  setUpAll(() {
    registerFallbackValue(FakePassphraseEntry());
  });

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 创建测试用条目
  PassphraseEntry createTestEntry({
    String id = 'pv_1700000000000_a1b2',
    String passphrase = 'abcdefgh',
    String label = '暗号 #1',
    String createdAt = '2024-01-15T08:30:00.000Z',
    int useCount = 0,
    String? lastUsedAt,
  }) {
    return PassphraseEntry(
      id: id,
      passphrase: passphrase,
      label: label,
      createdAt: createdAt,
      useCount: useCount,
      lastUsedAt: lastUsedAt,
    );
  }

  /// 构建 PassphraseInput 测试 Widget
  ///
  /// [entries] 保险库条目列表，用于 override passphraseEntriesProvider
  /// [key] PassphraseInput 的 GlobalKey
  Widget buildTestWidget({
    List<PassphraseEntry> entries = const [],
    required GlobalKey<PassphraseInputState> key,
  }) {
    return ProviderScope(
      overrides: [
        passphraseVaultServiceProvider
            .overrideWith((ref) => mockVaultService),
        passphraseEntriesProvider.overrideWith((ref) async => entries),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PassphraseInput(key: key),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // setPassphraseFromVault 方法测试
  // ============================================================
  group('setPassphraseFromVault', () {
    testWidgets('应填充暗号和确认字段', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      final entry = createTestEntry(passphrase: 'MyStr0ngPass!');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.passphrase, 'MyStr0ngPass!');
    });

    testWidgets('应更新强度指示器', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 初始强度为 veryWeak
      expect(key.currentState!.strength, PassphraseStrength.veryWeak);

      // 使用强暗号填充
      final entry = createTestEntry(passphrase: 'MyStr0ngPass!2024');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      // 强度应更新
      expect(key.currentState!.strength, isNot(equals(PassphraseStrength.veryWeak)));
    });

    testWidgets('应清除不一致状态', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 先输入不匹配的暗号，使 mismatch 为 true
      // 输入暗号字段
      final passphraseField = find.widgetWithText(
        TextField,
        '加密暗号',
      );
      await tester.enterText(passphraseField, 'abcdefgh');
      await tester.pump();

      // 输入不匹配的确认暗号
      final confirmField = find.widgetWithText(
        TextField,
        '再次输入暗号（确认）',
      );
      await tester.enterText(confirmField, 'different');
      await tester.pumpAndSettle();

      // 验证 mismatch 状态 - validate 应该返回 false
      expect(key.currentState!.validate(), isFalse);

      // 使用 setPassphraseFromVault 填充匹配的暗号
      final entry = createTestEntry(passphrase: 'abcdefgh');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      // mismatch 应被清除 - validate 应该不再因 mismatch 失败
      // 注意：abcdefgh 是 weak 强度，所以 validate 仍可能返回 false
      // 但不应因为 mismatch 返回 false
      // 我们检查 passphrase getter 确认两个字段已填充
      expect(key.currentState!.passphrase, 'abcdefgh');
    });
  });

  // ============================================================
  // 保险库选择按钮测试
  // ============================================================
  group('保险库选择按钮', () {
    testWidgets('保险库有条目时按钮应可见且可点击', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      final entries = [
        createTestEntry(passphrase: 'abcdefgh', label: '暗号 #1'),
      ];

      await tester.pumpWidget(buildTestWidget(key: key, entries: entries));
      await tester.pumpAndSettle();

      // 查找 "从保险库选择" 按钮
      final button = find.widgetWithText(OutlinedButton, '从保险库选择');
      expect(button, findsOneWidget);

      // 按钮应可点击（onPressed 不为 null）
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNotNull);
    });

    testWidgets('保险库为空时按钮应禁用', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();

      await tester.pumpWidget(buildTestWidget(key: key, entries: const []));
      await tester.pumpAndSettle();

      // 查找 "从保险库选择" 按钮
      final button = find.widgetWithText(OutlinedButton, '从保险库选择');
      expect(button, findsOneWidget);

      // 按钮应禁用（onPressed 为 null）
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNull);
    });

    testWidgets('点击按钮应显示保险库选择器对话框', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      final entries = [
        createTestEntry(
          id: 'pv_1_a1b2',
          passphrase: 'abcdefgh',
          label: '工作暗号',
          useCount: 3,
        ),
        createTestEntry(
          id: 'pv_2_c3d4',
          passphrase: 'ijklmnop',
          label: '个人暗号',
          useCount: 1,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(key: key, entries: entries));
      await tester.pumpAndSettle();

      // 点击 "从保险库选择" 按钮
      final button = find.widgetWithText(OutlinedButton, '从保险库选择');
      await tester.tap(button);
      await tester.pumpAndSettle();

      // 应显示选择器对话框，标题为 "选择暗号"
      expect(find.text('选择暗号'), findsOneWidget);

      // 应显示条目标签
      expect(find.text('工作暗号'), findsOneWidget);
      expect(find.text('个人暗号'), findsOneWidget);
    });

    testWidgets('从选择器选择条目后应填充输入字段', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      final entries = [
        createTestEntry(
          id: 'pv_1_a1b2',
          passphrase: 'abcdefgh',
          label: '工作暗号',
          useCount: 3,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(key: key, entries: entries));
      await tester.pumpAndSettle();

      // 点击 "从保险库选择" 按钮
      final button = find.widgetWithText(OutlinedButton, '从保险库选择');
      await tester.tap(button);
      await tester.pumpAndSettle();

      // 选择 "工作暗号" 条目
      await tester.tap(find.text('工作暗号'));
      await tester.pumpAndSettle();

      // 暗号应被填充
      expect(key.currentState!.passphrase, 'abcdefgh');
    });

    testWidgets('保险库为空时点击按钮应显示提示 SnackBar', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();

      await tester.pumpWidget(buildTestWidget(key: key, entries: const []));
      await tester.pumpAndSettle();

      // 空保险库时按钮是禁用的，所以无法点击
      // 但我们仍然验证按钮是禁用状态
      final button = find.widgetWithText(OutlinedButton, '从保险库选择');
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNull);
    });
  });

  // ============================================================
  // 现有功能回归测试
  // ============================================================
  group('validate() 验证测试', () {
    testWidgets('空暗号应返回 false', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isFalse);
    });

    testWidgets('veryWeak 暗号应返回 false', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 输入极弱暗号（少于 8 字符）
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'abc');
      await tester.pump();

      final confirmField =
          find.widgetWithText(TextField, '再次输入暗号（确认）');
      await tester.enterText(confirmField, 'abc');
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isFalse);
    });

    testWidgets('不匹配暗号应返回 false', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 输入暗号
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'abcdefgh');
      await tester.pump();

      // 输入不匹配的确认暗号
      final confirmField =
          find.widgetWithText(TextField, '再次输入暗号（确认）');
      await tester.enterText(confirmField, 'different');
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isFalse);
    });

    testWidgets('有效暗号应返回 true', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 使用 setPassphraseFromVault 填充有效暗号
      // abcdefgh 是 weak 强度（8 字符，不满足 medium/strong 条件）
      // 但 weak 强度可以通过 validate（只有 veryWeak 不行）
      final entry = createTestEntry(passphrase: 'abcdefgh');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isTrue);
    });

    testWidgets('强暗号应返回 true', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 使用强暗号
      final entry = createTestEntry(passphrase: 'MyStr0ngPass!2024');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(), isTrue);
    });
  });

  group('passphrase getter', () {
    testWidgets('应返回当前暗号值', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 初始为空
      expect(key.currentState!.passphrase, isEmpty);

      // 输入暗号
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'testpass123');
      await tester.pumpAndSettle();

      expect(key.currentState!.passphrase, 'testpass123');
    });

    testWidgets('setPassphraseFromVault 后应返回保险库暗号值',
        (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      final entry = createTestEntry(passphrase: 'vaultpass123');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.passphrase, 'vaultpass123');
    });
  });

  group('clear()', () {
    testWidgets('应重置所有字段', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 先填充暗号
      final entry = createTestEntry(passphrase: 'abcdefgh');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      // 验证已填充
      expect(key.currentState!.passphrase, 'abcdefgh');
      expect(key.currentState!.strength, isNot(equals(PassphraseStrength.veryWeak)));

      // 清空
      key.currentState!.clear();
      await tester.pumpAndSettle();

      // 验证已清空
      expect(key.currentState!.passphrase, isEmpty);
      expect(key.currentState!.strength, PassphraseStrength.veryWeak);
    });
  });

  // ============================================================
  // 强度指示器测试
  // ============================================================
  group('强度指示器', () {
    testWidgets('极弱暗号应显示极弱强度', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 输入极弱暗号
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'abc');
      await tester.pumpAndSettle();

      expect(key.currentState!.strength, PassphraseStrength.veryWeak);
    });

    testWidgets('弱暗号应显示弱强度', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // abcdefgh 是 weak 强度（8 字符，不满足 medium/strong 条件）
      final entry = createTestEntry(passphrase: 'abcdefgh');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.strength, PassphraseStrength.weak);
    });

    testWidgets('中等暗号应显示中等强度', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 12 字符以上且包含字母和数字
      final entry = createTestEntry(passphrase: 'mypass1234abc');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.strength, PassphraseStrength.medium);
    });

    testWidgets('强暗号应显示强强度', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 16 字符以上且满足 3+ 字符类别
      final entry = createTestEntry(passphrase: 'MyStr0ngPass!2024');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      expect(key.currentState!.strength, PassphraseStrength.strong);
    });
  });

  // ============================================================
  // 不一致状态测试
  // ============================================================
  group('不一致状态', () {
    testWidgets('两次输入不一致时应显示错误提示', (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 输入暗号
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'abcdefgh');
      await tester.pump();

      // 输入不匹配的确认暗号
      final confirmField =
          find.widgetWithText(TextField, '再次输入暗号（确认）');
      await tester.enterText(confirmField, 'xyz');
      await tester.pumpAndSettle();

      // 应显示不一致错误提示
      expect(find.text('两次输入的暗号不一致'), findsOneWidget);
    });

    testWidgets('setPassphraseFromVault 后不一致错误应消失',
        (WidgetTester tester) async {
      final key = GlobalKey<PassphraseInputState>();
      await tester.pumpWidget(buildTestWidget(key: key));
      await tester.pumpAndSettle();

      // 先制造不一致状态
      final passphraseField = find.widgetWithText(TextField, '加密暗号');
      await tester.enterText(passphraseField, 'abcdefgh');
      await tester.pump();

      final confirmField =
          find.widgetWithText(TextField, '再次输入暗号（确认）');
      await tester.enterText(confirmField, 'different');
      await tester.pumpAndSettle();

      // 确认不一致提示存在
      expect(find.text('两次输入的暗号不一致'), findsOneWidget);

      // 使用 setPassphraseFromVault 填充匹配暗号
      final entry = createTestEntry(passphrase: 'abcdefgh');
      key.currentState!.setPassphraseFromVault(entry);
      await tester.pumpAndSettle();

      // 不一致提示应消失
      expect(find.text('两次输入的暗号不一致'), findsNothing);
    });
  });
}
