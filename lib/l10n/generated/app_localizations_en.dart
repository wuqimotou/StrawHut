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
  String publishSavedToPath(String path) {
    return 'Published successfully. File saved to: $path';
  }

  @override
  String publishFailed(String error) {
    return 'Publish failed: $error';
  }

  @override
  String get publishSuccessTitle => 'Published';

  @override
  String get publishSuccessMessage => 'Knowledge card published successfully!';

  @override
  String get filePathLabel => 'File path:';

  @override
  String get unknownValue => 'Unknown';

  @override
  String get done => 'Done';

  @override
  String get shareAsOriginalImage =>
      'Please send as original image, otherwise recipient cannot decrypt';

  @override
  String get pngOriginalImageConfirmTitle => 'Original Image Reminder';

  @override
  String get pngOriginalImageConfirmBody =>
      'PNG knowledge cards embed encrypted data into image pixels. You MUST send it as the original image (no compression, no format conversion, no re-screenshot), otherwise the recipient will not be able to decrypt it. Do you confirm you understand and want to continue publishing?';

  @override
  String get confirmPublish => 'Confirm Publish';

  @override
  String get sharePngCard => 'Share Card';

  @override
  String get vaultTitle => 'Passphrase Vault';

  @override
  String get vaultEmptyTitle => 'Vault is Empty';

  @override
  String get vaultEmptyDesc =>
      'Save passphrases to select them directly on the decrypt screen';

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
    return 'Delete passphrase \"$label\"? You will need to enter it again or select another passphrase when decrypting.';
  }

  @override
  String get clearAllTitle => 'Clear All Passphrases';

  @override
  String get clearAllWarning =>
      'This will delete all saved passphrases and cannot be undone.';

  @override
  String get clearAllConfirmInput => 'Type DELETE to confirm';

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

  @override
  String get contentSource => 'Content Source';

  @override
  String get editorContent => 'Editor Content';

  @override
  String get uploadFile => 'Upload File';

  @override
  String get selectFile => 'Select File';

  @override
  String get dragFileHere => 'Drag file here or click to select';

  @override
  String get anyFileType => 'Any file type supported';

  @override
  String selectedFile(String fileName, String fileSize) {
    return 'Selected: $fileName ($fileSize)';
  }

  @override
  String get removeFile => 'Remove';

  @override
  String get fileSizeHint =>
      'Large file, encryption may take several seconds. Continue?';

  @override
  String get fileSizeWarning =>
      'Large file, encryption/decryption may take a long time. Better on powerful devices. Continue?';

  @override
  String get fileSizeStrongWarning =>
      'Very large file, long encryption/decryption, high memory usage, may lag on low-end devices. Continue?';

  @override
  String get fileSizeSevereWarning =>
      'Extremely large file, very long encryption/decryption, may use lots of memory and storage. Strongly recommend splitting the file first. Continue anyway?';

  @override
  String get saveFile => 'Save File';

  @override
  String get saveToLocale => 'Save to Local';

  @override
  String get viewSource => 'View Source';

  @override
  String get renderView => 'Render View';

  @override
  String get contentTooLong =>
      'Content too long, suggest saving as file for full view';

  @override
  String get imageLoadFailed => 'Image load failed';

  @override
  String audioLoadFailed(String error) {
    return 'Audio load failed: $error';
  }

  @override
  String videoLoadFailed(String error) {
    return 'Video load failed: $error';
  }

  @override
  String get saveAudio => 'Save Audio';

  @override
  String get saveVideo => 'Save Video';

  @override
  String get savePdf => 'Save PDF';

  @override
  String get cannotPreview =>
      'This file type cannot be previewed, please save and open with the appropriate program.';

  @override
  String get saveToLocal => 'Save to Local';

  @override
  String fileSize(String size) {
    return 'File size: $size';
  }

  @override
  String fileType(String type) {
    return 'File type: $type';
  }

  @override
  String get migrationTitle => 'Migrate Legacy File';

  @override
  String get migrationSuccess =>
      'Migration complete. Original file is preserved. You may delete the old file after confirming the new one works.';

  @override
  String migrationFailed(String error) {
    return 'Migration failed: $error';
  }

  @override
  String get oldFormatDetected =>
      'This file uses an old format and needs migration to view. Migrate now?';

  @override
  String get migrateNow => 'Migrate Now';

  @override
  String get exportFormatStraw => '.straw only';

  @override
  String get strawFormatOnly =>
      'File encryption mode only supports .straw format';

  @override
  String get legacyFileFormatTitle => 'Legacy File Format';

  @override
  String get legacyFileFormatMessage =>
      'This file is in legacy format and needs to be migrated before viewing. Please use the \'Migrate Legacy File\' function.';

  @override
  String get legacyFileMigrationRequired =>
      'This file needs to be migrated before viewing';

  @override
  String get migrate => 'Migrate';

  @override
  String get migrateLegacyFile => 'Migrate Legacy File';

  @override
  String get migrateLegacyFileDescription =>
      'Select a legacy .straw file and migrate it to the new format';

  @override
  String get selectLegacyFile => 'Select Legacy File';

  @override
  String get notOldFormat =>
      'This file is not in legacy format, no migration needed';

  @override
  String get migrationKeyRequired => 'Please enter the key';

  @override
  String get performMigration => 'Perform Migration';

  @override
  String get contentSourceLabel => 'Content Source';

  @override
  String get editorContentLabel => 'Editor';

  @override
  String get fileUploadLabel => 'Upload File';

  @override
  String get wrongPassphrase => 'Incorrect passphrase';

  @override
  String get wrongKey => 'Incorrect key';

  @override
  String get errFileNotFound => 'The encrypted file could not be found';

  @override
  String get errInvalidFileFormat => 'The encrypted file format is invalid';

  @override
  String get errEmptyChunks => 'The encrypted file contains no data chunks';

  @override
  String get errMetadataTruncated =>
      'The encrypted file metadata is incomplete';

  @override
  String get errFirstChunkTooSmall =>
      'The first encrypted data chunk is incomplete';

  @override
  String get errInvalidSaltLength =>
      'The encrypted file contains an invalid salt';

  @override
  String get errDecryptStreamFailed =>
      'The encrypted file could not be decrypted';

  @override
  String get errMetadataTooLarge => 'The encrypted file metadata is too large';

  @override
  String get errChunkSizeTooSmall =>
      'The encrypted file uses an invalid chunk size';

  @override
  String get errKeyDerivationFailed =>
      'The decryption key could not be derived from this passphrase';

  @override
  String get errInvalidKeyLength => 'The decryption key has an invalid length';

  @override
  String get errUnknown => 'An unknown decryption error occurred';

  @override
  String get errDecryptGeneric =>
      'Decryption failed. Please verify the file and credentials, then try again.';

  @override
  String get errKeyRequired => 'Enter a key or upload a .key file';

  @override
  String get errInvalidKeyFormat => 'The key is not valid Base64 data';

  @override
  String get verifying => 'Verifying...';
}
