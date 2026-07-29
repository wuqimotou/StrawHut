import 'package:flutter/material.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// Shared completion notices for desktop and Android publish flows.
///
/// Keeping format-specific and encryption-specific guidance in one widget
/// prevents `.straw` and `.png` completion screens from drifting apart.
class PublishSecurityNotices extends StatelessWidget {
  const PublishSecurityNotices({
    required this.exportFormat,
    required this.isNegotiated,
    this.keyBase64,
    super.key,
  }) : assert(isNegotiated || keyBase64 != null);

  final String exportFormat;
  final bool isNegotiated;
  final String? keyBase64;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exportFormat == 'png') ...[
          NeumorphicContainer(
            shape: NeumorphicShape.concave,
            borderRadius: tokens.radiusSmall,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeumorphicIcon(
                  StrawIcons.info,
                  size: 18,
                  color: tokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.shareAsOriginalImage,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spaceMd),
        ],
        if (isNegotiated)
          NeumorphicContainer(
            shape: NeumorphicShape.concave,
            borderRadius: tokens.radiusSmall,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.publish,
                      size: 20,
                      color: tokens.inkPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseShareNote,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.warning,
                      size: 20,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseSecurityNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          KeyDisplay(keyBase64: keyBase64!),
      ],
    );
  }
}
