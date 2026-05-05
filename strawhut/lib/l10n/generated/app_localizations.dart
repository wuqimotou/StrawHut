import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// 应用标题
  ///
  /// In zh, this message translates to:
  /// **'StrawHut'**
  String get appTitle;

  /// 新建知识卡片按钮
  ///
  /// In zh, this message translates to:
  /// **'新建知识卡片'**
  String get newCard;

  /// 打开知识卡片按钮
  ///
  /// In zh, this message translates to:
  /// **'打开知识卡片'**
  String get openCard;

  /// 发布按钮
  ///
  /// In zh, this message translates to:
  /// **'发布'**
  String get publish;

  /// 解密按钮
  ///
  /// In zh, this message translates to:
  /// **'解密'**
  String get decrypt;

  /// 取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 标题字段
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get title;

  /// 发布者代号字段
  ///
  /// In zh, this message translates to:
  /// **'发布者代号'**
  String get publisherAlias;

  /// 描述字段
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get description;

  /// 标签字段
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// 匿名模式开关
  ///
  /// In zh, this message translates to:
  /// **'匿名模式'**
  String get anonymousMode;

  /// 复制密钥按钮
  ///
  /// In zh, this message translates to:
  /// **'复制密钥'**
  String get copyKey;

  /// 导出密钥文件选项
  ///
  /// In zh, this message translates to:
  /// **'导出 .key 文件'**
  String get exportKeyFile;

  /// 解密失败提示
  ///
  /// In zh, this message translates to:
  /// **'密钥错误或文件已损坏'**
  String get keyError;

  /// 完整性校验失败提示
  ///
  /// In zh, this message translates to:
  /// **'文件可能被篡改'**
  String get integrityError;

  /// 加密模式标签
  ///
  /// In zh, this message translates to:
  /// **'加密模式'**
  String get encryptionModeLabel;

  /// 随机密钥模式选项
  ///
  /// In zh, this message translates to:
  /// **'随机密钥模式（推荐）'**
  String get randomKeyMode;

  /// 随机密钥模式描述
  ///
  /// In zh, this message translates to:
  /// **'系统自动生成高强度随机密钥'**
  String get randomKeyModeDesc;

  /// 协商密钥模式选项
  ///
  /// In zh, this message translates to:
  /// **'协商密钥模式'**
  String get negotiatedKeyMode;

  /// 协商密钥模式描述
  ///
  /// In zh, this message translates to:
  /// **'通过暗号派生密钥，适合口头分享'**
  String get negotiatedKeyModeDesc;

  /// 暗号输入标签
  ///
  /// In zh, this message translates to:
  /// **'加密暗号'**
  String get passphraseLabel;

  /// 暗号输入提示
  ///
  /// In zh, this message translates to:
  /// **'请输入加密暗号'**
  String get passphraseHint;

  /// 暗号确认标签
  ///
  /// In zh, this message translates to:
  /// **'再次输入暗号（确认）'**
  String get passphraseConfirmLabel;

  /// 暗号确认提示
  ///
  /// In zh, this message translates to:
  /// **'请再次输入暗号'**
  String get passphraseConfirmHint;

  /// 暗号不一致提示
  ///
  /// In zh, this message translates to:
  /// **'两次输入的暗号不一致'**
  String get passphraseMismatch;

  /// 暗号强度标签
  ///
  /// In zh, this message translates to:
  /// **'暗号强度'**
  String get passphraseStrengthLabel;

  /// 强强度
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get strengthStrong;

  /// 中等强度
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get strengthMedium;

  /// 弱强度
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get strengthWeak;

  /// 极弱强度
  ///
  /// In zh, this message translates to:
  /// **'极弱'**
  String get strengthVeryWeak;

  /// 极弱强度详细提示
  ///
  /// In zh, this message translates to:
  /// **'暗号过短，至少需要 8 个字符'**
  String get strengthVeryWeakDetail;

  /// 弱暗号警告
  ///
  /// In zh, this message translates to:
  /// **'当前暗号强度较弱，存在被暴力破解的风险'**
  String get passphraseWeakWarning;

  /// 弱暗号建议
  ///
  /// In zh, this message translates to:
  /// **'建议将暗号延长至 12 个字符以上，并混合使用字母、数字和符号'**
  String get passphraseWeakSuggestion;

  /// 弱暗号确认提示
  ///
  /// In zh, this message translates to:
  /// **'您确定要继续使用该暗号吗？'**
  String get passphraseWeakConfirm;

  /// 弱暗号警告对话框标题
  ///
  /// In zh, this message translates to:
  /// **'暗号强度警告'**
  String get weakPassphraseTitle;

  /// 返回修改按钮
  ///
  /// In zh, this message translates to:
  /// **'返回修改'**
  String get backToEdit;

  /// 确认继续按钮
  ///
  /// In zh, this message translates to:
  /// **'确认继续'**
  String get confirmContinue;

  /// 解密时暗号输入标签
  ///
  /// In zh, this message translates to:
  /// **'请输入加密暗号'**
  String get decryptPassphraseLabel;

  /// 解密时暗号输入提示
  ///
  /// In zh, this message translates to:
  /// **'请与创作者确认暗号内容'**
  String get decryptPassphraseHint;

  /// 解密时暗号加密提示
  ///
  /// In zh, this message translates to:
  /// **'此知识卡片通过暗号加密'**
  String get decryptPassphraseInfo;

  /// 暗号解密失败提示
  ///
  /// In zh, this message translates to:
  /// **'暗号错误或文件已损坏'**
  String get passphraseDecryptFailed;

  /// 暗号安全提示
  ///
  /// In zh, this message translates to:
  /// **'请妥善保管暗号，遗忘后无法找回内容'**
  String get passphraseSecurityNote;

  /// 暗号强度要求提示
  ///
  /// In zh, this message translates to:
  /// **'建议使用 12 个以上字符，包含字母、数字和符号，以提高安全性'**
  String get passphraseStrengthRequirement;

  /// 协商密钥模式下发布成功后的暗号分享提示
  ///
  /// In zh, this message translates to:
  /// **'请将暗号告知接收者，接收者需要输入相同暗号才能解密。'**
  String get passphraseShareNote;

  /// 知识卡片保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'知识卡片已保存到下载文件夹'**
  String get strawSavedToDownloads;

  /// PNG 卡片保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'卡片图片已保存到相册'**
  String get pngSavedToPhotos;

  /// 密钥文件保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'密钥文件已保存到下载文件夹'**
  String get keySavedToDownloads;

  /// PNG 分享时提示以原图发送
  ///
  /// In zh, this message translates to:
  /// **'请以原图方式发送，否则接收方无法解密'**
  String get shareAsOriginalImage;

  /// PNG 分享按钮文字
  ///
  /// In zh, this message translates to:
  /// **'分享卡片'**
  String get sharePngCard;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
