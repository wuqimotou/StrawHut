// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StrawHut';

  @override
  String get newCard => 'New Knowledge Card';

  @override
  String get openCard => 'Open Knowledge Card';

  @override
  String get publish => 'Publish';

  @override
  String get decrypt => 'Decrypt';

  @override
  String get cancel => 'Cancel';

  @override
  String get title => 'Title';

  @override
  String get publisherAlias => 'Publisher Alias';

  @override
  String get description => 'Description';

  @override
  String get tags => 'Tags';

  @override
  String get anonymousMode => 'Anonymous Mode';

  @override
  String get copyKey => 'Copy Key';

  @override
  String get exportKeyFile => 'Export .key file';

  @override
  String get keyError => 'Wrong key or corrupted file';

  @override
  String get integrityError => 'File may have been tampered with';

  @override
  String get encryptionModeLabel => 'Encryption Mode';

  @override
  String get randomKeyMode => 'Random Key Mode (Recommended)';

  @override
  String get randomKeyModeDesc => 'System generates a strong random key';

  @override
  String get negotiatedKeyMode => 'Negotiated Key Mode';

  @override
  String get negotiatedKeyModeDesc =>
      'Derive key from passphrase, ideal for verbal sharing';

  @override
  String get passphraseLabel => 'Encryption Passphrase';

  @override
  String get passphraseHint => 'Enter encryption passphrase';

  @override
  String get passphraseConfirmLabel => 'Confirm Passphrase';

  @override
  String get passphraseConfirmHint => 'Re-enter passphrase to confirm';

  @override
  String get passphraseMismatch => 'Passphrases do not match';

  @override
  String get passphraseStrengthLabel => 'Passphrase Strength';

  @override
  String get strengthStrong => 'Strong';

  @override
  String get strengthMedium => 'Medium';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthVeryWeak => 'Very Weak';

  @override
  String get strengthVeryWeakDetail =>
      'Passphrase too short, minimum 8 characters required';

  @override
  String get passphraseWeakWarning =>
      'Your passphrase is weak and may be vulnerable to brute force attacks';

  @override
  String get passphraseWeakSuggestion =>
      'We recommend using 12+ characters with a mix of letters, numbers, and symbols';

  @override
  String get passphraseWeakConfirm =>
      'Are you sure you want to continue with this passphrase?';

  @override
  String get weakPassphraseTitle => 'Weak Passphrase Warning';

  @override
  String get backToEdit => 'Go Back';

  @override
  String get confirmContinue => 'Continue Anyway';

  @override
  String get decryptPassphraseLabel => 'Enter Encryption Passphrase';

  @override
  String get decryptPassphraseRequired =>
      'Please enter a passphrase to decrypt';

  @override
  String get decryptPassphraseHint => 'Confirm the passphrase with the creator';

  @override
  String get decryptPassphraseInfo =>
      'This knowledge card is encrypted with a passphrase';

  @override
  String get passphraseDecryptFailed => 'Wrong passphrase or corrupted file';

  @override
  String get passphraseSecurityNote =>
      'Keep your passphrase safe. Content cannot be recovered if forgotten';

  @override
  String get passphraseStrengthRequirement =>
      'We recommend 12+ characters including letters, numbers, and symbols for better security';

  @override
  String get passphraseShareNote =>
      'Share the passphrase with recipients. They need the same passphrase to decrypt.';

  @override
  String get strawSavedToDownloads => 'Knowledge card saved to Downloads';

  @override
  String get pngSavedToPhotos => 'Card image saved to Photos';

  @override
  String get keySavedToDownloads => 'Key file saved to Downloads';

  @override
  String get shareAsOriginalImage =>
      'Please send as original image, otherwise recipient cannot decrypt';

  @override
  String get sharePngCard => 'Share Card';

  @override
  String get vaultTitle => 'Passphrase Vault';

  @override
  String get vaultEmptyTitle => 'Vault is Empty';

  @override
  String get vaultEmptyDesc =>
      'Save passphrases to auto-decrypt cards encrypted with them';

  @override
  String get vaultAddButton => 'Add Passphrase';

  @override
  String get vaultClearAllButton => 'Clear All Passphrases';

  @override
  String vaultCountLabel(int count) {
    return '$count/10 passphrases saved';
  }

  @override
  String get vaultSecurityNote =>
      'Saved passphrases are stored in device secure storage. Zero persistent storage except your saved passphrases.';

  @override
  String get addPassphraseTitle => 'Add Passphrase';

  @override
  String get passphraseLabelField => 'Label';

  @override
  String get passphraseLabelHint => 'e.g. Team Passphrase';

  @override
  String get savePassphraseWarning =>
      'Saving passphrases locally will modify StrawHut\'s \"zero persistent storage\" privacy commitment. Although passphrases are encrypted using device secure storage, any persistent storage carries theoretical security risks.';

  @override
  String get savePassphraseConfirm => 'I understand the risk and agree to save';

  @override
  String get confirmSave => 'Confirm Save';

  @override
  String get vaultFull => 'Vault is full, please delete before adding';

  @override
  String get duplicatePassphrase => 'This passphrase is already saved';

  @override
  String get passphraseTooWeak =>
      'Passphrase is too weak, minimum 8 characters required';

  @override
  String get deletePassphraseTitle => 'Confirm Delete';

  @override
  String deletePassphraseMessage(String label) {
    return 'Delete passphrase \"$label\"? Cards encrypted with this passphrase will require manual input to decrypt.';
  }

  @override
  String get clearAllTitle => 'Clear All Passphrases';

  @override
  String get clearAllWarning =>
      'This will delete all saved passphrases and cannot be undone.';

  @override
  String get clearAllConfirmInput => 'Type DELETE to confirm';

  @override
  String get autoDecryptProgress => 'Trying auto-decrypt...';

  @override
  String autoDecryptProgressWithCount(int current, int total) {
    return 'Trying auto-decrypt ($current/$total)...';
  }

  @override
  String autoDecryptSuccess(String label) {
    return 'Auto-decrypted with saved passphrase \"$label\"';
  }

  @override
  String get saveAfterDecrypt =>
      'Save this passphrase to vault after decryption';

  @override
  String passphraseDefaultLabel(int n) {
    return 'Passphrase #$n';
  }

  @override
  String vaultEntryCount(int count) {
    return '$count passphrase(s)';
  }

  @override
  String get vaultTooltip => 'Passphrase Vault';

  @override
  String get delete => 'Delete';

  @override
  String get clearAll => 'Clear All';

  @override
  String get selectFromVault => 'Select from Vault';

  @override
  String get selectFromVaultDesc => 'Select from saved passphrases';

  @override
  String get selectPassphraseTitle => 'Select Passphrase';

  @override
  String get vaultEmptySelectHint =>
      'Vault is empty, please add a passphrase first';

  @override
  String get saveAfterPublish => 'Save Passphrase to Vault?';

  @override
  String get saveAfterPublishDesc =>
      'The passphrase you just used is not in the vault. Save it for quick access next time.';

  @override
  String get skipSave => 'Skip';

  @override
  String get savePassphraseAction => 'Save Passphrase';

  @override
  String usedCount(int count) {
    return 'Used $count time(s)';
  }
}
