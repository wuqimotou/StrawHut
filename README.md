# 🌾 StrawHut

> **让知识在人与人之间安全、自由地传递。**
> *Let knowledge flow securely and freely between people.*

<p align="center">
  <a href="#中文">🇨🇳 中文</a> · <a href="#english">🇬🇧 English</a>
</p>

---

<a name="中文"></a>
## 🇨🇳  StrawHut — 本地知识卡片加密工具

### 🏠 产品简介

**StrawHut** 是一个**完全运行在本地**的知识卡片加密工具。它将你的知识内容加密为 `.straw` 格式文件，通过独立的 `.key` 密钥文件控制访问权限。软件不依赖任何中心化服务器，所有数据处理均在你的设备上完成。

> 🌟 **愿景**：让知识在人与人之间安全、自由地传递，创作者掌控内容，读者获得价值。

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🔒 **端到端加密** | AES-256-GCM 强加密，知识内容在本地即被加密 |
| 🏠 **纯本地运行** | 无服务器、无网络请求，数据永不离开你的设备 |
| 🗝️ **密钥即权限** | 系统自动生成高强度随机密钥，密钥文件独立存储 |
| 🕶️ **匿名发布** | 一键切换匿名模式，完全保护创作者身份 |
| 📄 **知识卡片化** | 结构化的 `.straw` 文件格式，便于知识独立传播 |
| 🛡️ **完整性校验** | SHA-256 哈希校验，防止文件被篡改 |
| 🧹 **零痕迹** | 软件不保存任何卡片、密钥或草稿，关闭后内存完全清空 |

### 🖥️ 界面预览

```
┌─────────────────────────────────────────────────┐
│  ←  编辑知识卡片                        [发布]   │
├─────────────────────────────────────────────────┤
│  [↶↷] [B I U S] [H▼] [列表] [代码] [图片] ...   │
├─────────────────────────────────────────────────┤
│                                                 │
│              富文本编辑区域                      │
│                                                 │
│          (所见即所得的 Markdown 渲染)            │
│                                                 │
├─────────────────────────────────────────────────┤
│              [👁 预览 / 返回编辑]                 │
└─────────────────────────────────────────────────┘
```

### 🔐 加密流程图

```
创作者                                    读者
  │                                       │
  ├── 📝 富文本编辑器撰写知识内容           │
  ├── 🚀 点击发布按钮                       │
  ├── 🎲 系统自动生成随机密钥               │
  ├── 📦 内容加密 + SHA-256 完整性校验     │
  ├── 💾 导出 .straw 文件                   │
  ├── 🔑 (可选) 导出 .key 密钥文件          │
  │                                       │
  ═══════ [ .straw 文件通过任意渠道传播 ] ════════
           (微信 / 邮件 / 云盘 / U盘 / ... )
  │                                       │
  │                          📥 接收到 .straw 文件
  │                          📂 用 StrawHut 打开
  │                          🔓 输入密钥或上传 .key 文件
  │                          ✅ 完整性校验通过
  │                          📖 阅读知识内容
```

### 🏗️ 技术架构

```
┌──────────────────────────────────────────────────────┐
│                    应用层 (UI)                        │
│  HomeScreen │ EditorScreen │ ReaderScreen │ Dialogs  │
├──────────────────────────────────────────────────────┤
│               核心服务层 (Services)                   │
│ CryptoService │ FileIOService │ DraftManager │ ...    │
├──────────────────────────────────────────────────────┤
│                  数据层 (Data)                        │
│       StrawFile │ KeyFile │ CardMeta │ Repository     │
├──────────────────────────────────────────────────────┤
│                   文件系统                            │
│              .straw 文件  │  .key 文件                │
└──────────────────────────────────────────────────────┘
```

| 技术栈 | 说明 |
|--------|------|
| **Flutter** | 跨平台 UI 框架，一套代码多端运行 |
| **flutter_quill** | 富文本编辑器，支持所见即所得编辑 |
| **Riverpod** | 状态管理，响应式数据流 |
| **encrypt** | AES-256-GCM 加密实现 |
| **file_selector** | 跨平台文件选择器 |
| **go_router** | 声明式路由导航 |

### 📦 .straw 文件格式

```json
{
  "format_version": "1.0.0",
  "meta": {
    "publisher_alias": "创作者代号",
    "publish_date": "2026-05-01T12:00:00Z",
    "title": "知识卡片标题",
    "tags": ["标签1", "标签2"],
    "is_anonymous": false
  },
  "content": {
    "encrypted_data": "Base64编码的加密内容",
    "encryption_algorithm": "AES-256-GCM",
    "iv": "Base64编码的初始化向量"
  },
  "integrity": {
    "hash": "sha256:abc123...",
    "hash_algorithm": "SHA-256"
  }
}
```

### 🚀 快速开始

#### 前置条件

- Flutter SDK >= 3.4.0
- Windows 10+ (19041+)

#### 安装与运行

```bash
# 1. 克隆仓库
git clone https://github.com/your-org/StrawHut.git
cd StrawHut

# 2. 安装依赖
cd strawhut
flutter pub get

# 3. 生成 Riverpod 代码
dart run build_runner build

# 4. 运行应用
flutter run -d windows
```

#### 构建发布版

```bash
flutter build windows --release
```

### 📁 项目结构

```
StrawHut/
├── strawhut/             # Flutter 应用主目录
│   ├── lib/
│   │   ├── core/         # 核心服务层（加密、文件、验证...）
│   │   ├── data/         # 数据模型与仓库
│   │   ├── presentation/ # UI 层（页面、对话框、状态管理）
│   │   ├── p2p/          # P2P 扩展预留（当前未实现）
│   │   └── app/          # 应用配置（路由、主题）
│   └── test/             # 单元测试（78+ 测试文件）
├── 项目架构说明.md         # 详细架构文档
└── PRD-去中心化加密知识分享平台.md  # 产品需求文档
```

### 🔮 未来规划

- [ ] Android 移动端适配
- [ ] iOS 移动端适配
- [ ] P2P 知识卡片网络（可选）
- [ ] 多媒体内容嵌入

---

<a name="english"></a>
## 🇬🇧 StrawHut — Local Encrypted Knowledge Card Tool

### 🏠 Overview

**StrawHut** is a **fully local** knowledge card encryption tool. It encrypts your knowledge content into `.straw` format files, with access controlled through independent `.key` files. The software doesn't rely on any centralized servers — all data processing happens on your device.

> 🌟 **Vision**: Let knowledge flow securely and freely between people. Creators control their content, readers gain value.

### ✨ Features

| Feature | Description |
|---------|-------------|
| 🔒 **End-to-End Encryption** | AES-256-GCM strong encryption, content encrypted locally |
| 🏠 **Purely Local** | No servers, no network requests — data never leaves your device |
| 🗝️ **Key Is Permission** | System generates strong random keys, stored in separate key files |
| 🕶️ **Anonymous Publishing** | One-click anonymous mode, fully protects creator identity |
| 📄 **Knowledge Cards** | Structured `.straw` format for independent knowledge sharing |
| 🛡️ **Integrity Verification** | SHA-256 hash verification to prevent tampering |
| 🧹 **Zero Traces** | No cards, keys, or drafts stored — memory fully cleared on exit |

### 🖥️ Interface Preview

```
┌─────────────────────────────────────────────────┐
│  ←  Edit Knowledge Card              [Publish]   │
├─────────────────────────────────────────────────┤
│  [↶↷] [B I U S] [H▼] [Lists] [Code] [Image]...  │
├─────────────────────────────────────────────────┤
│                                                 │
│              Rich Text Editor                    │
│                                                 │
│        (WYSIWYG Markdown rendering)              │
│                                                 │
├─────────────────────────────────────────────────┤
│              [👁 Preview / Back to Edit]          │
└─────────────────────────────────────────────────┘
```

### 🔐 Encryption Flow

```
Creator                                   Reader
  │                                       │
  ├── 📝 Write knowledge in rich text     │
  ├── 🚀 Click Publish button              │
  ├── 🎲 System auto-generates random key  │
  ├── 📦 Content encrypted + SHA-256 hash │
  ├── 💾 Export .straw file                │
  ├── 🔑 (Optional) Export .key file       │
  │                                       │
  ════════ [ .straw file shared via any channel ] ════════
            (WeChat / Email / Cloud Drive / USB / ... )
  │                                       │
  │                          📥 Received .straw file
  │                          📂 Open with StrawHut
  │                          🔓 Enter key or upload .key file
  │                          ✅ Integrity check passed
  │                          📖 Read knowledge content
```

### 🏗️ Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Application Layer (UI)               │
│  HomeScreen │ EditorScreen │ ReaderScreen │ Dialogs  │
├──────────────────────────────────────────────────────┤
│                  Core Service Layer                   │
│ CryptoService │ FileIOService │ DraftManager │ ...    │
├──────────────────────────────────────────────────────┤
│                    Data Layer                         │
│       StrawFile │ KeyFile │ CardMeta │ Repository     │
├──────────────────────────────────────────────────────┤
│                   File System                         │
│              .straw Files  │  .key Files               │
└──────────────────────────────────────────────────────┘
```

| Tech Stack | Description |
|------------|-------------|
| **Flutter** | Cross-platform UI framework, one codebase for all platforms |
| **flutter_quill** | Rich text editor with WYSIWYG support |
| **Riverpod** | State management with reactive data flow |
| **encrypt** | AES-256-GCM encryption implementation |
| **file_selector** | Cross-platform file picker |
| **go_router** | Declarative routing |

### 📦 .straw File Format

```json
{
  "format_version": "1.0.0",
  "meta": {
    "publisher_alias": "Creator Alias",
    "publish_date": "2026-05-01T12:00:00Z",
    "title": "Knowledge Card Title",
    "tags": ["Tag1", "Tag2"],
    "is_anonymous": false
  },
  "content": {
    "encrypted_data": "Base64 encoded encrypted content",
    "encryption_algorithm": "AES-256-GCM",
    "iv": "Base64 encoded initialization vector"
  },
  "integrity": {
    "hash": "sha256:abc123...",
    "hash_algorithm": "SHA-256"
  }
}
```

### 🚀 Quick Start

#### Prerequisites

- Flutter SDK >= 3.4.0
- Windows 10+ (19041+)

#### Install & Run

```bash
# 1. Clone the repository
git clone https://github.com/your-org/StrawHut.git
cd StrawHut

# 2. Install dependencies
cd strawhut
flutter pub get

# 3. Generate Riverpod code
dart run build_runner build

# 4. Run the app
flutter run -d windows
```

#### Build Release

```bash
flutter build windows --release
```

### 📁 Project Structure

```
StrawHut/
├── strawhut/             # Flutter application main directory
│   ├── lib/
│   │   ├── core/         # Core services (crypto, file I/O, validation...)
│   │   ├── data/         # Data models and repositories
│   │   ├── presentation/ # UI layer (screens, dialogs, state management)
│   │   ├── p2p/          # P2P extension reserved (not yet implemented)
│   │   └── app/          # App configuration (routing, theme)
│   └── test/             # Unit tests (78+ test files)
├── 项目架构说明.md         # Detailed architecture document
└── PRD-去中心化加密知识分享平台.md  # Product Requirements Document
```

### 🔮 Roadmap

- [ ] Android mobile support
- [ ] iOS mobile support
- [ ] P2P knowledge card network (optional)
- [ ] Multimedia content embedding

---

## 📜 License

This project is open source. Contributions are welcome! 🌾

> **文档版本**: v0.1.0 | **最后更新**: 2026-05-03
