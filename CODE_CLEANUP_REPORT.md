# StrawHut 代码清理与维护报告

## 1. 范围与基线

- 基线：`wuqimotou/StrawHut` 的 `main`，提交 `6c90a61`（v1.3.1）。
- 平台：Android、Windows 共用的 Flutter/Dart 代码与构建工具。
- 原则：优先修复可复现的构建回归和重复实现；不删除仍承担兼容、安全或平台适配职责的代码。

## 2. 已发现并解决的问题

### 2.1 修复最新版无法通过分析和测试编译的问题

最新解密流程引用了 18 个新的本地化字段，但中英文 ARB 和生成代码没有同步。基线运行 `flutter analyze` 时因此出现 29 个 `undefined_getter` 错误。

处理方式：

- 在 `app_en.arb`、`app_zh.arb` 中补齐密钥/暗号错误、文件损坏、密钥派生、完整性校验等双语提示；
- 删除已被精确错误提示取代且不再被代码引用的 `keyError`、`passphraseDecryptFailed` 资源；
- 重新生成 `AppLocalizations`；
- 保留解密逻辑通过错误码提供精确提示的设计，不退回硬编码字符串。
- 将错误密钥测试从代码中不存在的 `DECRYPTION_FAILED` 对齐到实际服务抛出的 `CHUNK_DECRYPTION_FAILED`，覆盖新的精确提示路径。

### 2.2 合并三套重复的富文本样式

编辑器、预览面板和阅读器分别维护了近乎相同的 Quill 标题、正文、列表、引用、代码块和斜体样式。三份实现容易在修改时发生显示差异，也重复触发相同的 API 弃用与风格问题。

处理方式：新增 `lib/presentation/widgets/quill_content_styles.dart`，由以下三个界面共用：

- `quill_editor.dart`
- `preview_panel.dart`
- `quill_viewer.dart`

共享实现统一处理亮色/暗色代码块颜色、文本间距和字体回退，删除约 270 行重复样式代码。

### 2.3 清理静态分析问题

清理内容包括：

- 异常捕获显式声明类型；
- 异步对话框返回后检查 `BuildContext` 是否仍有效；
- 移除无意义的空值断言；
- 使用命名零间距常量和新版颜色透明度 API；
- 修正无效文档引用、缺失尾逗号、可常量化构造和 Windows 路径原始字符串；
- 格式化受影响的 Dart 文件。

结果：静态分析由基线的 29 个错误和 47 个提示降为 `No issues found`。

### 2.4 删除历史临时产物

删除以下不参与运行、测试或构建的历史审查产物：

- `analyze_report.txt`：空白分析输出；
- `check_result.txt`：一次性的文档检查片段；
- `fix_doc.ps1`：绑定旧绝对路径 `C:\GitHub Repositories\StrawHut\Reference_Docs` 的一次性修补脚本。

保留 `tool/build_package.dart`，因为它仍是正式的 Windows/Android 打包工具，并同步修复其静态分析问题。

### 2.5 同步内部文档

- `CODE_WIKI.md` 的目录树移除了实际不存在的 `p2p/` 和 `app_bar.dart`；
- 补充当前的 Neumorphic 通用组件和共享 Quill 样式文件；
- `README.md` 文档版本同步到 v1.3.1。

## 3. 涉及文件

| 类别 | 文件 | 原因 |
|---|---|---|
| 本地化 | `lib/l10n/arb/app_en.arb`, `app_zh.arb`, `lib/l10n/generated/*` | 补齐解密错误提示并恢复编译 |
| 结构去重 | `lib/presentation/widgets/quill_content_styles.dart` | 单一维护富文本样式 |
| 编辑/阅读 | `preview_panel.dart`, `quill_editor.dart`, `quill_viewer.dart` | 使用共享样式并清理异常处理 |
| 工具栏 | `quill_toolbar.dart` | 修复异步上下文、文档和异常处理问题 |
| 打包工具 | `tool/build_package.dart` | 清理路径、格式和静态分析问题 |
| 文档 | `README.md`, `CODE_WIKI.md`, 本报告 | 与当前代码状态保持一致 |
| 删除 | `analyze_report.txt`, `check_result.txt`, `fix_doc.ps1` | 移除无效临时产物 |

## 4. 验证

提交前执行：

```text
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

验证结果：

- `flutter analyze --no-pub`：`No issues found`；
- `flutter test --no-pub`：`1272/1272` 通过；
- `flutter build windows --release --no-pub`：通过，生成 `strawhut.exe`；
- `git diff --check`：通过。

当前机器未安装 Android SDK（`flutter doctor -v` 报告 `Unable to locate Android SDK`），因此本次不能声明 APK/Android 原生构建已验证；Android 共用 Dart/Widget 逻辑已包含在全量 Flutter 测试中。

## 5. 有意保留与后续建议

- 旧版 `.straw` 迁移、纯 Dart 加密回退、临时文件管理、Android Intent/MediaStore 等代码仍有实际兼容或平台职责，因此未按“看起来旧”直接删除。
- 发布和解密界面目前分别维护桌面与移动布局，其中业务流程仍有较多相似代码。它们同时涉及取消、敏感数据擦除、流式加解密和导航生命周期；建议后续单独提取无 UI 的流程控制器，并增加取消/失败/成功后的状态机测试，再逐步合并，避免一次大改破坏安全流程。
- 依赖升级不属于本次低风险清理范围；尤其 `flutter_markdown` 已显示停止维护，建议在独立 PR 中评估替代包和渲染兼容性。
