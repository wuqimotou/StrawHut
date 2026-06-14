$f = "c:\GitHub Repositories\StrawHut\Reference_Docs\技术说明文档.md"
$c = Get-Content -Path $f -Raw -Encoding UTF8

# 1. image package description
$c = $c -replace '\| `image` \| \^4\.3\.0 \| 纯 Dart 图片处理（压缩 \+ PNG 编码） \|', '| `image` | ^4.3.0 | 纯 Dart 图片处理（编辑器嵌入图片的压缩与缩放） |'

# 2. Merge file_picker line and remove file_selector
$c = $c -replace '\| `file_picker` \| \^8\.1\.7 \| 跨平台文件选择器 \|\r?\n\| `file_selector` \| \^1\.0\.3 \| 文件选择（桌面端） \|', '| `file_picker` | ^8.1.7 | 跨平台文件选择器（所有平台统一使用） |'

# 3. Locale default
$c = $c -replace "Locale build\(\) => const Locale\('zh', 'CN'\)", "Locale build() => const Locale('zh')"

# 4. PNG chunk keyword
$c = $c -replace '\(StrawHut\)', '(strawhut)'

# 5. Integrity code block
$c = $c -replace '// 计算完整 JSON 的哈希\r?\nfinal hash = integrityService\.computeHash\(strawFileJson\);\r?\n// 将哈希写入 integrity 字段\r?\nstrawFile\.integrity = IntegrityInfo\(hash: hash, hashAlgorithm: ''SHA-256''\);', '// 在构建 StrawFile 对象前，先计算不含 integrity 字段的 JSON 哈希，\r\n// 再将哈希值作为 integrity 字段传入 StrawFile 构造函数\r\nfinal hash = integrityService.computeHash(contentWithoutIntegrity);\r\nfinal strawFile = StrawFile(\r\n  formatVersion: FormatVersion.fromString(STRAW_FORMAT_VERSION),\r\n  meta: cardMeta,\r\n  content: encryptedContent,\r\n  integrity: IntegrityInfo(hash: hash, hashAlgorithm: HASH_ALGORITHM_SHA256),\r\n);'

# 6. AndroidFileSaver
$oldSaver = "class AndroidFileSaver {\r\n  // 保存文件到 MediaStore\r\n  Future<void> saveToMediaStore\({\r\n    required Uint8List bytes,\r\n    required String fileName,\r\n    required String mimeType,\r\n  }\) async {\r\n    // 使用 MediaStore API 保存文件\r\n    // 保存后立即可在相册中查看\r\n  }\r\n}"
$newSaver = "class AndroidFileSaver {\r\n  static const _channel = MethodChannel('com.strawhut.strawhut/file_saver');\r\n\r\n  /// 保存文件到系统 Downloads 文件夹（.straw / .key）\r\n  static Future<String?> saveToDownloads({\r\n    required String fileName,\r\n    required String mimeType,\r\n    required Uint8List bytes,\r\n  }) async {\r\n    // 使用 MediaStore API 保存到 Downloads\r\n    // 返回 content URI 或 null\r\n  }\r\n\r\n  /// 保存 PNG 图片到系统 Pictures 文件夹\r\n  static Future<String?> saveToPictures({\r\n    required String fileName,\r\n    required Uint8List bytes,\r\n  }) async {\r\n    // 使用 MediaStore API 保存到 Pictures\r\n    // 保存后立即可在相册中查看\r\n    // 返回 content URI 或 null\r\n  }\r\n}"
$c = $c -replace [regex]::Escape($oldSaver), $newSaver

# 7. Windows section - file_selector references
$c = $c -replace '- ✅ 文件选择器（file_selector）', '- ✅ 文件选择器（file_picker）'
$c = $c -replace '使用 `file_selector` 提供原生文件选择体验', '使用 `file_picker` 提供跨平台文件选择体验'

# 8. P2P interface
$oldP2P = "abstract class P2PService {\r\n  /// 发布知识卡片到 P2P 网络\r\n  Future<void> publishCard\(StrawFile card\);\r\n  \r\n  /// 从 P2P 网络搜索知识卡片\r\n  Future<List<StrawFile>> searchCards\(String query\);\r\n  \r\n  /// 下载知识卡片\r\n  Future<StrawFile> downloadCard\(String cardId\);\r\n}"
$newP2P = "abstract class IP2PService {\r\n  /// 发布知识卡片到 P2P 网络\r\n  Future<void> publishToNetwork\(\);\r\n\r\n  /// 发现网络中的知识卡片\r\n  Future<void> discoverCards\(\);\r\n\r\n  /// 下载指定知识卡片\r\n  Future<void> downloadCard\(\);\r\n\r\n  /// 获取 P2P 服务状态\r\n  Future<void> getStatus\(\);\r\n\r\n  /// 关闭 P2P 连接\r\n  Future<void> shutdown\(\);\r\n}"
$c = $c -replace [regex]::Escape($oldP2P), $newP2P

$oldP2PStub = "class P2PStub implements P2PService {\r\n  @override\r\n  Future<void> publishCard\(StrawFile card\) async {\r\n    throw UnimplementedError\('P2P functionality is not yet implemented'\);\r\n  }\r\n  \r\n  // \.\.\. 其他方法\r\n}"
$newP2PStub = "class P2PStub implements IP2PService {\r\n  @override\r\n  Future<void> publishToNetwork\(\) async {\r\n    throw UnimplementedError\('P2P service not implemented'\);\r\n  }\r\n\r\n  @override\r\n  Future<void> discoverCards\(\) async {\r\n    throw UnimplementedError\('P2P service not implemented'\);\r\n  }\r\n\r\n  @override\r\n  Future<void> downloadCard\(\) async {\r\n    throw UnimplementedError\('P2P service not implemented'\);\r\n  }\r\n\r\n  @override\r\n  Future<void> getStatus\(\) async {\r\n    throw UnimplementedError\('P2P service not implemented'\);\r\n  }\r\n\r\n  @override\r\n  Future<void> shutdown\(\) async {\r\n    throw UnimplementedError\('P2P service not implemented'\);\r\n  }\r\n}"
$c = $c -replace [regex]::Escape($oldP2PStub), $newP2PStub

# 9. Exception type
$c = $c -replace '\| `FormatException` \| 格式验证异常 \|', '| `StrawFormatException` | 格式验证异常 |'

Set-Content -Path $f -Value $c -Encoding UTF8 -NoNewline
Write-Output "File updated successfully"