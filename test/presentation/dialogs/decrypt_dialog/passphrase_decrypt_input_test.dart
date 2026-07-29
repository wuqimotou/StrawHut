import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/passphrase_decrypt_input.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

void main() {
  const entry = PassphraseEntry(
    id: 'saved-1',
    passphrase: 'Saved Secret 123!',
    label: '团队暗号',
    createdAt: '2026-07-14T00:00:00Z',
    useCount: 3,
  );

  Widget buildSubject({
    required GlobalKey<PassphraseDecryptInputState> inputKey,
    List<PassphraseEntry> entries = const [entry],
    ValueChanged<bool>? onVaultSelectionChanged,
  }) {
    return ProviderScope(
      overrides: [
        passphraseEntriesProvider.overrideWith((ref) async => entries),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PassphraseDecryptInput(
              key: inputKey,
              onVaultSelectionChanged: onVaultSelectionChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('selecting one saved entry fills the passphrase without typing', (
    tester,
  ) async {
    final inputKey = GlobalKey<PassphraseDecryptInputState>();
    final sourceChanges = <bool>[];
    await tester.pumpWidget(
      buildSubject(
        inputKey: inputKey,
        onVaultSelectionChanged: sourceChanges.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('从保险库选择'));
    await tester.pumpAndSettle();
    expect(find.text('团队暗号'), findsOneWidget);

    await tester.tap(find.text('团队暗号'));
    await tester.pumpAndSettle();

    expect(inputKey.currentState!.passphrase, entry.passphrase);
    expect(inputKey.currentState!.selectedEntryId, entry.id);
    expect(inputKey.currentState!.isFromVault, isTrue);
    expect(sourceChanges, [true]);
  });

  testWidgets('editing a selected passphrase returns to manual input mode', (
    tester,
  ) async {
    final inputKey = GlobalKey<PassphraseDecryptInputState>();
    final sourceChanges = <bool>[];
    await tester.pumpWidget(
      buildSubject(
        inputKey: inputKey,
        onVaultSelectionChanged: sourceChanges.add,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('从保险库选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('团队暗号'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'manual passphrase');
    await tester.pump();

    expect(inputKey.currentState!.selectedEntryId, isNull);
    expect(inputKey.currentState!.passphrase, 'manual passphrase');
    expect(sourceChanges, [true, false]);
  });

  testWidgets('empty vault leaves the explicit selector disabled', (
    tester,
  ) async {
    final inputKey = GlobalKey<PassphraseDecryptInputState>();
    await tester.pumpWidget(
      buildSubject(inputKey: inputKey, entries: const []),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });
}
