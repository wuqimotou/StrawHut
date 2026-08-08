# StrawHut Code Wiki

> **文档版本**: v1.3.0 | **最后更新**: 2026-08-08

---

## 目录

1. [项目概述](#1-项目概述)
2. [项目架构](#2-项目架构)
3. [核心模块详解](#3-核心模块详解)
   - [3.1 应用入口层 (app/)](#31-应用入口层-app)
   - [3.2 核心服务层 (core/)](#32-核心服务层-core)
   - [3.3 数据模型层 (data/)](#33-数据模型层-data)
   - [3.4 表现层 (presentation/)](#34-表现层-presentation)
   - [3.5 国际化 (l10n/)](#35-国际化-l10n)
   - [3.6 P2P模块 (p2p/)](#36-p2p模块-p2p)
4. [关键数据流](#4-关键数据流)
5. [依赖关系](#5-依赖关系)
6. [项目运行方式](#6-项目运行方式)
7. [文件格式规范](#7-文件格式规范)
8. [加密技术规范](#8-加密技术规范)
9. [测试套件](#9-测试套件)
10. [原生平台代码](#10-原生平台代码)
11. [完整依赖清单](#11-完整依赖清单)

---

## 1. 项目概述

**StrawHut**（草棚）是一个**完全运行在本地**的去中心化加密知识分享平台。基于 Flutter 框架开发，支持 Windows 桌面端和 Android 移动端。应用采用 AES-256-GCM 端到端加密，零网络请求，零数据收集，零持久化存储（除用户主动保存的暗号外）。

### 核心技术栈

| 层级 | 技术选型 |
|------|----------|
| 框架 | Flutter 3.4+ (Dart SDK) |
| 状态管理 | Riverpod 2.6+ (代码生成) |
| 路由 | go_router 14.6+ |
| 富文本编辑 | flutter_quill 11.5+ |
| 加密 | encrypt 5.0 + pointycastle 3.9 + crypto 3.0 |
| 文件选择 | file_picker 11.0+ |
| 安全存储 | flutter_secure_storage 9.2+ |
| 国际化 | flutter_localizations |
| 代码分析 | very_good_analysis 7.0+ |

### 版本号

- 当前版本: `1.3.0+7`
- 文件格式版本: `.straw v2.1.0`（二进制容器格式，v2.1 增强容器认证）

---

## 2. 项目架构

### 分层架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                     应用入口层 (main.dart + app/)                 │
│  main() → ProviderScope → StrawHutApp → MaterialApp.router       │
├─────────────────────────────────────────────────────────────────┤
│                     表现层 (presentation/)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │  Screens  │  │  Dialogs │  │  Widgets │  │    Providers     │ │
│  │  HomeScreen│  │  Publish  │  │  AppBar │  │  CurrentCard    │ │
│  │  EditorScreen│ │  Decrypt │  │  ErrorBanner│ │  EditorContent │ │
│  │  ReaderScreen│ │  Migration│ │  Loading...│ │  CryptoService │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                     数据层 (data/)                                │
│  ┌───────────────┐  ┌───────────────────┐                        │
│  │  Models        │  │  Repositories      │                       │
│  │  StrawFile     │  │  FileRepository    │                       │
│  │  CardMeta      │  └───────────────────┘                       │
│  │  KeyFile       │                                              │
│  └───────────────┘                                              │
├─────────────────────────────────────────────────────────────────┤
│                   核心服务层 (core/)                               │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌────────────────────┐ │
│  │  Crypto   │ │ File I/O │ │ Integrity │ │ PassphraseVault    │ │
│  │  Service  │ │ Service  │ │ Service   │ │ Service            │ │
│  └──────────┘ └──────────┘ └───────────┘ └────────────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌────────────────────┐ │
│  │ Migration │ │  Draft   │ │ Validation│ │  Platform (Android │ │
│  │ Service   │ │ Manager  │ │ Validator │ │  FileSaver, etc)   │ │
│  └──────────┘ └──────────┘ └───────────┘ └────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Utils: MemoryUtils, Base64Utils, TempFileManager,           │ │
│  │         CancellationToken, CoverImageService, DateUtils       │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Errors: StrawHutException, CryptoException, FileException,   │ │
│  │          FormatException                                      │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 目录结构

```
lib/
├── main.dart                        # 应用入口
├── app/
│   ├── app.dart                     # MaterialApp 根组件配置
│   ├── routes.dart                  # go_router 路由定义
│   └── theme.dart                   # 亮色/暗色主题配置
├── core/
│   ├── crypto/
│   │   ├── crypto_constants.dart    # 加密常量定义
│   │   ├── crypto_models.dart       # 加密模型聚合导出
│   │   ├── crypto_service.dart      # 加密服务接口与实现
│   │   ├── passphrase_strength_service.dart  # 暗号强度评估
│   │   ├── crypto_models/           # 加密相关数据模型
│   │   │   ├── chunk_info.dart
│   │   │   ├── content_type_classifier.dart
│   │   │   ├── decryption_result.dart
│   │   │   ├── encrypt_result.dart
│   │   │   ├── encrypted_content.dart
│   │   │   ├── generated_key.dart
│   │   │   ├── passphrase_strength.dart
│   │   │   ├── payload_metadata.dart
│   │   │   └── source_type.dart
│   │   └── native/                  # 原生加密实现
│   │       ├── fallback_crypto_service.dart
│   │       ├── ffi_crypto_channel.dart
│   │       ├── method_channel_crypto_channel.dart
│   │       ├── native_crypto_service.dart
│   │       ├── parallel_chunk_processor.dart  # 多核并行分块处理器
│   │       ├── platform_crypto_channel.dart
│   │       └── windows_crypto_ffi.dart
│   ├── draft/
│   │   ├── draft_manager.dart       # 内存草稿管理器
│   │   └── draft_models.dart
│   ├── errors/
│   │   ├── crypto_exception.dart
│   │   ├── file_exception.dart
│   │   ├── format_exception.dart
│   │   └── strawhut_exception.dart
│   ├── file_io/
│   │   ├── file_extensions.dart
│   │   ├── file_io_service.dart     # 文件读写服务
│   │   └── file_selection_service.dart  # 文件选择服务
│   ├── integrity/
│   │   ├── integrity_constants.dart
│   │   └── integrity_service.dart   # SHA-256 / HMAC-SHA256 完整性校验
│   ├── migration/
│   │   └── migration_service.dart   # 旧版格式迁移
│   ├── passphrase_vault/
│   │   ├── passphrase_entry.dart
│   │   ├── passphrase_vault_constants.dart
│   │   ├── passphrase_vault_exception.dart
│   │   └── passphrase_vault_service.dart  # 暗号保险库
│   ├── platform/
│   │   ├── android_file_saver.dart  # Android 文件保存
│   │   └── intent_handler.dart      # Android Intent 处理
│   ├── utils/
│   │   ├── base64_utils.dart
│   │   ├── cancellation_token.dart
│   │   ├── cover_image_service.dart # PNG 封面生成/提取
│   │   ├── date_utils.dart
│   │   ├── image_service.dart
│   │   ├── memory_utils.dart        # 敏感数据内存清理
│   │   └── temp_file_manager.dart   # 临时文件管理
│   └── validation/
│       ├── format_validator.dart    # 文件格式验证器
│       └── validation_result.dart
├── data/
│   ├── models/
│   │   ├── card_meta.dart           # 卡片元数据模型
│   │   ├── format_version.dart      # 格式版本
│   │   ├── integrity_info.dart      # 完整性信息
│   │   ├── key_file.dart            # 密钥文件模型
│   │   ├── parsed_straw_file.dart   # 解析后的.straw文件
│   │   ├── straw_content.dart       # 加密内容描述
│   │   └── straw_file.dart          # .straw文件主模型
│   └── repositories/
│       └── file_repository.dart     # 文件仓库（仓储模式）
├── l10n/                            # 国际化
│   ├── arb/
│   │   ├── app_en.arb
│   │   └── app_zh.arb
│   ├── generated/
│   └── l10n.dart
├── p2p/                             # P2P模块（预留）
│   ├── p2p_interface.dart
│   ├── p2p_models.dart
│   └── p2p_stub.dart
└── presentation/
    ├── dialogs/
    │   ├── decrypt_dialog/          # 解密对话框
    │   ├── migration_dialog/        # 迁移对话框
    │   ├── passphrase_vault_dialog/ # 暗号保险库对话框
    │   └── publish_dialog/          # 发布对话框
    ├── providers/
    │   ├── card_provider.dart       # 卡片状态管理
    │   ├── crypto_provider.dart     # 加密服务依赖注入
    │   ├── editor_provider.dart     # 编辑器状态管理
    │   ├── locale_provider.dart     # 语言设置
    │   ├── migration_provider.dart  # 迁移状态管理
    │   ├── passphrase_vault_provider.dart
    │   ├── picked_file_provider.dart
    │   └── theme_provider.dart      # 主题设置
    ├── screens/
    │   ├── editor/                  # 编辑器页面
    │   ├── home/                    # 首页
    │   └── reader/                  # 阅读器页面
    └── widgets/                     # 通用组件
        ├── app_bar.dart
        ├── error_banner.dart
        ├── loading_indicator.dart
        ├── platform_adaptive_button.dart
        └── responsive_utils.dart
```

---

## 3. 核心模块详解

### 3.1 应用入口层 (app/)

#### main.dart — 应用入口点

[main.dart](file:///c:/GitHub Repositories/StrawHut/lib/main.dart)

应用启动函数，负责：

1. 初始化 Flutter 框架 (`WidgetsFlutterBinding.ensureInitialized()`)
2. 配置全局错误捕获 (`FlutterError.onError` + `PlatformDispatcher.instance.onError`)
3. 使用 `ProviderScope` 包裹应用以启用 Riverpod 状态管理
4. 调用 `runApp` 启动 `StrawHutApp`

#### app.dart — 应用根组件

[app.dart](file:///c:/GitHub Repositories/StrawHut/lib/app/app.dart)

`StrawHutApp` 是 `ConsumerStatefulWidget`，负责：

- 配置 Material 3 亮色/暗色主题
- 集成 go_router 路由系统
- 配置中英文本地化（flutter_localizations + flutter_quill）
- 跨平台中文字体支持（微软雅黑/苹方/思源黑体）
- Android Intent 处理（接收外部应用分享的文件）

#### routes.dart — 路由配置

[routes.dart](file:///c:/GitHub Repositories/StrawHut/lib/app/routes.dart)

| 路径 | 页面 | 说明 |
|------|------|------|
| `/` | HomeScreen | 首页，应用默认路由 |
| `/editor` | EditorScreen | 编辑器页面，新建/编辑知识卡片 |
| `/reader` | ReaderScreen | 阅读器页面，查看解密后的内容 |

#### theme.dart — 主题配置

[theme.dart](file:///c:/GitHub Repositories/StrawHut/lib/app/theme.dart)

- Material 3 设计规范，主色调为绿色 (Colors.green)
- 亮色/暗色主题各配置完整的 TextTheme + ButtonTheme
- 跨平台中文字体回退链

---

### 3.2 核心服务层 (core/)

#### 3.2.1 加密服务 (crypto/)

##### crypto_service.dart — 加密服务接口与实现

[crypto_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_service.dart)

**核心接口：`ICryptoService`**

| 方法 | 说明 |
|------|------|
| `generateKey()` | 使用 CSPRNG 生成 32 字节 AES-256 密钥 |
| `deriveKeyFromPassphrase()` | PBKDF2-HMAC-SHA256 从口令派生密钥，通过 `Flutter.compute()` 在后台 Isolate 执行 |
| `encrypt()` | 统一加密接口：分块加密，第一块含 PayloadMetadata 前缀；`useV21Security` 控制是否绑定 AAD；支持 `cancellationToken` 取消 |
| `decrypt()` | 统一解密接口：还原 PayloadMetadata + PayloadBytes；`useV21Security` 控制是否验证 AAD；支持 `cancellationToken` 取消 |
| `encryptStream()` | 流式加密（大文件）：从文件逐块读取加密；支持 `useV21Security`；支持 `cancellationToken` 取消 |
| `decryptStream()` | 流式解密（大文件）：从 .straw 文件逐块解密写入目标文件；支持 `useV21Security`；支持 `cancellationToken` 取消 |
| `decryptLegacyContent()` | 解密旧版单块加密内容 |
| `deriveHmacKey()` | v2.1 容器认证：从加密密钥派生 HMAC 密钥（`HMAC-SHA256(encKey, LABEL)`） |
| `clearSensitiveData()` | 清理敏感数据引用 |

**实现类：`CryptoService`**

- 依赖 `IntegrityService` 注入
- 每个分块通过 `Flutter.compute()` 在独立 Isolate 中加密/解密
- 分块格式：第一块为 `[2B MetadataLength(uint16 LE)] + [MetadataBytes] + [Payload]`，后续块为纯 Payload
- Isolate 顶层函数：`_encryptChunkInIsolate`、`_decryptChunkInIsolate`、`_deriveKeyFromPassphraseIsolate`

##### crypto_constants.dart — 加密常量

[crypto_constants.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_constants.dart)

| 常量 | 值 | 说明 |
|------|-----|------|
| `ENCRYPTION_ALGORITHM_AES_256_GCM` | `'AES-256-GCM'` | 加密算法标识 |
| `KEY_LENGTH_BYTES` | 32 | 密钥长度（256位） |
| `NATIVE_IV_LENGTH_BYTES` | 12 | NIST 推荐 GCM IV 长度 |
| `CHUNK_IV_LENGTH_BYTES` | 16 | 分块 IV 长度 |
| `GCM_TAG_LENGTH_BYTES` | 16 | GCM 认证标签长度 |
| `SALT_LENGTH_BYTES` | 16 | PBKDF2 盐值长度 |
| `KDF_ITERATIONS` | 600000 | PBKDF2 迭代次数（OWASP 2023 推荐） |
| `DEFAULT_CHUNK_SIZE` | 1048576 (1MB) | 默认分块大小 |
| `STRAW_MAGIC_BYTES` | `"STRAWHUT"` | 二进制文件 Magic Bytes |
| `BINARY_FORMAT_MAJOR` | 2 | 二进制格式主版本 |
| `BINARY_FORMAT_MINOR` | 1 | 二进制格式次版本（v2.1 增强容器认证） |
| `BINARY_FORMAT_MINOR_V20` | 0 | v2.0 旧版次版本号（兼容读取） |
| `BINARY_FORMAT_MINOR_V21` | 1 | v2.1 新版次版本号（AAD + HMAC） |
| `HASH_ALGORITHM_HMAC_SHA256` | `'HMAC-SHA256'` | v2.1 HMAC-SHA256 算法标识 |
| `MAX_HEADER_SIZE_BYTES` | 1048576 (1MiB) | JSON Header 最大字节数（DoS 防护） |
| `MAX_CHUNK_CIPHERTEXT_BYTES` | 2097152 (2MiB) | 单块密文最大字节数（DoS 防护） |
| `MAX_TOTAL_CHUNKS_LIMIT` | 1048576 | 最大分块数上限（DoS 防护） |
| `PASSPHRASE_MIN_LENGTH` | 8 | 口令最小长度 |
| `MAX_TAGS_COUNT` | 10 | 标签最大数量 |
| `MAX_TAG_LENGTH` | 20 | 标签最大长度 |
| `MAX_DESCRIPTION_LENGTH` | 200 | 描述最大长度 |

##### fallback_crypto_service.dart — 带回退的加密服务

[fallback_crypto_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/native/fallback_crypto_service.dart)

- 优先使用原生平台加密 API（Android KeyStore / Windows BCrypt）
- 原生 API 不可用时自动回退到纯 Dart 实现 (`CryptoService`)
- 可取消操作时，PBKDF2 自动切换到 Dart Isolate 实现以支持 UI 响应

##### 加密数据模型

| 模型 | 文件 | 说明 |
|------|------|------|
| `ChunkInfo` | [chunk_info.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/chunk_info.dart) | 分块信息：IV + 加密数据 |
| `PayloadMetadata` | [payload_metadata.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/payload_metadata.dart) | 载荷元数据：sourceType + originalExtension + originalFileName |
| `SourceType` | [source_type.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/source_type.dart) | 内容来源枚举：richText / rawFile |
| `EncryptResult` | [encrypt_result.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/encrypt_result.dart) | 加密结果：chunks + chunkSize + totalChunks |
| `DecryptResult` | [encrypt_result.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/encrypt_result.dart) | 解密结果：payloadMetadata + payloadBytes + decryptedFilePath |
| `DecryptStreamResult` | [encrypt_result.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/encrypt_result.dart) | 流式解密结果：payloadMetadata + targetPath |
| `GeneratedKey` | [generated_key.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/generated_key.dart) | 生成的密钥：bytes + base64 |
| `ContentTypeClassifier` | [content_type_classifier.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/crypto_models/content_type_classifier.dart) | 内容类型分类器 |

#### 3.2.2 文件 I/O 服务 (file_io/)

##### file_io_service.dart — 文件 I/O 服务

[file_io_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/file_io/file_io_service.dart)

**核心接口：`IFileIOService`**

| 方法 | 说明 |
|------|------|
| `readStrawFile()` | 读取 .straw 文件（全量加载） |
| `readStrawFileHeader()` | 流式读取 .straw 文件头部（不加载分块数据） |
| `readStrawFileFromBytes()` | 从字节数据读取 .straw 文件 |
| `writeStrawFile()` | 写入 .straw 文件（支持原子写入） |
| `buildBinaryFileBytes()` | 构建二进制文件字节（不写入磁盘） |
| `readStrawPng()` | 读取 PNG 中嵌入的 .straw 数据 |
| `readStrawPngFromBytes()` | 从字节数据读取 PNG 中嵌入的 .straw 数据 |
| `readKeyFile()` | 读取 .key 密钥文件 |
| `readKeyFileFromBytes()` | 从字节数据读取 .key 文件 |
| `writeKeyFile()` | 写入 .key 密钥文件 |

**二进制 .straw v2.0/v2.1 解析流程：**

1. 验证 Magic Bytes `"STRAWHUT"`（8字节）
2. 读取版本号：Major(2B uint16 LE) + Minor(2B uint16 LE)
3. 读取 Header Size (4B uint32 LE)，校验 `≤ MAX_HEADER_SIZE_BYTES`（DoS 防护）
4. 读取 JSON Header（UTF-8 编码）
5. 调用 `FormatValidator.validateStrawFormat()` 验证格式
6. 解析分块数据：每个分块 = IV(16B) + DataSize(4B uint32 LE) + EncryptedData
   - 校验 `DataSize ≤ MAX_CHUNK_CIPHERTEXT_BYTES`
   - 校验 `totalChunks ≤ MAX_TOTAL_CHUNKS_LIMIT`
7. 根据 Minor 版本号选择解密路径：
   - minor=0（v2.0）：GCM 无 AAD，SHA-256 完整性校验
   - minor=1（v2.1）：GCM 绑定 AAD，HMAC-SHA256 完整性校验

##### file_selection_service.dart — 文件选择服务

跨平台文件选择服务，封装 `file_picker` 包，提供：
- 选择 .straw / .png 文件
- 选择 .key 密钥文件
- 选择任意文件（文件加密模式）
- 保存文件到用户指定位置（桌面端弹出系统保存对话框）

#### 3.2.3 完整性校验 (integrity/)

##### integrity_service.dart — 完整性校验服务

[integrity_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/integrity/integrity_service.dart)

**核心接口：`IIntegrityService`**

| 方法 | 说明 |
|------|------|
| `computeHash()` | 对 JSON 字符串计算 SHA-256 哈希 |
| `computeHashFromBytes()` | 对字节数据计算 SHA-256 哈希 |
| `computeHashFromStrawFile()` | 从 .straw 文件流式计算 SHA-256（逐块更新哈希，内存友好） |
| `computeHashFromChunks()` | 从内存中的分块数据计算 SHA-256 |
| `computeHmacFromBytes()` | v2.1：对字节数据计算 HMAC-SHA256（需传入 HMAC 密钥） |
| `computeHmacFromStrawFile()` | v2.1：从 .straw 文件流式计算 HMAC-SHA256 |
| `verifyIntegrity()` | 验证完整性：重新计算哈希并比对 |

哈希格式：
- v2.0：`"sha256:{64位十六进制字符}"`（无密钥 SHA-256）
- v2.1：`"hmac-sha256:{64位十六进制字符}"`（HMAC-SHA256，防止攻击者重算哈希绕过校验）

#### 3.2.4 暗号保险库 (passphrase_vault/)

##### passphrase_vault_service.dart — 暗号保险库服务

[passphrase_vault_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/passphrase_vault/passphrase_vault_service.dart)

**核心接口：`IPassphraseVaultService`**

| 方法 | 说明 |
|------|------|
| `getAllEntries()` | 获取所有暗号条目（按创建时间降序） |
| `savePassphrase()` | 保存暗号（强度检查 + 去重 + 容量检查） |
| `deletePassphrase()` | 删除指定暗号 |
| `clearAll()` | 清空保险库 |
| `containsPassphrase()` | 检查暗号是否已存在 |
| `getEntryCount()` | 获取条目数量 |
| `markUsed()` | 标记使用（更新概率） |

**存储：** 使用 `flutter_secure_storage` 加密存储 JSON 结构，基于 Completer 的互斥锁防止并发问题。

#### 3.2.5 迁移服务 (migration/)

##### migration_service.dart — 迁移服务

[migration_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/migration/migration_service.dart)

将旧版 JSON 格式的 .straw 文件迁移到新版 v2.1 二进制容器格式。

| 方法 | 说明 |
|------|------|
| `isOldFormat()` | 检测字节数据是否为旧版 JSON 格式 |
| `isOldFormatFile()` | 检测文件是否为旧版 JSON 格式 |
| `migrateFromDecryptedContent()` | 将已解密的旧版内容用新格式重新加密保存 |

#### 3.2.6 草稿管理 (draft/)

##### draft_manager.dart — 内存草稿管理器

[draft_manager.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/draft/draft_manager.dart)

纯内存存储，不写入磁盘。应用关闭后自动清空。

| 方法 | 说明 |
|------|------|
| `saveToDraft()` | 保存 Delta JSON 到内存 |
| `loadFromDraft()` | 读取草稿，无草稿返回 null |
| `clearDraft()` | 清空草稿 |
| `hasDraft()` | 检查是否存在非空草稿 |

#### 3.2.7 格式验证 (validation/)

##### format_validator.dart — 格式验证器

[format_validator.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/validation/format_validator.dart)

验证 .straw 和 .key 文件的 JSON 结构是否符合规范。

**验证项：**
- 顶层必填字段（format_version, meta, content, integrity）
- 版本号主版本兼容性（v2.x）
- 加密算法必须为 `AES-256-GCM`
- 哈希算法必须为 `SHA-256`
- 哈希格式：`sha256:{64位十六进制}`
- 密钥长度：256 位
- 标签数量/长度限制
- 描述长度限制
- 二进制 Magic Bytes 校验

#### 3.2.8 平台适配 (platform/)

| 文件 | 说明 |
|------|------|
| [android_file_saver.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/platform/android_file_saver.dart) | Android 文件保存：多媒体存入相册，其他文件存入下载目录 |
| [intent_handler.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/platform/intent_handler.dart) | Android Intent 处理：接收外部应用分享的文件 |

#### 3.2.9 工具类 (utils/)

| 文件 | 说明 |
|------|------|
| [memory_utils.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/memory_utils.dart) | 敏感数据内存清理：逐字节置零 (`wipeBytes`) |
| [base64_utils.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/base64_utils.dart) | Base64 编解码工具 |
| [cancellation_token.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/cancellation_token.dart) | 可取消操作令牌：支持解密过程的取消 |
| [cover_image_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/cover_image_service.dart) | PNG 封面生成与 .straw 数据嵌入/提取 |
| [temp_file_manager.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/temp_file_manager.dart) | 临时文件管理：创建（CSPRNG 随机文件名）、清理、自动注册 |
| [date_utils.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/date_utils.dart) | 日期格式化工具 |
| [image_service.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/utils/image_service.dart) | 图片处理服务 |

#### 3.2.10 错误处理 (errors/)

| 异常类 | 文件 | 说明 |
|--------|------|------|
| `StrawHutException` | [strawhut_exception.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/errors/strawhut_exception.dart) | 基础异常类，含 code 字段 |
| `CryptoException` | [crypto_exception.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/errors/crypto_exception.dart) | 加密相关异常 |
| `FileException` | [file_exception.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/errors/file_exception.dart) | 文件 I/O 异常 |
| `FormatException` | [format_exception.dart](file:///c:/GitHub Repositories/StrawHut/lib/core/errors/format_exception.dart) | 格式验证异常 |

---

### 3.3 数据模型层 (data/)

#### 3.3.1 数据模型 (models/)

| 模型 | 文件 | 说明 |
|------|------|------|
| `StrawFile` | [straw_file.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/straw_file.dart) | .straw 文件主模型：formatVersion + meta + content + integrity |
| `ParsedStrawFile` | [parsed_straw_file.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/parsed_straw_file.dart) | 解析后的文件：strawFile + chunks |
| `CardMeta` | [card_meta.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/card_meta.dart) | 卡片元数据：publisherAlias, publishDate, title, tags, description, isAnonymous |
| `StrawContent` | [straw_content.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/straw_content.dart) | 加密内容描述：encryptionAlgorithm, chunkSize, totalChunks, originalPayloadSize, salt, kdf |
| `KeyFile` | [key_file.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/key_file.dart) | 密钥文件模型：formatVersion + keyMetadata + keyData + integrity |
| `KeyMetadata` | [key_file.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/key_file.dart) | 密钥元信息：keyId, createdAt, keyAlgorithm, keyLengthBits |
| `KeyData` | [key_file.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/key_file.dart) | 密钥数据：keyBase64, encoding |
| `FormatVersion` | [format_version.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/format_version.dart) | 语义化版本号 |
| `IntegrityInfo` | [integrity_info.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/models/integrity_info.dart) | 完整性信息：hash + hashAlgorithm |

所有模型均为 `@immutable`，实现 `==` / `hashCode` / `fromJson` / `toJson`。

#### 3.3.2 数据仓库 (repositories/)

##### file_repository.dart — 文件仓库

[file_repository.dart](file:///c:/GitHub Repositories/StrawHut/lib/data/repositories/file_repository.dart)

采用 Repository 模式封装文件系统操作，提供语义化的 `load`/`save` 方法：

| 方法 | 说明 |
|------|------|
| `loadStrawFile()` | 加载 .straw 文件 |
| `loadStrawPng()` | 加载 PNG 中嵌入的 .straw 数据 |
| `saveStrawFile()` | 保存 .straw 文件（支持原子写入） |
| `loadKeyFile()` | 加载 .key 密钥文件 |
| `saveKeyFile()` | 保存 .key 密钥文件 |

---

### 3.4 表现层 (presentation/)

#### 3.4.1 页面 (screens/)

##### HomeScreen — 首页

[home_screen.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/screens/home/home_screen.dart)

- 应用入口页面，展示 Logo 和欢迎文字
- "新建知识卡片" → 导航到 EditorScreen
- "打开知识卡片" → 文件选择器 → 导航到 ReaderScreen
- 桌面端拖拽区域（DropZone）
- Android 双击返回键退出
- 暗号保险库入口按钮
- 帮助教程按钮
- 版本号显示

##### EditorScreen — 编辑器

[editor_screen.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/screens/editor/editor_screen.dart)

- 基于 flutter_quill 的富文本编辑器
- 编辑/预览模式切换
- 防抖草稿自动保存
- 发布按钮 → 弹出 PublishDialog
- 离开确认对话框（未保存内容提示）
- 应用后台恢复时草稿恢复提示

##### ReaderScreen — 阅读器

[reader_screen.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/screens/reader/reader_screen.dart)

**状态机：** `loading` → `metaOnly` → `decrypted`

解密后根据内容类型选择不同查看器：
- `richText` → QuillViewer（富文本渲染）
- `text` → TextViewer（纯文本）
- `markdown` → TextViewer（Markdown 渲染）
- `image/audio/video/pdf/other` → FileSavePrompt（保存到本地）

#### 3.4.2 对话框 (dialogs/)

| 对话框 | 说明 |
|--------|------|
| PublishDialog | 发布对话框：选择加密格式(.straw/.png)、密钥模式(随机密钥/暗号)、元数据填写、匿名模式（等宽附加框 + 背景色突出激活态，开启时清空代号并显示"匿名·无需输入"禁用标识）、标签输入兼容中英文逗号并自动去空格、文件选择区带边框。v1.2.2 起：输入框全部改为扁平样式（surfaceAlt 微差色背景），仅按钮保留浮空（convex）样式；PNG 格式发布前增加原图发送强确认弹框（barrierDismissible:false，必须用户主动确认）；各提示文案按重要程度着色（高=warning/error，中=inkSecondary，低=textHint），暗号安全提示、弱暗号警告、10MB 内容过大提示统一提升为 warning 色 |
| DecryptDialog | 解密对话框：支持密钥文件上传、暗号输入、保险库选择解密、进度显示、取消操作。v1.2.2 起：暗号/密钥输入框全部改为扁平样式（surfaceAlt 背景 + 透明边框 + focus 态 inkSecondary 边框），仅按钮保留浮空样式 |
| PassphraseVaultDialog | 暗号保险库管理：添加/删除暗号、查看列表 |
| MigrationDialog | 旧版格式迁移提示 |

#### 3.4.3 状态管理 (providers/)

| Provider | 文件 | 类型 | 说明 |
|----------|------|------|------|
| `cryptoServiceProvider` | [crypto_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/crypto_provider.dart) | Provider | 加密服务全局单例 |
| `integrityServiceProvider` | [crypto_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/crypto_provider.dart) | Provider | 完整性校验服务 |
| `fileIOServiceProvider` | [crypto_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/crypto_provider.dart) | Provider | 文件 I/O 服务 |
| `fileSelectionServiceProvider` | [crypto_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/crypto_provider.dart) | Provider | 文件选择服务 |
| `draftManagerProvider` | [crypto_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/crypto_provider.dart) | Provider | 草稿管理器 |
| `currentCardProvider` | [card_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/card_provider.dart) | Notifier (keepAlive: false) | 当前加载的知识卡片 |
| `pendingFileBytesProvider` | [card_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/card_provider.dart) | StateProvider | 待处理的文件字节 |
| `editorContentProvider` | [editor_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/editor_provider.dart) | Notifier (keepAlive: true) | 编辑器内容 + 草稿同步 |
| `appThemeModeProvider` | [theme_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/theme_provider.dart) | Notifier | 主题模式 (system/light/dark) |
| `appLocaleProvider` | [locale_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/locale_provider.dart) | Notifier | 语言设置 |
| `passphraseVaultProvider` | [passphrase_vault_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/passphrase_vault_provider.dart) | Notifier | 暗号保险库状态 |
| `pickedFileProvider` | [picked_file_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/picked_file_provider.dart) | Notifier | 已选择的文件 |
| `migrationCheckProvider` | [migration_provider.dart](file:///c:/GitHub Repositories/StrawHut/lib/presentation/providers/migration_provider.dart) | Provider | 旧版格式检测（可注入） |

---

### 3.5 国际化 (l10n/)

支持中文（zh）和英文（en）两种语言，使用 Flutter 标准的 ARB 文件格式。

- `app_en.arb` / `app_zh.arb` →
- `app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_zh.dart`

---

### 3.6 P2P 模块 (p2p/)

预留模块，当前仅包含接口定义和桩实现，尚未实现实际功能。

---

## 4. 关键数据流

### 4.1 加密发布流程

```
用户编辑内容 (EditorScreen)
  │
  ├── 点击"发布" → PublishDialog
  │
  ├── 选择加密模式
  │   ├── 随机密钥: CryptoService.generateKey()
  │   └── 暗号模式: CryptoService.deriveKeyFromPassphrase()
  │
  ├── 加密内容（v2.1 默认启用 AAD 绑定）
  │   ├── 小文件: CryptoService.encrypt(useV21Security: true)
  │   └── 大文件: CryptoService.encryptStream(useV21Security: true)
  │
  ├── 构建 StrawFile → IntegrityService 计算哈希
  │   └── v2.1: deriveHmacKey() → computeHmacFromBytes()
  │
  ├── 输出格式
  │   ├── .straw: FileIOService.writeStrawFile()
  │   └── .png: CoverImageService + 嵌入 .straw 数据
  │
  └── 清理敏感数据
```

### 4.2 解密阅读流程

```
用户选择文件 (HomeScreen → ReaderScreen)
  │
  ├── 文件加载
  │   ├── .straw: FileIOService.readStrawFile() / readStrawFileHeader()
  │   └── .png: FileIOService.readStrawPng()
  │
  ├── 展示元数据预览 (MetaPreview)
  │
  ├── 弹出解密对话框 (DecryptDialog)
  │   ├── 密钥文件: 上传 .key 文件
  │   ├── 暗号输入: 手动输入暗号
  │   └── 保险库选择: 从保险库中选择暗号
  │
  ├── 解密
  │   ├── 小文件: CryptoService.decrypt()（根据版本选择 useV21Security）
  │   └── 大文件: CryptoService.decryptStream()（根据版本选择 useV21Security）
  │
  ├── 完整性校验
  │   ├── v2.0: IntegrityService.computeHashFromStrawFile()
  │   └── v2.1: IntegrityService.computeHmacFromStrawFile() + deriveHmacKey()
  │
  └── 内容展示
      ├── richText → QuillViewer
      ├── text / markdown → TextViewer
      └── image/audio/video/pdf → FileSavePrompt
```

---

## 5. 依赖关系

### 5.1 模块依赖图

```
presentation/providers  ──→  core/services  ──→  data/models
        │                        │
        │                        ├── crypto (encrypt, pointycastle, crypto)
        │                        ├── integrity (crypto)
        │                        ├── file_io (path)
        │                        ├── passphrase_vault (flutter_secure_storage)
        │                        └── platform (receive_sharing_intent)
        │
        └── data/repositories ──→ core/file_io
```

### 5.2 外部依赖

| 包名 | 用途 |
|------|------|
| `flutter_quill` | 富文本编辑器 |
| `flutter_riverpod` + `riverpod_annotation` | 状态管理 |
| `go_router` | 声明式路由 |
| `encrypt` + `pointycastle` | AES-256-GCM 加密 |
| `crypto` | SHA-256 哈希 |
| `file_picker` | 跨平台文件选择 |
| `flutter_secure_storage` | 安全本地存储 |
| `path_provider` | 平台路径获取 |
| `desktop_drop` | 桌面端拖拽 |
| `receive_sharing_intent` | Android Intent 接收 |
| `video_player` + `audioplayers` | 多媒体播放 |
| `flutter_markdown` | Markdown 渲染 |
| `syncfusion_flutter_pdfviewer` | PDF 查看 |
| `json_annotation` + `json_serializable` | JSON 序列化 |

---

## 6. 项目运行方式

### 6.1 环境要求

| 环境 | 版本要求 |
|------|----------|
| Flutter SDK | >= 3.4.0 |
| Dart SDK | >= 3.4.0 |
| Windows | 10+ (19041+) |
| Android | 5.0+ (API 23+) |

### 6.2 安装与运行

```bash
# 克隆仓库
git clone <repository-url>
cd StrawHut

# 安装依赖
flutter pub get

# 代码生成（Riverpod + JSON 序列化）
dart run build_runner build --delete-conflicting-outputs

# 运行桌面端 (Windows)
flutter run -d windows

# 运行 Android 端
flutter run -d android

# 运行测试
flutter test

# 构建发布版本
flutter build windows --release
flutter build apk --release
```

### 6.3 代码生成说明

项目使用以下代码生成器：

- `riverpod_generator`：生成 `*.g.dart` 文件（Provider 代码）
- `json_serializable`：生成 JSON 序列化代码

修改 Provider 或模型后，需重新运行 `dart run build_runner build`。

### 6.4 国际化配置

ARB 文件位于 `lib/l10n/arb/`，修改后需运行：

```bash
flutter gen-l10n
```

---

## 7. 文件格式规范

### 7.1 .straw v2.1 二进制容器格式

```
Offset       Size       Content
────────────────────────────────────────────
0x00000000   8 bytes    Magic Bytes "STRAWHUT" (ASCII)
0x00000008   2 bytes    Format Version Major (uint16 LE) = 2
0x0000000A   2 bytes    Format Version Minor (uint16 LE) = 1 (v2.1)
0x0000000C   4 bytes    Header Size (uint32 LE), JSON Header 字节数
0x00000010   variable   JSON Header (UTF-8)
0x00000010+H variable   Encrypted Chunks
```

**版本演进：**
- v2.0 (minor=0)：GCM 无 AAD，外层无密钥 SHA-256
- v2.1 (minor=1)：GCM 绑定 AAD（chunk 序号+总数），外层 HMAC-SHA256

**兼容性：** 读取时同时支持 minor=0 和 minor=1，写入时使用 v2.1。

### 7.2 分块格式

```
Offset    Size       Content
────────────────────────────────────
0x00      16 bytes   Chunk IV (AES-256-GCM 初始化向量)
0x10      4 bytes    Chunk Data Size (uint32 LE), 加密数据字节数
0x14      variable   Encrypted Data (ciphertext + GCM Tag)
```

### 7.3 JSON Header 结构

```json
{
  "format_version": "2.1.0",
  "meta": {
    "publisher_alias": "Anonymous",
    "publish_date": "2026-05-01T12:00:00Z",
    "title": "知识卡片标题",
    "tags": ["标签1", "标签2"],
    "description": "卡片描述",
    "is_anonymous": true,
    "custom_annotations": {}
  },
  "content": {
    "encryption_algorithm": "AES-256-GCM",
    "chunk_size": 1048576,
    "total_chunks": 1,
    "original_payload_size": 1234,
    "salt": "base64_encoded_salt",
    "kdf_algorithm": "PBKDF2-HMAC-SHA256",
    "kdf_iterations": 600000
  },
  "integrity": {
    "hash": "hmac-sha256:abcdef1234567890...",
    "hash_algorithm": "HMAC-SHA256"
  }
}
```

**v2.0 vs v2.1 差异：**
- `format_version`：`2.0.0` → `2.1.0`
- `kdf_iterations`：旧文件保留原值（100000），新文件默认 600000
- `integrity.hash`：`sha256:` 前缀 → `hmac-sha256:` 前缀
- `integrity.hash_algorithm`：`SHA-256` → `HMAC-SHA256`

### 7.4 第一分块明文格式

```
Offset       Size       Content
────────────────────────────────────
0x00         2 bytes    Metadata Length (uint16 LE)
0x02         variable   PayloadMetadata JSON (UTF-8 bytes)
0x02+M       variable   First chunk of payload data
```

---

## 8. 加密技术规范

### 8.1 加密算法

| 参数 | 值 |
|------|-----|
| 对称加密算法 | AES-256-GCM |
| 密钥长度 | 256 位 (32 字节) |
| IV 长度 | 12 字节 (NIST SP 800-38D 推荐) |
| 分块 IV 长度 | 16 字节 |
| GCM 认证标签 | 16 字节 |
| GCM AAD (v2.1) | `UTF8("STRAWHUT-V2.1-CHUNK") + u32LE(chunkIndex) + u32LE(totalChunks)` |
| 密钥派生 | PBKDF2-HMAC-SHA256, 600,000 次迭代（OWASP 2023 推荐） |
| 盐值长度 | 16 字节 |
| 随机数生成 | CSPRNG (Random.secure / Android SecureRandom / BCryptGenRandom) |
| 完整性哈希 (v2.0) | SHA-256（无密钥） |
| 完整性哈希 (v2.1) | HMAC-SHA256（密钥派生：`HMAC-SHA256(encKey, "STRAWHUT-V2.1-HMAC-KEY")`） |
| 临时文件名 | CSPRNG 生成 16 字节随机十六进制前缀，原子写入 |

### 8.2 原生加密架构

```
FallbackCryptoService (代理层)
  │
  ├── 优先: NativeCryptoService
  │   ├── Android: MethodChannelCryptoChannel (KeyStore AES)
  │   └── Windows: FfiCryptoChannel (BCrypt API)
  │
  └── 回退: CryptoService (纯 Dart 实现)
      └── encrypt + pointycastle 包
```

### 8.3 分块加密策略

- 默认分块大小：1MB (1,048,576 字节)
- 第一个分块含 PayloadMetadata 前缀（2字节长度 + 元数据）
- 每个分块独立生成随机 IV
- 每个分块通过 `Flutter.compute()` 在独立 Isolate 中加密/解密
- 大文件使用流式接口（`encryptStream`/`decryptStream`），避免将整个文件加载到内存

### 8.4 性能优化

#### 8.4.1 进度回调节流（throttle）

- **位置**：`decrypt_dialog.dart`、`publish_dialog.dart`（桌面端与移动端 State 类）
- **实现**：通过 `_lastProgressUpdateTime` 字段 + `_throttledSetProgress()` 方法
- **策略**：进度回调每 100ms 或进度到达 1.0（阶段边界）时才触发 `setState`，避免每个分块都触发 UI 重绘
- **取消响应**：节流不影响 `cancellationToken` 同步检查，取消仍能在 ~1 块内响应

#### 8.4.2 完整性校验循环让出策略

- **位置**：`integrity_service.dart`（4 处循环：`computeHashFromStrawFile`/`computeHashFromChunks`/`computeHmacFromStrawFile`/`computeHmacFromChunks`）
- **实现**：`await Future.delayed(Duration.zero)` 改为「每 16 块让出一次」（`if (i & 0xF == 0xF)`）
- **效果**：减少事件循环切换开销，同步 `cancellationToken` 检查保证取消仍可在 ~1 块内响应

#### 8.4.3 RandomAccessFile 合并读取

- **位置**：`native_crypto_service.dart` 的 `decryptStream()`
- **实现**：将每块的 3 次 `await raf.read(...)`（IV 16B + len 4B + encData 1MB）合并为 2 次（header 20B 一次 + encData 一次）
- **效果**：100 块文件减少 100 次 await 开销，对应减少事件循环切换

#### 8.4.4 死代码清理

- **位置**：`native_crypto_service.dart`
- **清理**：移除未使用的 `_IsolateParams`、`_encryptInIsolate`、`_decryptInIsolate`、`_ffiEncryptSync`、`_ffiDecryptSync` 及对应 `windows_crypto_ffi.dart` import
- **原因**：分块加解密路径走的是 `_nativeEncryptChunkInIsolate`/`_nativeDecryptChunkInIsolate`（pointycastle），单块 FFI 路径已废弃

#### 8.4.5 解密边读边算 IntegritySink

- **位置**：`integrity_service.dart`（新增 `IntegritySink` 抽象类 + `_HmacSha256IntegritySink` / `_Sha256IntegritySink` 实现）、`crypto_service.dart` / `native_crypto_service.dart` 的 `decryptStream()`、`fallback_crypto_service.dart`、`decrypt_dialog.dart`
- **实现**：
  - `IIntegrityService.createIntegritySink()` 工厂方法创建 sink，创建时立即用 `strawFileForHash`（hash='' 版本）更新头部
  - `decryptStream()` 新增 `integritySink` 可选参数，每读一个 chunk 的 IV + len + ciphertext 后立即 `updateChunkIv` / `updateChunkLength` / `updateChunkCipher`
  - 解密完成后 `integritySink.finalize()` 瞬间返回哈希，无需重新读取文件
- **效果**：流式解密时哈希计算与解密合并为单遍 IO，消除哈希阶段的完整文件重读，大文件解密耗时下降 30-50%
- **兼容性**：内存解密（useStream=false）仍走 `computeHmacFromChunks` / `computeHashFromChunks` 旧路径

#### 8.4.6 发布流式构造 buildBinaryFileBytesWithIntegrity

- **位置**：`file_io_service.dart`（新增 `buildBinaryFileBytesWithIntegrity` 方法）、`publish_dialog.dart`
- **实现**：
  - 一次调用同时完成：构造 hash='' 版本 bytes + 通过 IntegritySink 边构造边算哈希 + 用真实哈希重建 header
  - 第二次构造复用第一次的 chunks 部分（sublist view），避免重新遍历所有 chunks
- **效果**：发布路径消除一次外部 `buildBinaryFileBytes` 调用和一次完整 bytes 遍历（HMAC 计算与 bytes 构造合并）

#### 8.4.7 多核并行分块加解密 ParallelChunkProcessor

- **位置**：`parallel_chunk_processor.dart`（新增 `ParallelChunkProcessor` 类）、`native_crypto_service.dart`（`encrypt` / `decrypt` / `encryptStream` / `decryptStream` 四个方法）
- **实现**：
  - `ParallelChunkProcessor` 采用滑动窗口并发策略，维护 `concurrency` 个 in-flight `Flutter.compute` Future，每完成一个立即派发下一个
  - 并发度按 `Platform.numberOfProcessors` 自适应：≤2 核取 2，3-8 核取核数 -1，>8 核取 8
  - 结果按原始 chunkIndex 顺序填入预分配数组，保证分块顺序正确
  - `CancellationToken` 触发时停止派发新任务，等待在途任务完成后抛出 `OperationCancelledException`
  - `encryptStream` / `decryptStream` 采用分批预读策略：每批预读 `concurrency` 个分块到内存，并行处理后再读下一批，避免大文件 OOM
- **效果**：多分块文件加解密利用多核 CPU 并行处理，N 核机器理论加速接近 N-1 倍（留 1 核给 UI），大文件加解密耗时显著下降
- **内存控制**：在途任务数固定为 `concurrency`，每块 1MB → 最多 `concurrency` MB 内存增量

#### 8.4.8 加密过程取消支持

- **位置**：`crypto_service.dart`（`ICryptoService.encrypt` / `encryptStream` 接口 + `CryptoService` 实现）、`native_crypto_service.dart`（`NativeCryptoService` 实现）、`fallback_crypto_service.dart`（转发）、`publish_dialog.dart`（UI）
- **实现**：
  - `encrypt` / `encryptStream` 新增 `CancellationToken? cancellationToken` 参数，与解密接口对称
  - 在方法入口、第一块加密前后、循环中每块前检查 `cancellationToken?.throwIfCancelled()`
  - `NativeCryptoService` 将 `cancellationToken` 透传给 `ParallelChunkProcessor.encryptChunks`，与并行解密共用同一取消路径
  - `publish_dialog.dart` 桌面版 + 移动版均新增 `_cancellationToken` / `_isCancelling` 字段、`dispose()` 取消、`_handleCancel()` 方法
  - 加密开始前创建 `CancellationToken`，3 处 `encrypt` / `encryptStream` 调用传入
  - catch 单独处理 `OperationCancelledException`：静默恢复初始状态，不显示错误
  - 桌面版取消按钮：加载时变为"取消加密"并调用 `_handleCancel`
  - 移动版底部操作栏：加载时切换为「进度文本（Expanded）+ 取消按钮」并排布局，取消按钮紧邻进度，更直观
- **效果**：大文件加密过程中可随时取消，停止后续分块处理，与解密取消体验一致

### 8.5 安全性保证

- 零网络请求：所有加密操作在本地完成
- 零持久化存储：除暗号保险库外，不保存任何数据
- 内存安全：`MemoryUtils.wipeBytes()` 逐字节清零敏感数据
- 完整性校验：SHA-256 哈希防止文件篡改
- 格式验证：多层验证防止恶意文件注入
- 取消支持：加密、解密和完整性校验均可在任意时刻取消

---

## 9. 测试套件

项目采用 `flutter_test` + `mocktail` 进行单元测试和 Widget 测试，测试目录结构与源码目录一一对应。

### 测试框架

| 组件 | 用途 |
|------|------|
| `flutter_test` | Flutter 官方测试框架 |
| `mocktail` | Mock 对象生成（替代 mockito，无需代码生成） |
| `integration_test` | 集成测试（预留） |

### 测试分类与覆盖

#### 9.1 核心加密测试 (`test/core/crypto/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `crypto_service_test.dart` | 基础加密/解密：密钥生成、AES-256-GCM 加解密、PBKDF2 密钥派生 |
| `crypto_service_chunked_test.dart` | 分块加密/解密：多块数据加解密、分块边界处理 |
| `crypto_service_stream_test.dart` | 流式加密/解密：大文件流式处理、内存效率验证 |
| `crypto_v21_security_test.dart` | v2.1 容器认证：AAD 加解密往返、HMAC 密钥派生、HMAC-SHA256 完整性校验、版本不兼容验证、长度字段上限、流式 v2.1 往返 |
| `decrypt_stream_cancellation_test.dart` | 解密取消：取消令牌机制、中途取消后的资源释放 |
| `fallback_crypto_service_test.dart` | 回退加密服务：原生→Dart 回退逻辑 |
| `crypto_compatibility_test.dart` | 跨平台兼容性：原生加密与 Dart 加密互操作 |
| `passphrase_strength_service_test.dart` | 暗号强度评估：强度分级逻辑 |
| `crypto_models/*_test.dart` | 加密数据模型：序列化/反序列化、边界值验证 |
| `native/native_crypto_service_test.dart` | 原生加密服务：MethodChannel/FFI 通道测试 |

#### 9.2 文件 I/O 与完整性测试 (`test/core/file_io/`, `test/core/integrity/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `file_io_service_test.dart` | .straw 文件读写、.key 文件读写、PNG 嵌入提取、二进制格式解析 |
| `integrity_service_test.dart` | SHA-256 哈希计算、HMAC-SHA256 哈希计算、完整性校验 |
| `incremental_integrity_test.dart` | 流式/增量哈希计算 |

#### 9.3 暗号保险库测试 (`test/core/passphrase_vault/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `passphrase_vault_service_test.dart` | 增删查、去重、容量限制、智能排序、并发安全 |
| `passphrase_entry_test.dart` | 条目模型序列化 |
| `passphrase_vault_exception_test.dart` | 异常处理 |

#### 9.4 工具类测试 (`test/core/utils/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `memory_utils_test.dart` | 敏感数据内存清零 |
| `base64_utils_test.dart` | Base64 编解码 |
| `temp_file_manager_test.dart` | 临时文件创建/清理、安全随机文件名 |
| `date_utils_test.dart` | 日期格式化 |
| `file_size_warning_test.dart` | 大文件警告逻辑 |

#### 9.5 格式验证测试 (`test/core/validation/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `format_validator_test.dart` | .straw/.key 格式验证、Magic Bytes 校验、版本兼容性 |

#### 9.6 数据模型测试 (`test/data/models/`)

| 测试文件 | 覆盖范围 |
|----------|----------|
| `straw_file_test.dart` | StrawFile 模型序列化/反序列化 |
| `parsed_straw_file_test.dart` | ParsedStrawFile 解析验证 |
| `straw_content_test.dart` | StrawContent 加密内容描述 |
| `key_file_test.dart` | KeyFile 密钥文件模型 |
| `format_version_test.dart` | 语义化版本号比较 |

#### 9.7 表现层测试 (`test/presentation/`)

| 测试类别 | 测试文件 | 说明 |
|----------|----------|------|
| 首页 | `home_screen_test.dart`, `action_buttons_test.dart`, `drop_zone_test.dart` | 首页渲染、按钮交互、拖拽功能 |
| 编辑器 | `editor_screen_test.dart`, `quill_editor_test.dart`, `quill_toolbar_test.dart`, `preview_panel_test.dart` | 编辑器渲染、工具栏、预览面板 |
| 阅读器 | `reader_screen_test.dart`, `meta_preview_test.dart`, `quill_viewer_test.dart` | 阅读器状态机、元数据预览、富文本查看器 |
| 发布对话框 | `publish_dialog_test.dart`, `publish_dialog_save_test.dart`, `meta_form_test.dart`, `key_display_test.dart`, `export_options_test.dart`, `passphrase_input_test.dart`, `publish_security_notices_test.dart`, `file_size_warning_dialog_test.dart` | 发布流程全链路测试 |
| 解密对话框 | `decrypt_dialog_test.dart`, `key_file_upload_test.dart`, `key_input_test.dart`, `passphrase_decrypt_input_test.dart` | 解密流程全链路测试 |
| Provider | `card_provider_test.dart`, `editor_provider_test.dart`, `crypto_provider_test.dart`, `theme_provider_test.dart`, `locale_provider_test.dart`, `passphrase_vault_provider_test.dart` | 状态管理单元测试 |

#### 9.8 运行测试

```bash
# 运行所有单元测试
flutter test

# 运行指定测试文件
flutter test test/core/crypto/crypto_service_test.dart

# 运行加密相关全部测试
flutter test test/core/crypto/

# 生成覆盖率报告
flutter test --coverage
```

---

## 10. 原生平台代码

### 10.1 Android 原生代码

#### CryptoPlugin.kt — Android 原生加密插件

[文件路径](file:///c:/GitHub Repositories/StrawHut/android/app/src/main/kotlin/com/strawhut/strawhut/CryptoPlugin.kt)

通过 `MethodChannel`（通道名 `com.strawhut.crypto`）向 Flutter 层暴露 Android 原生加密能力：

| 方法 | 说明 |
|------|------|
| `generateKey` | 使用 `SecureRandom` 生成 32 字节 AES-256 密钥 |
| `encrypt` | AES-256-GCM 加密，使用 Android `Cipher` API，输出 `ciphertext + GCM Tag(16B)` |
| `decrypt` | AES-256-GCM 解密，支持 12/16 字节 IV 向后兼容，`AEADBadTagException` 单独处理 |
| `deriveKey` | PBKDF2-HMAC-SHA256 密钥派生，优先使用 `AndroidOpenSSL` Provider，不可用时回退默认 Provider |

**安全设计：**
- 使用 `javax.crypto` 标准库，基于 Android KeyStore 的硬件级 CSPRNG
- 密钥永不被持久化存储，仅在内存中使用
- 解密失败时返回明确的 `DECRYPTION_FAILED` 错误码

#### MainActivity.kt — Android 主 Activity 与文件保存

[文件路径](file:///c:/GitHub Repositories/StrawHut/android/app/src/main/kotlin/com/strawhut/strawhut/MainActivity.kt)

通过 `MethodChannel`（通道名 `com.strawhut.strawhut/file_saver`）提供文件保存能力：

| 方法 | 说明 |
|------|------|
| `saveToDownloads` | 保存文件到下载目录，使用 `application/octet-stream` MIME 类型 |
| `saveToPictures` | 保存 PNG 图片到相册目录 |
| `saveMediaToAlbum` | 根据 MIME 类型自动选择保存路径（图片→Pictures, 视频→Movies, 音频→Music） |

**平台适配：**
- Android 10+ (API 29+)：使用 `MediaStore` API 写入，通过 `IS_PENDING` 标志保证原子写入
- Android 9 及以下：直接使用 `FileOutputStream` 写入公共目录

**插件注册：** 在 `configureFlutterEngine()` 中通过 `flutterEngine.plugins.add(CryptoPlugin())` 注册原生加密插件。

### 10.2 Windows 原生代码

#### main.cpp — Windows 应用入口

[文件路径](file:///c:/GitHub Repositories/StrawHut/windows/runner/main.cpp)

- 创建 Win32 窗口（400x800 竖屏比例），居中显示
- 初始化 COM 运行时（`CoInitializeEx`）
- 标准 Windows 消息泵（`GetMessage` → `TranslateMessage` → `DispatchMessage`）
- 控制台附加：调试模式下自动附加到父进程控制台或创建新控制台

#### flutter_window.cpp — Flutter 窗口集成

[文件路径](file:///c:/GitHub Repositories/StrawHut/windows/runner/flutter_window.cpp)

- 继承 `Win32Window`，创建 `FlutterViewController` 管理 Flutter 引擎
- 注册 Flutter 插件（`RegisterPlugins`）
- 首帧渲染完成后显示窗口（`SetNextFrameCallback`）
- 处理 `WM_FONTCHANGE` 消息以支持系统字体变更时重新加载

#### win32_window.cpp — Win32 窗口管理

[文件路径](file:///c:/GitHub Repositories/StrawHut/windows/runner/win32_window.cpp)

- 窗口类注册（`WindowClassRegistrar` 单例模式）
- 高 DPI 支持：`EnableNonClientDpiScaling` + `WM_DPICHANGED` 处理
- 沉浸式暗色模式：读取注册表 `AppsUseLightTheme`，通过 `DwmSetWindowAttribute` 设置窗口标题栏主题
- 窗口生命周期管理：`WM_DESTROY` → `PostQuitMessage`，引用计数自动注销窗口类

#### utils.cpp — Windows 工具函数

[文件路径](file:///c:/GitHub Repositories/StrawHut/windows/runner/utils.cpp)

- `CreateAndAttachConsole()`：调试控制台创建
- `GetCommandLineArguments()`：UTF-16 → UTF-8 命令行参数转换
- `Utf8FromUtf16()`：宽字符到 UTF-8 字符串转换

#### windows_crypto_ffi.dart — BCrypt FFI 绑定

[文件路径](file:///c:/GitHub Repositories/StrawHut/lib/core/crypto/native/windows_crypto_ffi.dart)

通过 `dart:ffi` 直接调用 Windows CNG (Cryptography Next Generation) API：

| 方法 | 对应 Windows API | 说明 |
|------|-----------------|------|
| `generateRandom()` | `BCryptGenRandom` | 基于 AES-CTR-DRBG (NIST SP 800-90A) 的 CSPRNG |
| `encryptAesGcm()` | `BCryptEncrypt` | AES-256-GCM 加密，输出 ciphertext + 16B GCM Tag |
| `decryptAesGcm()` | `BCryptDecrypt` | AES-256-GCM 解密，自动验证 GCM 标签 |
| `deriveKeyPBKDF2()` | `BCryptDeriveKeyPBKDF2` | PBKDF2-HMAC-SHA256 密钥派生（需 Win10 19041+） |

**关键设计决策：**
- 使用 `Arena` 自动管理 native 内存生命周期，避免内存泄漏
- 动态计算 `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` 结构体大小，兼容 x64/x86 平台
- 通过 `RtlGetVersion` 检测真实 Windows 版本（不受应用程序兼容性清单影响）
- 延迟加载 DLL：仅在首次访问时初始化，非 Windows 平台不触发加载
- 每次调用重新分配和释放 native 资源，不缓存任何指针

### 10.3 原生加密通道架构

```
Dart 层 (Flutter)
  │
  ├── Android: MethodChannelCryptoChannel
  │   └── MethodChannel("com.strawhut.crypto")
  │       └── CryptoPlugin.kt (Android KeyStore)
  │
  └── Windows: FfiCryptoChannel
      └── dart:ffi → bcrypt.dll
          └── WindowsCryptoFfi (BCrypt/CNG API)
```

---

## 11. 完整依赖清单

### 11.1 运行时依赖 (dependencies)

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter_quill` | ^11.5.0 | 富文本编辑器（Quill Delta 格式） |
| `flutter_quill_extensions` | ^11.0.0-dev.7 | 编辑器扩展（图片、视频嵌入） |
| `flutter_riverpod` | ^2.6.1 | 响应式状态管理框架 |
| `riverpod_annotation` | ^2.6.1 | Riverpod 代码生成注解 |
| `encrypt` | ^5.0.3 | AES 加密包装器 |
| `pointycastle` | ^3.9.1 | 纯 Dart 密码学库（AES-GCM、PBKDF2） |
| `crypto` | ^3.0.6 | SHA-256 哈希 |
| `ffi` | ^2.1.0 | Dart FFI 互操作（Windows BCrypt 绑定） |
| `file_picker` | ^11.0.3 | 跨平台文件选择对话框 |
| `image` | ^4.3.0 | 图片处理（PNG 读写、封面生成） |
| `path_provider` | ^2.1.5 | 平台路径获取 |
| `path` | ^1.9.0 | 跨平台路径操作 |
| `video_player` | ^2.8.0 | 视频播放 |
| `audioplayers` | ^6.7.1 | 音频播放 |
| `flutter_markdown` | ^0.7.0 | Markdown 渲染 |
| `syncfusion_flutter_pdfviewer` | ^33.2.13 | PDF 查看器 |
| `go_router` | ^14.6.2 | 声明式路由 |
| `desktop_drop` | ^0.5.0 | 桌面端文件拖拽 |
| `share_plus` | ^10.1.3 | 系统分享 |
| `receive_sharing_intent` | ^1.8.0 | Android 接收外部分享 |
| `permission_handler` | ^13.0.0 | 运行时权限管理 |
| `media_scanner` | ^2.1.0 | Android 媒体扫描 |
| `image_picker` | ^1.1.2 | 图片选择器 |
| `flutter_secure_storage` | ^9.2.4 | 安全本地存储（暗号保险库） |
| `package_info_plus` | ^8.3.0 | 应用信息获取 |
| `json_annotation` | ^4.9.0 | JSON 序列化注解 |
| `cupertino_icons` | ^1.0.8 | iOS 风格图标 |

### 11.2 开发依赖 (dev_dependencies)

| 包名 | 版本 | 用途 |
|------|------|------|
| `build_runner` | ^2.4.13 | 代码生成运行器 |
| `riverpod_generator` | ^2.6.3 | Riverpod Provider 代码生成 |
| `json_serializable` | ^6.9.0 | JSON 序列化代码生成 |
| `very_good_analysis` | ^7.0.0 | 严格代码分析规则 |
| `mocktail` | ^1.0.4 | Mock 测试框架 |

### 11.3 依赖关系图

```
strawhut (v1.3.0+7)
├── 加密 (Cryptography)
│   ├── encrypt ^5.0.3
│   ├── pointycastle ^3.9.1
│   ├── crypto ^3.0.6
│   └── ffi ^2.1.0 (Windows BCrypt)
├── 状态管理 (State Management)
│   ├── flutter_riverpod ^2.6.1
│   ├── riverpod_annotation ^2.6.1
│   ├── riverpod_generator ^2.6.3 (dev)
│   └── build_runner ^2.4.13 (dev)
├── 路由 (Routing)
│   └── go_router ^14.6.2
├── 编辑器 (Editor)
│   ├── flutter_quill ^11.5.0
│   └── flutter_quill_extensions ^11.0.0-dev.7
├── 文件操作 (File Operations)
│   ├── file_picker ^11.0.3
│   ├── path_provider ^2.1.5
│   ├── path ^1.9.0
│   └── image ^4.3.0
├── 多媒体 (Media)
│   ├── video_player ^2.8.0
│   ├── audioplayers ^5.0.0
│   ├── flutter_markdown ^0.7.0
│   └── syncfusion_flutter_pdfviewer ^33.2.13
├── 平台 (Platform)
│   ├── desktop_drop ^0.5.0
│   ├── share_plus ^10.1.3
│   ├── receive_sharing_intent ^1.8.0
│   ├── permission_handler ^11.3.1
│   ├── media_scanner ^2.1.0
│   └── image_picker ^1.1.2
├── 存储 (Storage)
│   └── flutter_secure_storage ^9.2.4
├── 工具 (Utilities)
│   ├── package_info_plus ^8.3.0
│   └── json_annotation ^4.9.0
├── 测试 (Testing)
│   ├── flutter_test (sdk)
│   ├── integration_test (sdk)
│   ├── mocktail ^1.0.4 (dev)
│   └── very_good_analysis ^7.0.0 (dev)
└── UI
    └── cupertino_icons ^1.0.8
```
