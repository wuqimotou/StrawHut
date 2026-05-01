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
}
