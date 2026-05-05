# StrawHut - 草棚

StrawHut 是一个纯本地运行的去中心化加密知识分享平台。用户在本地编写知识内容，加密后导出为 `.straw` 文件或 `.png` 图片，通过任何渠道分享给他人。接收方使用 StrawHut 打开文件并输入密钥/暗号后即可解密阅读。

## 核心特性

- **AES-256-GCM 加密** - 行业级加密标准，确保知识内容安全
- **两种加密模式** - 随机密钥模式（高强度）和协商密钥模式（暗号派生，适合口头分享）
- **纯本地运行** - 所有功能在用户设备上执行，无任何网络请求
- **零持久化存储** - 不保存任何卡片、密钥或草稿，关闭后内存完全清空
- **PNG 知识卡片** - 将加密内容嵌入 PNG 图片元数据，可通过社交软件便捷传输
- **跨平台支持** - Windows 桌面端 + Android 移动端

## 平台支持

| 平台 | 支持状态 | 说明 |
|------|---------|------|
| Windows | 完全支持 | 桌面端原版，支持拖拽文件 |
| Android | 支持（v0.5.0+） | 移动端适配，支持 Intent 接收、分享、响应式 UI |
| macOS / iOS / Linux | 兼容运行 | 未做专项适配，可正常运行 |

### Android 特性

- **文件选择** - 使用系统文件选择器打开 `.straw` / `.png` / `.key` 文件
- **Intent 接收** - 支持从文件管理器、相册等外部应用通过 "打开方式" 接收文件
- **文件分享** - 发布 PNG 卡片后可直接通过系统分享菜单发送
- **响应式 UI** - 全屏发布对话框、底部弹出解密对话框、水平滚动工具栏
- **返回键支持** - 编辑器返回确认、阅读器状态清理、主页双击退出
- **生命周期管理** - 进入后台提醒、恢复时草稿提示
- **MediaStore 通知** - 保存的 PNG 图片立即可在相册中查看

## 文件格式

### .straw - 知识卡片

JSON 格式的加密知识卡片文件，包含元数据（公开可见）和加密内容。

```json
{
  "format_version": "1.1.0",
  "meta": { "title": "网络安全入门指南", ... },
  "content": { "encrypted_data": "...", "iv": "..." },
  "integrity": { "hash": "sha256:...", "hash_algorithm": "SHA-256" }
}
```

### .png - 图片知识卡片

外观为普通图片，内部 tEXt chunk 嵌入了完整的加密知识卡片数据。

### .key - 密钥文件

独立保存的加密密钥文件，可与知识卡片分开传输。

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter | 跨平台 UI 框架 |
| Riverpod | 响应式状态管理 |
| flutter_quill | 富文本编辑器 |
| encrypt / pointycastle | AES-256-GCM 加密 |
| image | 图片压缩与 PNG 编码 |
| file_picker / file_selector | 文件选择 |
| share_plus | 文件分享（Android） |
| receive_sharing_intent | Intent 接收（Android） |
| go_router | 声明式路由 |
| media_scanner | MediaStore 扫描（Android） |
| permission_handler | 权限管理（Android） |

## 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Windows 10+ 或 Android 5.0+ (API 23+)

### 安装与运行

```bash
# 克隆项目
git clone <repository-url>
cd strawhut

# 安装依赖
flutter pub get

# 生成代码（Riverpod / i18n）
dart run build_runner build
flutter gen-l10n

# 运行
flutter run
```

### 构建 Android APK

```bash
# Debug 版本
flutter build apk --debug

# Release 版本（需配置签名）
flutter build apk --release

# 分 ABI 构建（减小体积）
flutter build apk --split-per-abi --release
```

## 项目结构

```
strawhut/
├── lib/
│   ├── core/              # 核心服务层（加密、文件 I/O、草稿、验证）
│   ├── data/              # 数据层（模型、仓库）
│   ├── presentation/      # 应用层（页面、对话框、Provider）
│   ├── app/               # 应用配置（路由、主题、Intent 处理）
│   └── p2p/               # P2P 扩展预留
├── android/               # Android 平台配置
├── windows/               # Windows 平台配置
└── test/                  # 单元测试（800+ 用例）
```

## 安全架构

- **AES-256-GCM** - 对称加密，认证加密模式（AEAD）
- **PBKDF2-HMAC-SHA256** - 暗号派生密钥，100,000 次迭代
- **CSPRNG** - 安全随机数生成器用于密钥和盐值
- **SHA-256 完整性校验** - 防止文件篡改
- **内存安全** - 敏感数据使用后逐字节置零

## 文档

- [项目架构说明](../项目架构说明.md) - 完整的架构设计文档
- [产品需求文档](../prd/PRD-去中心化加密知识分享平台.md)
- [Android 适配需求](../prd/PRD-StrawHut-Android适配.md)

## 开源协议

本项目遵循开源协议，详情请见 LICENSE 文件。
