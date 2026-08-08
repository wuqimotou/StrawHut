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
  String get decryptPassphraseRequired => '请输入暗号后再解密';

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
  String publishSavedToPath(String path) {
    return '发布成功！文件已保存至：$path';
  }

  @override
  String publishFailed(String error) {
    return '发布失败：$error';
  }

  @override
  String get publishSuccessTitle => '发布成功';

  @override
  String get publishSuccessMessage => '知识卡片已成功发布！';

  @override
  String get filePathLabel => '文件路径：';

  @override
  String get unknownValue => '未知';

  @override
  String get done => '完成';

  @override
  String get shareAsOriginalImage => '请以原图方式发送，否则接收方无法解密';

  @override
  String get pngOriginalImageConfirmTitle => '原图发送提醒';

  @override
  String get pngOriginalImageConfirmBody =>
      'PNG 知识卡片将加密数据嵌入图像像素，必须以原图方式发送（不压缩、不转格式、不二次截图），否则接收方将无法解密。是否确认了解并继续发布？';

  @override
  String get confirmPublish => '确认发布';

  @override
  String get sharePngCard => '分享卡片';

  @override
  String get vaultTitle => '暗号保险库';

  @override
  String get vaultEmptyTitle => '暗号保险库为空';

  @override
  String get vaultEmptyDesc => '保存常用暗号后，可在解密界面直接选择，无需再次输入';

  @override
  String get vaultAddButton => '添加暗号';

  @override
  String get vaultClearAllButton => '清除全部暗号';

  @override
  String vaultCountLabel(int count) {
    return '已保存 $count/10 条暗号';
  }

  @override
  String get vaultSecurityNote => '保存的暗号将存储在设备安全区域中，除您主动保存的暗号外，零持久化存储';

  @override
  String get addPassphraseTitle => '添加暗号';

  @override
  String get passphraseLabelField => '备注名称';

  @override
  String get passphraseLabelHint => '例如：团队暗号';

  @override
  String get savePassphraseWarning =>
      '保存暗号到本地将违反 StrawHut 的“零持久化存储”隐私承诺。虽然暗号会使用设备安全存储机制加密保存，但任何持久化存储都存在理论上的安全风险。';

  @override
  String get savePassphraseConfirm => '我已了解风险，同意保存';

  @override
  String get confirmSave => '确认保存';

  @override
  String get vaultFull => '保险库已满，请删除后重试';

  @override
  String get duplicatePassphrase => '该暗号已保存';

  @override
  String get passphraseTooWeak => '暗号强度不足，至少需要 8 个字符';

  @override
  String get deletePassphraseTitle => '确认删除';

  @override
  String deletePassphraseMessage(String label) {
    return '确定要删除暗号\"$label\"吗？删除后，解密时需重新输入或选择其他暗号。';
  }

  @override
  String get clearAllTitle => '清除全部暗号';

  @override
  String get clearAllWarning => '此操作将删除所有已保存的暗号，且不可撤销。';

  @override
  String get clearAllConfirmInput => '请输入 DELETE 以确认';

  @override
  String get saveAfterDecrypt => '解密后保存此暗号到保险库';

  @override
  String passphraseDefaultLabel(int n) {
    return '暗号 #$n';
  }

  @override
  String vaultEntryCount(int count) {
    return '$count 条暗号';
  }

  @override
  String get vaultTooltip => '暗号保险库';

  @override
  String get delete => '删除';

  @override
  String get clearAll => '清除全部';

  @override
  String get selectFromVault => '从保险库选择';

  @override
  String get selectFromVaultDesc => '从已保存的暗号中选择';

  @override
  String get selectPassphraseTitle => '选择暗号';

  @override
  String get vaultEmptySelectHint => '保险库为空，请先添加暗号';

  @override
  String get saveAfterPublish => '保存暗号到保险库？';

  @override
  String get saveAfterPublishDesc => '您刚刚使用的暗号不在保险库中。保存后，下次加密或解密时可快速使用。';

  @override
  String get skipSave => '跳过';

  @override
  String get savePassphraseAction => '保存暗号';

  @override
  String usedCount(int count) {
    return '使用 $count 次';
  }

  @override
  String get contentSource => '内容来源';

  @override
  String get editorContent => '编辑器内容';

  @override
  String get uploadFile => '上传文件';

  @override
  String get selectFile => '选择文件';

  @override
  String get dragFileHere => '拖拽文件到此处或点击选择';

  @override
  String get anyFileType => '支持任意类型文件';

  @override
  String selectedFile(String fileName, String fileSize) {
    return '已选择：$fileName（$fileSize）';
  }

  @override
  String get removeFile => '移除';

  @override
  String get fileSizeHint => '文件较大，加密可能需要数秒至十余秒，是否继续？';

  @override
  String get fileSizeWarning => '文件较大，加密和解密可能需要较长时间，建议在性能较好的设备上操作。是否继续？';

  @override
  String get fileSizeStrongWarning => '文件非常大，加密和解密耗时较长，内存占用较高，可能导致低端设备卡顿。是否继续？';

  @override
  String get fileSizeSevereWarning =>
      '文件极大，加密和解密耗时可能很长，可能占用大量内存和存储空间。强烈建议分割文件后再加密。是否仍要继续？';

  @override
  String get saveFile => '保存文件';

  @override
  String get saveToLocale => '保存到本地';

  @override
  String get viewSource => '查看源码';

  @override
  String get renderView => '渲染视图';

  @override
  String get contentTooLong => '内容过长，建议保存为文件查看完整内容';

  @override
  String get imageLoadFailed => '图片加载失败';

  @override
  String audioLoadFailed(String error) {
    return '音频加载失败：$error';
  }

  @override
  String videoLoadFailed(String error) {
    return '视频加载失败：$error';
  }

  @override
  String get saveAudio => '保存音频';

  @override
  String get saveVideo => '保存视频';

  @override
  String get savePdf => '保存PDF';

  @override
  String get cannotPreview => '此文件类型无法直接预览，请保存后使用对应程序打开。';

  @override
  String get saveToLocal => '保存到本地';

  @override
  String fileSize(String size) {
    return '文件大小：$size';
  }

  @override
  String fileType(String type) {
    return '文件类型：$type';
  }

  @override
  String get migrationTitle => '迁移旧版文件';

  @override
  String get migrationSuccess => '旧版文件已迁移，原文件仍保留。建议确认新文件可用后删除旧版文件。';

  @override
  String migrationFailed(String error) {
    return '迁移失败：$error';
  }

  @override
  String get oldFormatDetected => '此文件为旧版格式，需要迁移后才能查看。是否立即迁移？';

  @override
  String get migrateNow => '立即迁移';

  @override
  String get exportFormatStraw => '仅 .straw';

  @override
  String get strawFormatOnly => '文件加密模式仅支持 .straw 格式';

  @override
  String get legacyFileFormatTitle => '旧版文件格式';

  @override
  String get legacyFileFormatMessage =>
      '此文件为旧版格式，需要迁移后才能查看。请使用\"迁移旧版文件\"功能进行转换。';

  @override
  String get legacyFileMigrationRequired => '此文件需要迁移后才能查看';

  @override
  String get migrate => '迁移';

  @override
  String get migrateLegacyFile => '迁移旧版文件';

  @override
  String get migrateLegacyFileDescription => '选择旧版 .straw 文件并将其迁移到新格式';

  @override
  String get selectLegacyFile => '选择旧版文件';

  @override
  String get notOldFormat => '该文件不是旧版格式，无需迁移';

  @override
  String get migrationKeyRequired => '请输入密钥';

  @override
  String get performMigration => '执行迁移';

  @override
  String get contentSourceLabel => '内容来源';

  @override
  String get editorContentLabel => '编辑器内容';

  @override
  String get fileUploadLabel => '上传文件';
}
