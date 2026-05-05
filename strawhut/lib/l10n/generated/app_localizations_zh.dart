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

  @override
  String get encryptionModeLabel => '加密模式';

  @override
  String get randomKeyMode => '随机密钥模式（推荐）';

  @override
  String get randomKeyModeDesc => '系统自动生成高强度随机密钥';

  @override
  String get negotiatedKeyMode => '协商密钥模式';

  @override
  String get negotiatedKeyModeDesc => '通过暗号派生密钥，适合口头分享';

  @override
  String get passphraseLabel => '加密暗号';

  @override
  String get passphraseHint => '请输入加密暗号';

  @override
  String get passphraseConfirmLabel => '再次输入暗号（确认）';

  @override
  String get passphraseConfirmHint => '请再次输入暗号';

  @override
  String get passphraseMismatch => '两次输入的暗号不一致';

  @override
  String get passphraseStrengthLabel => '暗号强度';

  @override
  String get strengthStrong => '强';

  @override
  String get strengthMedium => '中';

  @override
  String get strengthWeak => '弱';

  @override
  String get strengthVeryWeak => '极弱';

  @override
  String get strengthVeryWeakDetail => '暗号过短，至少需要 8 个字符';

  @override
  String get passphraseWeakWarning => '当前暗号强度较弱，存在被暴力破解的风险';

  @override
  String get passphraseWeakSuggestion => '建议将暗号延长至 12 个字符以上，并混合使用字母、数字和符号';

  @override
  String get passphraseWeakConfirm => '您确定要继续使用该暗号吗？';

  @override
  String get weakPassphraseTitle => '暗号强度警告';

  @override
  String get backToEdit => '返回修改';

  @override
  String get confirmContinue => '确认继续';

  @override
  String get decryptPassphraseLabel => '请输入加密暗号';

  @override
  String get decryptPassphraseHint => '请与创作者确认暗号内容';

  @override
  String get decryptPassphraseInfo => '此知识卡片通过暗号加密';

  @override
  String get passphraseDecryptFailed => '暗号错误或文件已损坏';

  @override
  String get passphraseSecurityNote => '请妥善保管暗号，遗忘后无法找回内容';

  @override
  String get passphraseStrengthRequirement => '建议使用 12 个以上字符，包含字母、数字和符号，以提高安全性';

  @override
  String get passphraseShareNote => '请将暗号告知接收者，接收者需要输入相同暗号才能解密。';

  @override
  String get strawSavedToDownloads => '知识卡片已保存到下载文件夹';

  @override
  String get pngSavedToPhotos => '卡片图片已保存到相册';

  @override
  String get keySavedToDownloads => '密钥文件已保存到下载文件夹';

  @override
  String get shareAsOriginalImage => '请以原图方式发送，否则接收方无法解密';

  @override
  String get sharePngCard => '分享卡片';
}
