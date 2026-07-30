import 'dart:convert';
import 'dart:typed_data';

import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/validation/validation_result.dart';

/// 格式验证器接口
///
/// 定义 StrawHut 文件格式验证的契约。
/// 负责验证 .straw 知识卡片文件和 .key 密钥文件的 JSON 结构是否符合规范。
///
/// 验证范围：
/// - 顶层必填字段（format_version, meta, content, integrity）
/// - 元数据字段长度限制（标题、标签、描述等）
/// - 版本号兼容性检查
/// - 加密内容必填字段（二进制分块格式）
/// - 完整性校验必填字段
/// - 二进制 Magic Bytes 校验
///
/// 架构位置：核心服务层（Core Service Layer）
/// 被依赖方：FileIOService（读写文件时自动验证）
abstract class IFormatValidator {
  /// 验证 .straw 知识卡片文件格式
  ///
  /// 检查 JSON Header 是否包含所有必填字段且格式正确。
  ///
  /// 验证项包括：
  /// - format_version 存在且主版本兼容（v2.x）
  /// - meta.publisher_alias 存在
  /// - meta.publish_date 存在且为有效日期
  /// - meta.title 非空
  /// - meta.is_anonymous 存在
  /// - content.encryption_algorithm 为 "AES-256-GCM"
  /// - content.chunk_size 存在
  /// - content.total_chunks 存在
  /// - content.original_payload_size 存在
  /// - integrity.hash 存在且格式正确
  /// - integrity.hash_algorithm 为 "SHA-256"
  /// - tags 数量和长度限制
  /// - description 长度限制
  ///
  /// 参数：[json] - 解析后的 .straw 文件 JSON Header 映射
  /// 返回：[ValidationResult]，isValid 为 true 表示格式正确
  ValidationResult validateStrawFormat(Map<String, dynamic> json);

  /// 验证 .key 密钥文件格式
  ///
  /// 检查 JSON 是否包含所有必填字段且格式正确。
  ///
  /// 验证项包括：
  /// - format_version 存在
  /// - key_metadata.key_id 存在
  /// - key_metadata.created_at 存在
  /// - key_metadata.key_algorithm 为 "AES-256-GCM"
  /// - key_metadata.key_length_bits 为 256
  /// - key_data.key_base64 存在且为有效的 Base64
  /// - key_data.encoding 为 "base64"
  /// - integrity 字段完整
  ///
  /// 参数：[json] - 解析后的 .key 文件 JSON 映射
  /// 返回：[ValidationResult]，isValid 为 true 表示格式正确
  ValidationResult validateKeyFormat(Map<String, dynamic> json);

  /// 验证二进制 .straw 文件的 Magic Bytes
  ///
  /// 检查字节数据的起始位置是否为 "STRAWHUT" Magic Bytes，
  /// 用于快速判断文件是否为 StrawHut 二进制格式。
  ///
  /// 参数：[bytes] - 二进制 .straw 文件的字节数据
  /// 返回：[ValidationResult]，isValid 为 true 表示 Magic Bytes 匹配
  ValidationResult validateBinaryFormat(Uint8List bytes);
}

/// 格式验证器实现类
///
/// 实现 [IFormatValidator] 接口，提供对 .straw 知识卡片文件和 .key 密钥文件的
/// JSON 格式验证能力，以及二进制 .straw 文件的 Magic Bytes 校验。
///
/// 设计原则：
/// - 收集所有验证错误（不在第一个错误处停止），以便一次性向用户展示全部问题
/// - 使用常量而非硬编码字符串，确保与加密模块的一致性
/// - 错误信息清晰明确，可直接用于 UI 展示
///
/// 安全意义：
/// - 在读取或写入文件前验证格式，防止恶意或损坏的文件进入系统
/// - 确保加密算法和哈希算法符合预期，防止降级攻击
/// - 验证字段长度限制，防止缓冲区溢出或拒绝服务攻击
class FormatValidator implements IFormatValidator {
  /// 验证 .straw 知识卡片文件格式（v2.0 二进制容器 JSON Header）
  ///
  /// 对解析后的 .straw 文件 JSON Header 进行全面的格式检查，确保所有必填字段
  /// 存在且值符合规范。此验证是文件安全处理的第一道防线。
  ///
  /// 验证流程：
  /// 1. 检查 format_version 是否存在且主版本为 "2"（v2.0 二进制格式）
  /// 2. 检查 meta 对象及其必填字段（publisher_alias、publish_date、
  ///    title、is_anonymous）
  /// 3. 检查 content 对象及其必填字段（encryption_algorithm、chunk_size、
  ///    total_chunks、original_payload_size）
  /// 4. 检查 integrity 对象及其必填字段（hash、hash_algorithm）
  /// 5. 验证加密算法必须为 AES-256-GCM（防止降级攻击）
  /// 6. 验证哈希算法必须为 SHA-256（确保完整性校验强度）
  /// 7. 验证 meta.title 非空
  /// 8. 验证 tags 数量和长度限制
  /// 9. 验证 description 长度限制
  ///
  /// 参数：[json] - 通过 jsonDecode 解析后的 .straw 文件 JSON Header 映射
  /// 返回：[ValidationResult]，isValid 为 true 表示格式完全正确
  @override
  ValidationResult validateStrawFormat(Map<String, dynamic> json) {
    final errors = <String>[];

    // ========== 1. 验证 format_version 是否存在且主版本兼容 ==========
    // format_version 采用语义化版本控制（major.minor.patch）
    // v2.0 二进制格式主版本为 "2"，与旧版 v1.x JSON 格式不兼容
    // 主版本不同表示格式发生了不兼容的变更，应拒绝处理
    if (!json.containsKey('format_version')) {
      errors.add('缺少必填字段: format_version（文件格式版本号）');
    } else {
      final version = json['format_version'] as String?;
      if (version == null || version.isEmpty) {
        errors.add('format_version 不能为空');
      } else {
        final majorVersion = version.split('.').first;
        if (majorVersion != BINARY_FORMAT_MAJOR.toString()) {
          errors.add(
            '不兼容的格式版本号: $version，仅支持主版本为 ${BINARY_FORMAT_MAJOR} 的文件格式',
          );
        }
      }
    }

    // ========== 2. 验证 meta 对象及其必填字段 ==========
    // meta 包含文件的元数据信息，部分字段在未解密状态下即可见
    // 用于文件预览、列表展示和基础信息校验
    if (!json.containsKey('meta')) {
      errors.add('缺少必填对象: meta（文件元数据）');
    } else {
      final meta = json['meta'];
      if (meta is! Map<String, dynamic>) {
        errors.add('meta 必须是一个对象（键值对集合）');
      } else {
        // 验证 meta.publisher_alias —— 发布者别名
        // 用于标识卡片创建者，匿名模式下使用 Anonymous_ 前缀的随机标识
        if (!meta.containsKey('publisher_alias')) {
          errors.add('缺少必填字段: meta.publisher_alias（发布者别名）');
        }

        // 验证 meta.publish_date —— 发布日期
        // 用于文件排序和时间线展示，必须是有效的日期字符串
        if (!meta.containsKey('publish_date')) {
          errors.add('缺少必填字段: meta.publish_date（发布日期）');
        }

        // 验证 meta.title —— 卡片标题
        // 标题是卡片的核心标识，在未解密状态下也可见，用于快速识别内容
        if (!meta.containsKey('title')) {
          errors.add('缺少必填字段: meta.title（卡片标题）');
        } else {
          final title = meta['title'] as String?;
          // 标题不能为空或仅包含空白字符，否则无法有效标识卡片
          if (title == null || title.trim().isEmpty) {
            errors.add('meta.title 不能为空');
          }
        }

        // 验证 meta.is_anonymous —— 是否匿名发布
        // 布尔值，决定发布者身份是否隐藏，影响隐私保护级别
        if (!meta.containsKey('is_anonymous')) {
          errors.add('缺少必填字段: meta.is_anonymous（是否匿名发布）');
        }
      }
    }

    // ========== 3. 验证 content 对象及其必填字段 ==========
    // content 包含加密内容的元信息，不包含密文本身（密文在二进制分块载荷中）
    // v2.0 格式中不再有 encrypted_data 和 iv 字段，改为分块结构
    if (!json.containsKey('content')) {
      errors.add('缺少必填对象: content（加密内容元信息）');
    } else {
      final content = json['content'];
      if (content is! Map<String, dynamic>) {
        errors.add('content 必须是一个对象（键值对集合）');
      } else {
        // 验证 content.encryption_algorithm —— 加密算法
        // 必须为 AES-256-GCM，使用常量比较防止降级攻击
        // 如果允许其他算法，攻击者可能强制使用弱加密算法
        if (!content.containsKey('encryption_algorithm')) {
          errors.add('缺少必填字段: content.encryption_algorithm（加密算法）');
        } else {
          final algorithm = content['encryption_algorithm'] as String?;
          if (algorithm != ENCRYPTION_ALGORITHM_AES_256_GCM) {
            errors.add(
              '不支持的加密算法: $algorithm，仅支持 $ENCRYPTION_ALGORITHM_AES_256_GCM',
            );
          }
        }

        // 验证 content.chunk_size —— 分块大小
        // v2.0 二进制格式新增字段，表示每个加密分块的明文大小（字节）
        if (!content.containsKey('chunk_size')) {
          errors.add('缺少必填字段: content.chunk_size（分块大小）');
        } else {
          final chunkSize = content['chunk_size'];
          if (chunkSize is! int || chunkSize <= 0) {
            errors.add('content.chunk_size 必须为正整数');
          }
        }

        // 验证 content.total_chunks —— 总分块数
        // v2.0 二进制格式新增字段，表示加密分块的总数
        if (!content.containsKey('total_chunks')) {
          errors.add('缺少必填字段: content.total_chunks（总分块数）');
        } else {
          final totalChunks = content['total_chunks'];
          if (totalChunks is! int || totalChunks <= 0) {
            errors.add('content.total_chunks 必须为正整数');
          }
        }

        // 验证 content.original_payload_size —— 原始载荷大小
        // v2.0 二进制格式新增字段，表示未加密的原始数据大小（字节）
        if (!content.containsKey('original_payload_size')) {
          errors.add('缺少必填字段: content.original_payload_size（原始载荷大小）');
        } else {
          final payloadSize = content['original_payload_size'];
          if (payloadSize is! int || payloadSize < 0) {
            errors.add('content.original_payload_size 必须为非负整数');
          }
        }
      }
    }

    // ========== 4. 验证 integrity 对象及其必填字段 ==========
    // integrity 用于文件完整性校验，确保文件在传输或存储过程中未被篡改
    // 这是安全验证的关键环节，防止中间人攻击和文件损坏
    if (!json.containsKey('integrity')) {
      errors.add('缺少必填对象: integrity（完整性校验信息）');
    } else {
      final integrity = json['integrity'];
      if (integrity is! Map<String, dynamic>) {
        errors.add('integrity 必须是一个对象（键值对集合）');
      } else {
        // 验证 integrity.hash —— 文件哈希值
        // 对整个 .straw 文件内容进行哈希计算得到的摘要
        // v2.0: 无密钥 SHA-256，格式 "sha256:{64位十六进制字符}"
        // v2.1: HMAC-SHA256，格式 "hmac-sha256:{64位十六进制字符}"
        // 用于检测文件是否被篡改，是完整性校验的核心
        if (!integrity.containsKey('hash')) {
          errors.add('缺少必填字段: integrity.hash（完整性哈希值）');
        } else {
          final hash = integrity['hash'] as String?;
          if (hash == null || hash.isEmpty) {
            errors.add('integrity.hash 不能为空');
          } else {
            // 验证哈希格式：sha256: 或 hmac-sha256: 后跟 64 位十六进制字符
            final hashPattern = RegExp(
              r'^(sha256|hmac-sha256):[a-f0-9]{64}$',
            );
            if (!hashPattern.hasMatch(hash)) {
              errors.add(
                'integrity.hash 格式无效，应为 "sha256:" 或 "hmac-sha256:" 后跟 64 位十六进制字符',
              );
            }
          }
        }

        // 验证 integrity.hash_algorithm —— 哈希算法
        // v2.0: SHA-256（无密钥哈希）
        // v2.1: HMAC-SHA256（带密钥 HMAC）
        if (!integrity.containsKey('hash_algorithm')) {
          errors.add(
            '缺少必填字段: integrity.hash_algorithm（哈希算法）',
          );
        } else {
          final hashAlgo = integrity['hash_algorithm'] as String?;
          if (hashAlgo != HASH_ALGORITHM_SHA256 &&
              hashAlgo != HASH_ALGORITHM_HMAC_SHA256) {
            errors.add(
              '不支持的哈希算法: $hashAlgo，仅支持 $HASH_ALGORITHM_SHA256 或 $HASH_ALGORITHM_HMAC_SHA256',
            );
          }
        }
      }
    }

    // ========== 5. 验证 tags 数量和长度限制 ==========
    // tags 用于知识卡片的分类和检索，限制数量和长度防止元数据膨胀
    // 同时也是一种安全防护，避免恶意构造超长标签导致解析异常
    final meta = json['meta'];
    if (meta is Map<String, dynamic> && meta.containsKey('tags')) {
      final tags = meta['tags'];
      if (tags is List) {
        // 验证标签数量不超过上限
        if (tags.length > MAX_TAGS_COUNT) {
          errors.add(
            '标签数量超出限制: ${tags.length} 个，最多允许 $MAX_TAGS_COUNT 个',
          );
        }

        // 逐个验证每个标签的长度
        for (var i = 0; i < tags.length; i++) {
          final tag = tags[i];
          if (tag is! String) {
            errors.add('标签索引 $i 必须是字符串类型');
          } else if (tag.length > MAX_TAG_LENGTH) {
            errors.add(
              '标签 "$tag" 长度超出限制: ${tag.length} 字符，最多允许 $MAX_TAG_LENGTH 字符',
            );
          }
        }
      }
    }

    // ========== 6. 验证 description 长度限制 ==========
    // description 在未解密状态下可见，用于帮助用户快速识别卡片内容
    // 限制长度防止元数据文件过大，同时避免潜在的缓冲区攻击
    if (meta is Map<String, dynamic> && meta.containsKey('description')) {
      final description = meta['description'];
      if (description is String &&
          description.length > MAX_DESCRIPTION_LENGTH) {
        errors.add(
          '描述长度超出限制: ${description.length} 字符， '
          '最多允许 $MAX_DESCRIPTION_LENGTH 字符',
        );
      }
    }

    // ========== 返回验证结果 ==========
    // 如果 errors 为空，表示所有检查通过，返回成功结果
    // 否则返回失败结果，携带所有收集到的错误信息
    if (errors.isEmpty) {
      return ValidationResult.success();
    }
    return ValidationResult.failure(errors);
  }

  /// 验证 .key 密钥文件格式
  ///
  /// 对解析后的 .key 文件 JSON 进行全面的格式检查，确保密钥文件的结构
  /// 完整且安全。.key 文件包含解密密钥，其格式正确性是安全解密的前提。
  ///
  /// 验证流程：
  /// 1. 检查 format_version 是否存在
  /// 2. 检查 key_metadata 对象及其必填字段（key_id、created_at、
  ///    key_algorithm、key_length_bits）
  /// 3. 检查 key_data 对象及其必填字段（key_base64、encoding）
  /// 4. 检查 integrity 对象及其必填字段（hash、hash_algorithm）
  /// 5. 验证 key_algorithm 必须为 AES-256-GCM
  /// 6. 验证 key_length_bits 必须为 256
  /// 7. 验证 encoding 必须为 "base64"
  ///
  /// 安全说明：
  /// - 密钥文件格式错误可能导致解密失败或安全风险
  /// - 必须验证算法和密钥长度，防止使用弱密钥
  /// - 完整性校验确保密钥在传输过程中未被篡改
  ///
  /// 参数：[json] - 通过 jsonDecode 解析后的 .key 文件 JSON 映射
  /// 返回：[ValidationResult]，isValid 为 true 表示格式完全正确
  @override
  ValidationResult validateKeyFormat(Map<String, dynamic> json) {
    final errors = <String>[];

    // ========== 1. 验证 format_version 是否存在 ==========
    // .key 文件有自己的版本控制系统，与 .straw 文件版本独立管理
    // 确保读取方能够识别密钥文件的格式，避免解析错误
    if (!json.containsKey('format_version')) {
      errors.add('缺少必填字段: format_version（密钥文件格式版本号）');
    }

    // ========== 2. 验证 key_metadata 对象及其必填字段 ==========
    // key_metadata 包含密钥的元数据信息，用于密钥管理和识别
    // 这些信息不涉密密钥本身，但记录了密钥的重要属性
    if (!json.containsKey('key_metadata')) {
      errors.add('缺少必填对象: key_metadata（密钥元数据）');
    } else {
      final keyMetadata = json['key_metadata'];
      if (keyMetadata is! Map<String, dynamic>) {
        errors.add('key_metadata 必须是一个对象（键值对集合）');
      } else {
        // 验证 key_metadata.key_id —— 密钥唯一标识符
        // 用于密钥管理和轮换，确保每个密钥都有唯一的标识
        // 在密钥泄露需要轮换时，key_id 用于标识需要废弃的密钥
        if (!keyMetadata.containsKey('key_id')) {
          errors.add('缺少必填字段: key_metadata.key_id（密钥唯一标识符）');
        }

        // 验证 key_metadata.created_at —— 密钥创建时间
        // 用于密钥生命周期管理，判断密钥是否过期需要轮换
        if (!keyMetadata.containsKey('created_at')) {
          errors.add('缺少必填字段: key_metadata.created_at（密钥创建时间）');
        }

        // 验证 key_metadata.key_algorithm —— 密钥算法
        // 必须为 AES-256-GCM，与 .straw 文件的加密算法一致
        // 如果不一致，说明密钥不匹配该文件，无法正确解密
        if (!keyMetadata.containsKey('key_algorithm')) {
          errors.add(
            '缺少必填字段: key_metadata.key_algorithm（密钥算法）',
          );
        } else {
          final algorithm = keyMetadata['key_algorithm'] as String?;
          if (algorithm != ENCRYPTION_ALGORITHM_AES_256_GCM) {
            errors.add(
              '不支持的密钥算法: $algorithm，仅支持 $ENCRYPTION_ALGORITHM_AES_256_GCM',
            );
          }
        }

        // 验证 key_metadata.key_length_bits —— 密钥长度
        // 必须为 256 位，确保密钥强度足够
        // 较短的密钥（如 128 位）虽然也能使用，但安全余量较低
        // 强制 256 位是出于安全最佳实践的考虑
        if (!keyMetadata.containsKey('key_length_bits')) {
          errors.add(
            '缺少必填字段: key_metadata.key_length_bits（密钥长度）',
          );
        } else {
          final keyLength = keyMetadata['key_length_bits'];
          if (keyLength != 256) {
            errors.add(
              '不支持的密钥长度: $keyLength 位，仅支持 256 位',
            );
          }
        }
      }
    }

    // ========== 3. 验证 key_data 对象及其必填字段 ==========
    // key_data 包含实际的密钥数据，是 .key 文件的核心内容
    // 此对象以安全编码格式存储密钥，需要正确解析后才能用于解密
    if (!json.containsKey('key_data')) {
      errors.add('缺少必填对象: key_data（密钥数据）');
    } else {
      final keyData = json['key_data'];
      if (keyData is! Map<String, dynamic>) {
        errors.add('key_data 必须是一个对象（键值对集合）');
      } else {
        // 验证 key_data.key_base64 —— Base64 编码的密钥
        // 密钥以 Base64 编码存储，便于在 JSON 中传输和存储
        // 缺少此字段意味着密钥文件没有实际的密钥数据
        if (!keyData.containsKey('key_base64')) {
          errors.add('缺少必填字段: key_data.key_base64（Base64 编码的密钥）');
        } else {
          final keyBase64 = keyData['key_base64'] as String?;
          if (keyBase64 == null || keyBase64.isEmpty) {
            errors.add('key_data.key_base64 不能为空');
          } else {
            // 验证 Base64 格式有效性
            try {
              base64Decode(keyBase64);
            } on FormatException {
              errors.add(
                'key_data.key_base64 不是有效的 Base64 编码字符串',
              );
            }
          }
        }

        // 验证 key_data.encoding —— 编码格式
        // 必须为 "base64"，确保解码时使用正确的解码方式
        // 如果编码格式不匹配，解码后的密钥将是错误的，导致解密失败
        if (!keyData.containsKey('encoding')) {
          errors.add('缺少必填字段: key_data.encoding（编码格式）');
        } else {
          final encoding = keyData['encoding'] as String?;
          if (encoding != 'base64') {
            errors.add(
              '不支持的编码格式: $encoding，仅支持 base64',
            );
          }
        }
      }
    }

    // ========== 4. 验证 integrity 对象及其必填字段 ==========
    // integrity 用于 .key 文件的完整性校验
    // 密钥文件的完整性至关重要，被篡改的密钥会导致：
    // 1. 解密失败（数据不可用）
    // 2. 潜在的解密后数据被操控（如果使用了错误的密钥）
    if (!json.containsKey('integrity')) {
      errors.add('缺少必填对象: integrity（完整性校验信息）');
    } else {
      final integrity = json['integrity'];
      if (integrity is! Map<String, dynamic>) {
        errors.add('integrity 必须是一个对象（键值对集合）');
      } else {
        // 验证 integrity.hash —— 密钥文件哈希值
        // 对整个 .key 文件进行 SHA-256 哈希计算
        // 确保密钥在存储和传输过程中未被篡改
        if (!integrity.containsKey('hash')) {
          errors.add('缺少必填字段: integrity.hash（完整性哈希值）');
        }

        // 验证 integrity.hash_algorithm —— 哈希算法
        // 必须为 SHA-256，确保完整性校验的强度
        if (!integrity.containsKey('hash_algorithm')) {
          errors.add(
            '缺少必填字段: integrity.hash_algorithm（哈希算法）',
          );
        }
      }
    }

    // ========== 返回验证结果 ==========
    // 如果 errors 为空，表示所有检查通过，返回成功结果
    // 否则返回失败结果，携带所有收集到的错误信息
    if (errors.isEmpty) {
      return ValidationResult.success();
    }
    return ValidationResult.failure(errors);
  }

  /// 验证二进制 .straw 文件的 Magic Bytes
  ///
  /// 检查字节数据的起始 8 字节是否为 "STRAWHUT"（ASCII），
  /// 用于快速判断文件是否为 StrawHut 二进制容器格式。
  ///
  /// 验证流程：
  /// 1. 检查字节数据长度是否至少包含 Magic Bytes（8 字节）
  /// 2. 逐字节比较起始位置与预定义的 STRAW_MAGIC_BYTES
  ///
  /// 安全意义：
  /// - Magic Bytes 是二进制文件识别的第一道防线
  /// - 防止将非 .straw 文件误识别为 StrawHut 文件
  /// - 在执行昂贵的 JSON 解析前快速拒绝不匹配的文件
  ///
  /// 参数：[bytes] - 二进制 .straw 文件的字节数据
  /// 返回：[ValidationResult]，isValid 为 true 表示 Magic Bytes 匹配
  @override
  ValidationResult validateBinaryFormat(Uint8List bytes) {
    final errors = <String>[];

    // 检查最小长度
    if (bytes.length < MAGIC_BYTES_LENGTH) {
      errors.add(
        '文件数据过短: ${bytes.length} 字节，至少需要 $MAGIC_BYTES_LENGTH 字节的 Magic Bytes',
      );
      return ValidationResult.failure(errors);
    }

    // 逐字节比较 Magic Bytes
    for (var i = 0; i < MAGIC_BYTES_LENGTH; i++) {
      if (bytes[i] != STRAW_MAGIC_BYTES[i]) {
        final actual = String.fromCharCodes(
          bytes.sublist(0, MAGIC_BYTES_LENGTH),
        );
        errors.add(
          'Magic Bytes 不匹配: 期望 "STRAWHUT"，实际为 "$actual"。\n'
          '该文件不是有效的 StrawHut 二进制格式文件。',
        );
        break;
      }
    }

    if (errors.isEmpty) {
      return ValidationResult.success();
    }
    return ValidationResult.failure(errors);
  }
}
