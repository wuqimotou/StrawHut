/// 国际化（i18n）配置
///
/// 统一导出 flutter gen-l10n 生成的本地化文件。
///
/// 架构位置：国际化模块 → 聚合导出
/// 使用工具：flutter gen-l10n（Flutter 内置国际化生成工具）
///
/// 工作流程：
/// 1. 编辑 lib/l10n/app_en.arb 和 lib/l10n/app_zh.arb 翻译文件
/// 2. 运行 flutter gen-l10n 生成 app_localizations.dart
/// 3. 生成的文件位于 lib/l10n/generated/ 目录
/// 4. 通过此文件统一导出，简化外部引用
///
/// 使用示例：
/// ```dart
/// import 'package:strawhut/l10n/l10n.dart';
/// // 在 Widget 中使用
/// Text(AppLocalizations.of(context)!.appName)
/// ```
///
/// 注意事项：
/// - generated/ 目录下的文件为自动生成，不应手动修改
/// - 翻译内容应编辑 .arb 文件后重新生成
export 'generated/app_localizations.dart';
