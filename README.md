# 🌾 StrawHut

> **Let knowledge flow securely between people.**
> *让知识在人与人之间安全地传递。*

> ⚖️ **Compliance Notice**: This project is designed to protect personal privacy and knowledge security. Please comply with local laws and regulations and use it lawfully. It is strictly prohibited to use it for distributing illegal content or engaging in any unlawful activities.

<p align="center">
  <a href="#english">🇬🇧 English</a> · <a href="#中文">🇨🇳 中文</a>
</p>

***

<a name="english"></a>

## 🇬🇧 StrawHut — Local Encrypted Knowledge Card Tool

### 🏠 Overview

**StrawHut** is a **fully local** knowledge card encryption tool. Your content is encrypted before it ever leaves your device — no servers, no network requests, no persistent storage. Your knowledge, your keys, your control.

**✨ Privacy Core: Knowledge Card as PNG Image** — Encrypted knowledge is embedded into PNG image metadata. The image looks like a beautiful knowledge cover that any image viewer can display, but only StrawHut can read the content with the correct key. Share images via WeChat, Photos, AirDrop, or any channel — breaking the barrier of mobile sharing.

> 🌟 **Vision**: Let knowledge flow securely between people. Creators control their content, readers gain value, privacy is never compromised.

### 📥 Download

| Platform | Download | Requirements |
|----------|----------|--------------|
| **Windows** | [Download .exe](../../releases/latest) | Windows 10+ (19041+) |
| **Android (64-bit)** | [Download arm64-v8a APK](../../releases/latest) | Android 5.0+ (API 23+) |
| **Android (32-bit)** | [Download armeabi-v7a APK](../../releases/latest) | Android 5.0+ (API 23+) |

> Go to [Releases](../../releases/latest) to download the latest version.

### 🔐 Privacy Promise

| Promise | Description |
|---------|-------------|
| 🚫 **Zero Network Requests** | The app never sends or receives any network data; all content is processed locally |
| 🚫 **Zero Data Collection** | No user information, usage data, or analytics are collected |
| 🚫 **Zero Persistent Storage** | No knowledge cards, keys, drafts, or history are saved except for passphrases you explicitly save |
| 🔒 **End-to-End Encryption** | Content is encrypted locally with AES-256-GCM; only those with the key can decrypt |
| 🕶️ **Anonymous Publishing** | One-click anonymous mode; creator identity is completely hidden |
| 🗝️ **Key Is Permission** | Key files are independently managed by users; no key means no access; no backdoors |

### ✨ Features

| Feature | Description |
|---------|-------------|
| 🔒 **End-to-End Encryption** | AES-256-GCM with native API hardware acceleration (AES-NI) |
| 🖼️ **Knowledge as Image** | Encrypted content embedded in PNG metadata — beautiful cover, easy mobile sharing |
| 🤝 **Passphrase Key** | Derive encryption key from a passphrase (PBKDF2-HMAC-SHA256), perfect for verbal sharing |
| 📊 **Passphrase Strength** | Real-time strength assessment (Very Weak / Weak / Medium / Strong) with weak passphrase confirmation |
| 🔐 **Passphrase Vault** | Securely save passphrases locally, auto-match to decrypt incoming cards |
| 🏠 **Purely Local** | No servers, no network — data never leaves your device |
| 🗝️ **Key File Mode** | System-generated high-strength random keys, stored in separate `.key` files |
| 🕶️ **Anonymous Mode** | One-click anonymous publishing, fully protects creator identity |
| 📄 **Dual Format** | Export as `.straw` files or `.png` images, choose by scenario |
| 🛡️ **Integrity Check** | SHA-256 hash verification prevents tampering |
| 🧹 **Zero Traces** | No cards, keys, or drafts stored except for user-saved passphrases |

### 🖼️ PNG Knowledge Card — Image Is Knowledge

When publishing a knowledge card, you can embed encrypted content into a PNG image. The generated image looks like a carefully designed cover:

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

### 🔄 How It Works

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
            (WeChat / Photos / AirDrop / Email / ...)
  │                                       │
  │                          📥 Received .png image
  │                          📂 Open with StrawHut
  │                          🔓 Enter key or upload .key file
  │                          ✅ Integrity check passed
  │                          📖 Read knowledge content
```

**⚠️ Important:** When sharing as an image, always send the **original image**. Social media compression will strip the metadata containing encrypted content.

### 🔐 Encryption

- **AES-256-GCM** — Industry-standard authenticated encryption with native hardware acceleration (AES-NI)
- **PBKDF2-HMAC-SHA256** — 100,000 iterations for passphrase-based key derivation, with native API acceleration
- **12-byte IV** — NIST SP 800-38D recommended, with backward compatibility for 16-byte IV
- **CSPRNG** — Cryptographically secure random number generation (Android SecureRandom / Windows BCryptGenRandom)
- **Native-first architecture** — Platform native crypto APIs with automatic fallback to pure Dart implementation


***

<a name="中文"></a>

## 🇨🇳 StrawHut — 本地加密知识卡片工具

### 🏠 产品简介

**StrawHut** 是一个**完全运行在本地**的知识卡片加密工具。你的知识内容在离开设备之前就被加密，软件不依赖任何中心化服务器，不发送任何网络请求，除用户主动保存的暗号外不在本地保存任何数据——你的知识、你的密钥、你的控制权。

**✨ 隐私核心：知识卡片 PNG 图片** — 将加密后的知识嵌入 PNG 图片的元数据中，图片外观是一张精美的知识封面，任何图片查看器都能正常显示，但只有用 StrawHut 打开并输入密钥才能阅读内容。图片可以通过微信、相册、AirDrop 等任何渠道传输，彻底打通移动端分享壁垒。

> 🌟 **愿景**：让知识在人与人之间安全传递，创作者掌控内容，读者获得价值，隐私永不妥协。

### 📥 下载

| 平台 | 下载 | 系统要求 |
|------|------|----------|
| **Windows** | [下载 .exe](../../releases/latest) | Windows 10+ (19041+) |
| **Android (64位)** | [下载 arm64-v8a APK](../../releases/latest) | Android 5.0+ (API 23+) |
| **Android (32位)** | [下载 armeabi-v7a APK](../../releases/latest) | Android 5.0+ (API 23+) |

> 前往 [Releases](../../releases/latest) 下载最新版本。

### 🔐 隐私承诺

| 承诺 | 说明 |
|------|------|
| 🚫 **零网络请求** | 软件运行时不会发送或接收任何网络数据，所有内容在本地处理 |
| 🚫 **零数据收集** | 不收集任何用户信息、使用数据或分析数据 |
| 🚫 **零持久化存储** | 除用户主动保存的暗号外，不保存任何知识卡片、密钥、草稿或历史记录 |
| 🔒 **端到端加密** | 内容在本地即被 AES-256-GCM 加密，只有持有密钥的人才能解密 |
| 🕶️ **匿名发布** | 一键切换匿名模式，创作者身份完全隐藏，无任何可追溯信息 |
| 🗝️ **密钥即权限** | 密钥文件由用户独立保管，无密钥即无访问，无后门、无恢复机制 |

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🔒 **端到端加密** | AES-256-GCM 强加密，原生 API 硬件加速（AES-NI） |
| 🖼️ **知识即图片** | 加密内容嵌入 PNG 元数据，封面精美，传输便捷，适合移动端分享 |
| 🤝 **协商密钥加密** | 通过暗号派生密钥（PBKDF2-HMAC-SHA256），适合口头分享场景 |
| 📊 **暗号强度评估** | 实时评估暗号强度（极弱/弱/中/强），弱暗号二次确认机制 |
| 🔐 **暗号保险库** | 本地安全保存常用暗号，自动匹配解密暗号加密的知识卡片 |
| 🏠 **纯本地运行** | 无服务器、无网络请求，数据永不离开你的设备 |
| 🗝️ **密钥即权限** | 系统自动生成高强度随机密钥，密钥文件独立存储 |
| 🕶️ **匿名发布** | 一键切换匿名模式，完全保护创作者身份 |
| 📄 **双格式导出** | 支持 `.straw` 文件和 `.png` 图片两种格式，按场景自由选择 |
| 🛡️ **完整性校验** | SHA-256 哈希校验，防止文件被篡改 |
| 🧹 **零痕迹** | 除用户主动保存的暗号外，软件不保存任何卡片、密钥或草稿 |

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

### 🔄 使用流程

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
           (微信 / 朋友圈 / 相册 / AirDrop / 邮件 / ...)
  │                                       │
  │                          📥 接收到 .png 图片
  │                          📂 用 StrawHut 打开图片
  │                          🔓 输入密钥或上传 .key 文件
  │                          ✅ 完整性校验通过
  │                          📖 阅读知识内容
```

**⚠️ 重要提示：** 以图片形式分享时务必发送**原图**，社交平台压缩图片会丢失元数据中的加密内容。

### 🔐 加密技术

- **AES-256-GCM** — 业界标准认证加密，原生硬件加速（AES-NI）
- **PBKDF2-HMAC-SHA256** — 100,000 次迭代密钥派生，原生 API 加速
- **12 字节 IV** — NIST SP 800-38D 推荐值，向下兼容 16 字节 IV
- **CSPRNG** — 密码学安全伪随机数生成（Android SecureRandom / Windows BCryptGenRandom）
- **原生优先架构** — 优先使用平台原生加密 API，不可用时自动回退到纯 Dart 实现


***

## 📜 License

This project is open source. Contributions are welcome! 🌾

> **文档版本**: v1.0.0 | **最后更新**: 2026-06-15
