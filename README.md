# 🌾 StrawHut

> **让知识在人与人之间安全地传递。**
> *Let knowledge flow securely between people.*

> ⚖️ **合规声明**：本项目旨在保护个人隐私与知识安全，请遵守当地法律法规，正当合法使用。严禁用于传播违法违规内容或从事任何非法活动。

<p align="center">
  <a href="#中文">🇨🇳 中文</a> · <a href="#english">🇬🇧 English</a>
</p>

***

<a name="中文"></a>

## 🇨🇳 StrawHut — 本地加密知识卡片工具

### 🏠 产品简介

**StrawHut** 是一个**完全运行在本地**的知识卡片加密工具。你的知识内容在离开设备之前就被加密，软件不依赖任何中心化服务器，不发送任何网络请求，不在本地保存任何数据——你的知识、你的密钥、你的控制权。

**✨ 隐私核心：知识卡片 PNG 图片** — 将加密后的知识嵌入 PNG 图片的元数据中，图片外观是一张精美的知识封面，任何图片查看器都能正常显示，但只有用 StrawHut 打开并输入密钥才能阅读内容。图片可以通过微信、相册、AirDrop 等任何渠道传输，彻底打通移动端分享壁垒。

> 🌟 **愿景**：让知识在人与人之间安全传递，创作者掌控内容，读者获得价值，隐私永不妥协。

### 🔐 隐私承诺

| 承诺 | 说明 |
|------|------|
| 🚫 **零网络请求** | 软件运行时不会发送或接收任何网络数据，所有内容在本地处理 |
| 🚫 **零数据收集** | 不收集任何用户信息、使用数据或分析数据 |
| 🚫 **零持久化存储** | 不保存任何知识卡片、密钥、草稿或历史记录，关闭后内存完全清空 |
| 🔒 **端到端加密** | 内容在本地即被 AES-256-GCM 加密，只有持有密钥的人才能解密 |
| 🕶️ **匿名发布** | 一键切换匿名模式，创作者身份完全隐藏，无任何可追溯信息 |
| 🗝️ **密钥即权限** | 密钥文件由用户独立保管，无密钥即无访问，无后门、无恢复机制 |

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🔒 **端到端加密** | AES-256-GCM 强加密，知识内容在本地即被加密，图片中嵌入的也是密文 |
| 🖼️ **知识即图片** | 将加密内容嵌入 PNG 图片元数据，封面精美，传输便捷，适合移动端分享 |
| 🤝 **协商密钥加密** | 通过暗号派生密钥（PBKDF2-HMAC-SHA256），适合口头分享场景 |
| 📊 **暗号强度评估** | 实时评估暗号强度（极弱/弱/中/强），弱暗号二次确认机制 |
| 🏠 **纯本地运行** | 无服务器、无网络请求，数据永不离开你的设备 |
| 🗝️ **密钥即权限** | 系统自动生成高强度随机密钥，密钥文件独立存储 |
| 🕶️ **匿名发布** | 一键切换匿名模式，完全保护创作者身份 |
| 📄 **双格式导出** | 支持 `.straw` 文件和 `.png` 图片两种格式，按场景自由选择 |
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

### 🖼️ PNG 知识卡片 — 图片即知识

发布知识卡片时，你可以选择将加密内容嵌入 PNG 图片。生成的图片外观是一张精心设计的封面：

```
┌─────────────────────────────────────────┐
│  STRAWHUT                               │
│  ━━━━                                   │
│                                         │
│              ┌ 🔒 已加密 ┐              │
│                                         │
│           网络安全入门指南                │
│                                         │
│      [安全] [入门] [笔记]                │
│      一份关于网络安全基础的...            │
│                                         │
│           作者：Anonymous                │
│           2026.05.04                    │
└─────────────────────────────────────────┘
```

**它仍然是一张合法的 PNG 图片** — 任何图片查看器都能正常显示封面。但封面之下，完整的加密知识内容被隐藏在 PNG 元数据中。

**分享与接收：**

```
创作者                                    读者
  │                                       │
  ├── 📝 富文本编辑器撰写知识              │
  ├── 🚀 点击发布 → 选择 .png 格式         │
  ├── 🎨 自定义封面或自动生成              │
  ├── 📦 内容加密 → 嵌入 PNG 元数据       │
  ├── 💾 保存为 .png 图片                  │
  │                                       │
  ═══════ [ .png 图片通过任意渠道传播 ] ════════
           (微信 / 朋友圈 / 相册 / AirDrop / ...)
  │                                       │
  │                          📥 接收到 .png 图片
  │                          📂 用 StrawHut 打开图片
  │                          🔓 输入密钥或上传 .key 文件
  │                          ✅ 完整性校验通过
  │                          📖 阅读知识内容
```

**⚠️ 重要提示：** 以图片形式分享时务必发送**原图**，社交平台压缩图片会丢失元数据中的加密内容。

### 🔐 加密流程对比

```
创作者                                    读者
  │                                       │
  ├── 📝 富文本编辑器撰写知识内容           │
  ├── 🚀 点击发布按钮                       │
  ├── 📋 选择导出格式                       │
  │   ├── .straw 文件 → 标准加密文件        │
  │   └── .png 图片 → 封面+加密元数据       │
  ├── 🎲 系统自动生成随机密钥               │
  ├── 📦 内容加密 + SHA-256 完整性校验     │
  ├── 💾 导出 .straw 或 .png 文件           │
  ├── 🔑 (可选) 导出 .key 密钥文件          │
  │                                       │
  ═══════ [ 文件通过任意渠道传播 ] ════════
           (微信 / 邮件 / 云盘 / U盘 / ...)
  │                                       │
  │                          📥 接收到 .straw 或 .png 文件
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

| **技术栈** | 说明 |
|--------|------|
| **Flutter** | 跨平台 UI 框架，一套代码多端运行 |
| **flutter_quill** | 富文本编辑器，支持所见即所得编辑 |
| **Riverpod** | 状态管理，响应式数据流 |
| **encrypt** | AES-256-GCM 加密实现 |
| **image** | 纯 Dart 图片处理（压缩 + PNG 编码，全平台通用） |
| **file_selector** | 跨平台文件选择器 |
| **go_router** | 声明式路由导航 |

### 📦 .straw 文件格式

```json
{
  "format_version": "1.1.0",
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
    "iv": "Base64编码的初始化向量",
    "salt": "Base64编码的盐值（协商密钥模式）",
    "kdf_algorithm": "PBKDF2-HMAC-SHA256",
    "kdf_iterations": 100000
  },
  "integrity": {
    "hash": "sha256:abc123...",
    "hash_algorithm": "SHA-256"
  }
}
```

### 🔐 加密算法

| 算法 | 说明 |
|------|------|
| **AES-256-GCM** | 对称加密算法，256 位密钥，GCM 认证加密模式 |
| **PBKDF2-HMAC-SHA256** | 密钥派生函数，100,000 次迭代（协商密钥模式） |
| **CSPRNG** | 密码学安全伪随机数生成器，用于生成密钥和盐值 |
| **16 字节随机盐值** | CSPRNG 生成的盐值，确保相同暗号派生不同密钥 |
| **SHA-256** | 哈希校验算法，确保文件完整性 |

### 🚀 快速开始

#### 前置条件

- Flutter SDK >= 3.4.0
- Windows 10+ (19041+)
- Android 5.0+ (API 23+)

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
# Windows
flutter build windows --release

# Android
flutter build apk --release
```

### 📁 项目结构

```
StrawHut/
├── strawhut/             # Flutter 应用主目录
│   ├── lib/
│   │   ├── core/         # 核心服务层（加密、文件、验证、图片...）
│   │   ├── data/         # 数据模型与仓库
│   │   ├── presentation/ # UI 层（页面、对话框、状态管理）
│   │   ├── p2p/          # P2P 扩展预留（当前未实现）
│   │   └── app/          # 应用配置（路由、主题）
│   └── test/             # 单元测试（78+ 测试文件）
├── 项目架构说明.md         # 详细架构文档
└── PRD-去中心化加密知识分享平台.md  # 产品需求文档
```

### 🔮 未来规划

- [x] Android 移动端适配
- [ ] iOS 移动端适配
- [ ] P2P 知识卡片网络（可选）
- [ ] 多媒体内容嵌入

***

<a name="english"></a>

## 🇬🇧 StrawHut — Local Encrypted Knowledge Card Tool

### 🏠 Overview

**StrawHut** is a **fully local** knowledge card encryption tool. Your knowledge content is encrypted before it ever leaves your device. The software doesn't rely on any centralized servers, sends no network requests, and stores nothing locally — your knowledge, your keys, your control.

**✨ Privacy Core: Knowledge Card as PNG Image** — Encrypted knowledge is embedded into PNG image metadata. The image looks like a beautiful knowledge cover that any image viewer can display, but only StrawHut can read the content with the correct key. Images can be shared via WeChat, Photos, AirDrop, or any channel — breaking the barrier of mobile sharing.

> 🌟 **Vision**: Let knowledge flow securely between people. Creators control their content, readers gain value, privacy is never compromised.

### 🔐 Privacy Promise

| Promise | Description |
|---------|-------------|
| 🚫 **Zero Network Requests** | The app never sends or receives any network data; all content is processed locally |
| 🚫 **Zero Data Collection** | No user information, usage data, or analytics are collected |
| 🚫 **Zero Persistent Storage** | No knowledge cards, keys, drafts, or history are saved; memory is fully cleared on exit |
| 🔒 **End-to-End Encryption** | Content is encrypted locally with AES-256-GCM; only those with the key can decrypt |
| 🕶️ **Anonymous Publishing** | One-click anonymous mode; creator identity is completely hidden with no traceable information |
| 🗝️ **Key Is Permission** | Key files are independently managed by users; no key means no access; no backdoors, no recovery |

### ✨ Features

| Feature | Description |
|---------|-------------|
| 🔒 **End-to-End Encryption** | AES-256-GCM strong encryption, content encrypted locally |
| 🖼️ **Knowledge as Image** | Encrypted content embedded in PNG metadata, beautiful cover, easy sharing for mobile |
| 🤝 **Negotiated Key Encryption** | Derive key from passphrase (PBKDF2-HMAC-SHA256), suitable for verbal sharing |
| 📊 **Passphrase Strength Evaluation** | Real-time strength assessment (Very Weak/Weak/Medium/Strong), weak passphrase confirmation |
| 🏠 **Purely Local** | No servers, no network requests — data never leaves your device |
| 🗝️ **Key Is Permission** | System generates strong random keys, stored in separate key files |
| 🕶️ **Anonymous Publishing** | One-click anonymous mode, fully protects creator identity |
| 📄 **Dual Format Export** | Support `.straw` files and `.png` images, choose by scenario |
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

### 🖼️ PNG Knowledge Card — Image Is Knowledge

When publishing a knowledge card, you can choose to embed encrypted content into a PNG image. The generated image looks like a carefully designed cover:

```
┌─────────────────────────────────────────┐
│  STRAWHUT                               │
│  ━━━━                                   │
│                                         │
│              ┌ 🔒 Encrypted ┐           │
│                                         │
│        Getting Started with Security     │
│                                         │
│      [Security] [Basics] [Notes]        │
│      A guide about network security...   │
│                                         │
│           Author: Anonymous              │
│           2026.05.04                     │
└─────────────────────────────────────────┘
```

**It's still a valid PNG image** — any image viewer can display the cover. But beneath the cover, the full encrypted knowledge content is hidden in the PNG metadata.

**Sharing & Receiving:**

```
Creator                                   Reader
  │                                       │
  ├── 📝 Write knowledge in rich text     │
  ├── 🚀 Publish → choose .png format     │
  ├── 🎨 Custom or auto-generated cover   │
  ├── 📦 Content encrypted → PNG metadata │
  ├── 💾 Save as .png image               │
  │                                       │
  ════ [ .png image shared via any channel ] ════
            (WeChat / Moments / Photos / AirDrop / ...)
  │                                       │
  │                          📥 Received .png image
  │                          📂 Open with StrawHut
  │                          🔓 Enter key or upload .key
  │                          ✅ Integrity check passed
  │                          📖 Read knowledge content
```

**⚠️ Important:** When sharing as an image, always send the **original image**. Social media compression will strip the metadata containing encrypted content.

### 🔐 Encryption Flow

```
Creator                                   Reader
  │                                       │
  ├── 📝 Write knowledge in rich text     │
  ├── 🚀 Click Publish button              │
  ├── 📋 Choose export format               │
  │   ├── .straw file → standard format     │
  │   └── .png image → cover + metadata     │
  ├── 🎲 System auto-generates random key  │
  ├── 📦 Content encrypted + SHA-256 hash │
  ├── 💾 Export .straw or .png file         │
  ├── 🔑 (Optional) Export .key file       │
  │                                       │
  ════════ [ File shared via any channel ] ════════
            (WeChat / Email / Cloud Drive / USB / ... )
  │                                       │
  │                          📥 Received .straw or .png file
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
  "format_version": "1.1.0",
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
    "iv": "Base64 encoded initialization vector",
    "salt": "Base64 encoded salt (negotiated key mode)",
    "kdf_algorithm": "PBKDF2-HMAC-SHA256",
    "kdf_iterations": 100000
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
- Android 5.0+ (API 23+)

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
# Windows
flutter build windows --release

# Android
flutter build apk --release
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

- [x] Android mobile support
- [ ] iOS mobile support
- [ ] P2P knowledge card network (optional)
- [ ] Multimedia content embedding

***

## 📜 License

This project is open source. Contributions are welcome! 🌾

> **文档版本**: v0.3.0 | **最后更新**: 2026-05-04
