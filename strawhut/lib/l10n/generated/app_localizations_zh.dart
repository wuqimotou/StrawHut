// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'StrawHut';

  @override
  String get newCard => '新建知识卡片';

  @override
  String get openCard => '打开知识卡片';

  @override
  String get publish => '发布';

  @override
  String get decrypt => '解密';

  @override
  String get cancel => '取消';

  @override
  String get title => '标题';

  @override
  String get publisherAlias => '发布者代号';

  @override
  String get description => '描述';

  @override
  String get tags => '标签';

  @override
  String get anonymousMode => '匿名模式';

  @override
  String get copyKey => '复制密钥';

  @override
  String get exportKeyFile => '导出 .key 文件';

  @override
  String get keyError => '密钥错误或文件已损坏';

  @override
  String get integrityError => '文件可能被篡改';
}
