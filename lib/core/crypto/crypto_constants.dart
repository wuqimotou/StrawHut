/// 加密算法标识
///
/// 定义 StrawHut 使用的对称加密算法标准。
/// 当前采用 AES-256-GCM（高级加密标准，256位密钥，Galois/Counter模式），
/// 提供加密和消息认证码（MAC）双重保护。
///
/// 安全特性：
/// - AES-256：NIST 推荐的强加密标准，广泛用于金融和政府领域
/// - GCM 模式：提供认证加密（AEAD），防止密文被篡改
/// - 支持硬件加速（AES-NI 指令集），提升加密/解密性能
const String ENCRYPTION_ALGORITHM_AES_256_GCM = 'AES-256-GCM';

/// 密钥长度（字节）
///
/// AES-256 需要 32 字节（256 位）的密钥。
/// 密钥由 CSPRNG（密码学安全伪随机数生成器）生成，
/// 确保每个密钥具有足够的熵（随机性），防止暴力破解。
///
/// 安全说明：
/// - 32 字节 = 256 位，提供 2^256 的密钥空间
/// - 理论上无法通过暴力穷举破解
const int KEY_LENGTH_BYTES = 32; // 256 bits

/// IV/Nonce 长度（字节）- 旧版兼容
///
/// 初始化向量（Initialization Vector）用于确保相同的明文每次加密产生不同的密文。
/// 此为旧版 `encrypt` 包使用的 16 字节 IV 长度，新加密使用 [NATIVE_IV_LENGTH_BYTES]（12 字节）。
///
/// 安全说明：
/// - IV 必须是加密安全的随机数
/// - 同一密钥下 IV 不可重复使用
/// - IV 不需要保密，可随密文一起传输
@Deprecated('Use NATIVE_IV_LENGTH_BYTES instead')
const int IV_LENGTH_BYTES = 16;

/// 原生加密 IV/Nonce 长度（字节）
///
/// NIST SP 800-38D 推荐的 GCM 模式标准 IV 长度（96 位）。
/// 新加密使用此长度，解密同时支持 12 字节和 16 字节 IV。
const int NATIVE_IV_LENGTH_BYTES = 12;

/// 哈希算法标识
///
/// 定义 StrawHut 使用的完整性校验哈希算法。
/// SHA-256（安全哈希算法 256 位）用于：
/// 1. 验证 .straw 文件是否被篡改
/// 2. 验证 .key 文件是否被篡改
///
/// 安全特性：
/// - 输出 256 位（32 字节）哈希值
/// - 抗碰撞性强，难以找到两个不同输入产生相同哈希
/// - 广泛用于数字签名和文件完整性验证
const String HASH_ALGORITHM_SHA256 = 'SHA-256';

/// .straw 知识卡片文件格式版本号
///
/// 采用语义化版本控制（Semantic Versioning）：major.minor.patch
/// - 主版本号（Major）：不兼容的格式变更
/// - 次版本号（Minor）：向后兼容的功能新增
/// - 修订号（Patch）：向后兼容的 Bug 修复
///
/// 兼容性策略：
/// - 主版本相同 → 正常读取
/// - 文件主版本高于当前软件 → 拒绝读取，提示更新
/// - 文件主版本低于当前软件 → 兼容模式读取
const String STRAW_FORMAT_VERSION = '2.0.0';

/// .key 密钥文件格式版本号
///
/// 与 .straw 版本独立管理，确保密钥文件格式的向后兼容性。
const String KEY_FORMAT_VERSION = '1.0.0';

/// 匿名标识前缀
/// 匿名发布者前缀
///
/// 当用户开启匿名模式时，系统自动生成的发布者代号：
/// "Anonymous"
const String ANONYMOUS_PREFIX = 'Anonymous';

/// 标签最大数量
///
/// 每张知识卡片最多允许 10 个标签，用于分类和检索。
/// 限制标签数量防止元数据过度膨胀，影响文件可读性。
const int MAX_TAGS_COUNT = 10;

/// 标签最大长度（字符数）
///
/// 每个标签最长 20 个字符，确保标签简洁明了。
/// 超出此限制的标签将被格式验证服务拒绝。
const int MAX_TAG_LENGTH = 20;

/// 描述最大长度（字符数）
///
/// 知识卡片描述最长 200 个字符。
/// 描述内容在未解密状态下可见，帮助用户识别卡片内容。
const int MAX_DESCRIPTION_LENGTH = 200;

/// 盐值长度（字节）
///
/// 用于密钥派生函数（KDF）的盐值长度。
/// 16 字节（128 位）的盐值可提供足够的随机性，
/// 防止彩虹表攻击和预计算攻击。
///
/// 安全说明：
/// - 盐值必须使用 CSPRNG 生成
/// - 每次加密应使用不同的盐值
/// - 盐值不需要保密，可随密文一起存储
const int SALT_LENGTH_BYTES = 16;

/// 密钥派生算法标识
///
/// 使用 PBKDF2-HMAC-SHA256 从口令派生加密密钥。
/// PBKDF2（Password-Based Key Derivation Function 2）是 NIST 推荐的
/// 基于口令的密钥派生标准，结合 HMAC-SHA256 提供强安全性。
const String KDF_ALGORITHM_PBKDF2 = 'PBKDF2-HMAC-SHA256';

/// KDF 迭代次数
///
/// PBKDF2 的迭代次数，100000 次是当前 OWASP 推荐的最小值。
/// 更高的迭代次数增加暴力破解的成本，但也会增加密钥派生的耗时。
///
/// 性能参考：100000 次迭代在现代设备上约需 100-300ms
const int KDF_ITERATIONS = 100000;

/// 口令最小长度
///
/// 用户设置的口令至少需要 8 个字符。
/// 低于此长度的口令将被视为 veryWeak 强度。
const int PASSPHRASE_MIN_LENGTH = 8;

/// 口令推荐长度
///
/// 推荐用户使用 12 个字符以上的口令，
/// 以获得更好的安全性。
const int PASSPHRASE_RECOMMENDED_LENGTH = 12;

/// 最大连续相同字符数
///
/// 口令中不允许出现 6 个及以上连续相同字符，
/// 如 "aaaaaa" 或 "111111"，防止弱口令。
const int MAX_CONSECUTIVE_SAME_CHAR = 6;

/// 默认分块大小（1MB）
///
/// 分块加密/解密时每个分块的明文大小上限。
/// 1MB = 1048576 字节，在内存占用和加密性能之间取得平衡。
/// 第一个分块因包含元数据前缀，实际载荷容量会略小。
const int DEFAULT_CHUNK_SIZE = 1048576;

/// 分块 IV 长度（字节）
///
/// 每个加密分块使用独立的 16 字节 IV（初始化向量），
/// 确保相同密钥下不同分块的 IV 不重复。
const int CHUNK_IV_LENGTH_BYTES = 16;

/// GCM 认证标签长度（字节）
///
/// AES-256-GCM 模式在密文末尾附加 16 字节认证标签（MAC），
/// 用于验证密文完整性和真实性。
/// 加密后每个分块的密文大小 = 明文大小 + GCM_TAG_LENGTH_BYTES。
const int GCM_TAG_LENGTH_BYTES = 16;

// ============================================================================
// 二进制容器格式常量（.straw v2.0）
// ============================================================================

/// 二进制 .straw 文件 Magic Bytes
///
/// 8 字节 ASCII 字符串 "STRAWHUT"，位于二进制文件偏移 0x00000000。
/// 用于快速识别文件是否为 StrawHut 二进制格式。
const List<int> STRAW_MAGIC_BYTES = [
  0x53,
  0x54,
  0x52,
  0x41,
  0x57,
  0x48,
  0x55,
  0x54,
]; // "STRAWHUT"

/// Magic Bytes 长度（字节）
///
/// 固定为 8 字节，与 STRAW_MAGIC_BYTES 长度一致。
const int MAGIC_BYTES_LENGTH = 8;

/// 二进制格式主版本号
///
/// 位于二进制文件偏移 0x00000008，2 字节 uint16 LE。
/// 当前值为 2，对应 .straw v2.0 格式。
const int BINARY_FORMAT_MAJOR = 2;

/// 二进制格式次版本号
///
/// 位于二进制文件偏移 0x0000000A，2 字节 uint16 LE。
/// 当前值为 0，对应 .straw v2.0 格式。
const int BINARY_FORMAT_MINOR = 0;
