import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/publish_security_notices.dart';

void main() {
  Widget buildSubject({
    required String exportFormat,
    required bool isNegotiated,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PublishSecurityNotices(
          exportFormat: exportFormat,
          isNegotiated: isNegotiated,
          keyBase64: isNegotiated ? null : List.filled(44, 'A').join(),
        ),
      ),
    );
  }

  for (final format in ['straw', 'png']) {
    testWidgets('$format passphrase publish always shows sharing guidance', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(exportFormat: format, isNegotiated: true),
      );
      final context = tester.element(find.byType(PublishSecurityNotices));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.passphraseShareNote), findsOneWidget);
      expect(find.text(l10n.passphraseSecurityNote), findsOneWidget);
      expect(find.byType(KeyDisplay), findsNothing);
      expect(
        find.text(l10n.shareAsOriginalImage),
        format == 'png' ? findsOneWidget : findsNothing,
      );
    });

    testWidgets(
      '$format random-key publish shows key instead of passphrase note',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(exportFormat: format, isNegotiated: false),
        );
        final context = tester.element(find.byType(PublishSecurityNotices));
        final l10n = AppLocalizations.of(context)!;

        expect(find.text(l10n.passphraseShareNote), findsNothing);
        expect(find.byType(KeyDisplay), findsOneWidget);
        expect(
          find.text(l10n.shareAsOriginalImage),
          format == 'png' ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
