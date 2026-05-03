/// Mock 类定义文件
///
/// 本文件定义用于 Provider 单元测试的 Mock 类和 Fake 类，
/// 使用 mocktail 库实现。

import 'package:mocktail/mocktail.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';

/// FileIOService 的 Mock 类（扩展 Mock 并实现 FileIOService）
class MockFileIOService extends Mock implements FileIOService {}

/// StrawFile 的 Fake 类，用于 registerFallbackValue
class FakeStrawFile extends Fake implements StrawFile {}

/// 创建用于测试的 StrawFile 实例
StrawFile createTestStrawFile({String title = 'Test Card'}) {
  return StrawFile(
    formatVersion: FormatVersion.fromString('1.0.0'),
    meta: CardMeta(
      publisherAlias: 'Test Author',
      publishDate: '2026-05-01T12:00:00Z',
      title: title,
      isAnonymous: false,
      tags: ['test'],
      description: 'Test Description',
    ),
    content: const EncryptedContent(
      encryptedDataBase64: 'dGVzdA==',
      ivBase64: 'dGVzdA==',
      algorithm: 'AES-256-GCM',
    ),
    integrity: const IntegrityInfo(
      hash: 'sha256:test',
      hashAlgorithm: 'SHA-256',
    ),
  );
}
