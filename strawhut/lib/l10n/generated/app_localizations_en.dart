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
}
