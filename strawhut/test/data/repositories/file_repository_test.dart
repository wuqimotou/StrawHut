import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/repositories/file_repository.dart';

// Mock class for IFileIOService
class MockFileIOService extends Mock implements IFileIOService {}

void main() {
  late FileRepository fileRepository;
  late MockFileIOService mockFileIOService;

  setUp(() {
    mockFileIOService = MockFileIOService();
    fileRepository = FileRepository(mockFileIOService);
  });

  // ==========================================
  // loadStrawFile 测试
  // ==========================================
  group('FileRepository.loadStrawFile', () {
    test('成功加载 .straw 文件并返回 StrawFile 对象', () async {
      // Arrange: 构造一个有效的 StrawFile mock 返回值
      const mockStrawFile = StrawFile(
        formatVersion: FormatVersion(1, 0, 0),
        meta: CardMeta(
          publisherAlias: 'Anonymous_test',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          tags: ['test'],
          description: '测试描述',
          isAnonymous: true,
        ),
        content: EncryptedContent(
          encryptedDataBase64: 'dGVzdA==',
          ivBase64: 'YWJjZGVmZ2hpamtsbW5vcA==',
          algorithm: 'AES-256-GCM',
        ),
        integrity: IntegrityInfo(
          hash: 'sha256:testhash',
          hashAlgorithm: 'SHA-256',
        ),
      );

      when(() => mockFileIOService.readStrawFile(any())).thenAnswer(
        (_) async => mockStrawFile,
      );

      // Act
      final result = await fileRepository.loadStrawFile('/path/to/card.straw');

      // Assert
      expect(result, isA<StrawFile>());
      expect(result.meta.title, '测试卡片');
      verify(() => mockFileIOService.readStrawFile('/path/to/card.straw'))
          .called(1);
    });

    test('文件不存在时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readStrawFile(any())).thenThrow(
        const FileException(
          '文件不存在',
          code: 'FILE_NOT_FOUND',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadStrawFile('/path/to/nonexistent.straw'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'FILE_NOT_FOUND',
          ),
        ),
      );
    });

    test('扩展名不正确时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readStrawFile(any())).thenThrow(
        const FileException(
          '无效的文件扩展名',
          code: 'INVALID_EXTENSION',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadStrawFile('/path/to/file.txt'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'INVALID_EXTENSION',
          ),
        ),
      );
    });

    test('JSON 格式错误时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readStrawFile(any())).thenThrow(
        const FileException(
          'JSON 解析失败',
          code: 'INVALID_FORMAT',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadStrawFile('/path/to/corrupted.straw'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'INVALID_FORMAT',
          ),
        ),
      );
    });

    test('格式验证失败时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readStrawFile(any())).thenThrow(
        const FileException(
          '文件格式验证失败',
          code: 'VALIDATION_FAILED',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadStrawFile('/path/to/invalid.straw'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'VALIDATION_FAILED',
          ),
        ),
      );
    });
  });

  // ==========================================
  // saveStrawFile 测试
  // ==========================================
  group('FileRepository.saveStrawFile', () {
    StrawFile createTestStrawFile() {
      return const StrawFile(
        formatVersion: FormatVersion(1, 0, 0),
        meta: CardMeta(
          publisherAlias: 'Anonymous_test',
          publishDate: '2026-05-01T12:00:00Z',
          title: '测试卡片',
          tags: ['test'],
          description: '测试描述',
          isAnonymous: true,
        ),
        content: EncryptedContent(
          encryptedDataBase64: 'dGVzdA==',
          ivBase64: 'YWJjZGVmZ2hpamtsbW5vcA==',
          algorithm: 'AES-256-GCM',
        ),
        integrity: IntegrityInfo(
          hash: 'sha256:testhash',
          hashAlgorithm: 'SHA-256',
        ),
      );
    }

    test('成功保存 .straw 文件', () async {
      // Arrange
      final strawFile = createTestStrawFile();

      when(
        () => mockFileIOService.writeStrawFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await fileRepository.saveStrawFile(
        strawFile: strawFile,
        targetPath: '/path/to/output.straw',
      );

      // Assert
      verify(
        () => mockFileIOService.writeStrawFile(
          content: any(named: 'content'),
          targetPath: '/path/to/output.straw',
        ),
      ).called(1);
    });

    test('验证调用 assembleToJson 和 writeStrawFile', () async {
      // Arrange
      final strawFile = createTestStrawFile();

      when(
        () => mockFileIOService.writeStrawFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await fileRepository.saveStrawFile(
        strawFile: strawFile,
        targetPath: '/path/to/output.straw',
      );

      // Assert: 验证 writeStrawFile 被调用，且 content 参数是 JSON 字符串
      final captured = verify(
        () => mockFileIOService.writeStrawFile(
          content: captureAny(named: 'content'),
          targetPath: captureAny(named: 'targetPath'),
        ),
      ).captured;

      // captured[0] 是 content 参数，captured[1] 是 targetPath 参数
      expect(captured[0], isA<String>());
      expect(captured[1], '/path/to/output.straw');
    });

    test('写入失败时抛出 FileException', () async {
      // Arrange
      final strawFile = createTestStrawFile();

      when(
        () => mockFileIOService.writeStrawFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenThrow(
        const FileException(
          '写入文件失败',
          code: 'WRITE_FAILED',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.saveStrawFile(
          strawFile: strawFile,
          targetPath: '/invalid/path/output.straw',
        ),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'WRITE_FAILED',
          ),
        ),
      );
    });
  });

  // ==========================================
  // loadKeyFile 测试
  // ==========================================
  group('FileRepository.loadKeyFile', () {
    test('成功加载 .key 文件并返回 KeyFile 对象', () async {
      // Arrange
      const mockKeyFile = KeyFile(
        formatVersion: FormatVersion(1, 0, 0),
        keyMetadata: KeyMetadata(
          keyId: 'k_test123',
          createdAt: '2026-05-01T12:00:00Z',
          associatedCardTitle: '测试卡片',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: KeyData(
          keyBase64: 'xK9mP2vR7wN4jQ8tL5yH3bF6dA1cE0gU6sZ9oI2eM=',
          encoding: 'base64',
        ),
        integrity: IntegrityInfo(
          hash: 'sha256:testhash',
          hashAlgorithm: 'SHA-256',
        ),
      );

      when(() => mockFileIOService.readKeyFile(any())).thenAnswer(
        (_) async => mockKeyFile,
      );

      // Act
      final result = await fileRepository.loadKeyFile('/path/to/secret.key');

      // Assert
      expect(result, isA<KeyFile>());
      expect(result.keyMetadata.keyId, 'k_test123');
      verify(() => mockFileIOService.readKeyFile('/path/to/secret.key'))
          .called(1);
    });

    test('文件不存在时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readKeyFile(any())).thenThrow(
        const FileException(
          '文件不存在',
          code: 'FILE_NOT_FOUND',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadKeyFile('/path/to/nonexistent.key'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'FILE_NOT_FOUND',
          ),
        ),
      );
    });

    test('扩展名不正确时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readKeyFile(any())).thenThrow(
        const FileException(
          '无效的文件扩展名',
          code: 'INVALID_EXTENSION',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadKeyFile('/path/to/file.txt'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'INVALID_EXTENSION',
          ),
        ),
      );
    });

    test('JSON 格式错误时抛出 FileException', () async {
      // Arrange
      when(() => mockFileIOService.readKeyFile(any())).thenThrow(
        const FileException(
          'JSON 解析失败',
          code: 'INVALID_FORMAT',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.loadKeyFile('/path/to/corrupted.key'),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'INVALID_FORMAT',
          ),
        ),
      );
    });
  });

  // ==========================================
  // saveKeyFile 测试
  // ==========================================
  group('FileRepository.saveKeyFile', () {
    KeyFile createTestKeyFile() {
      return const KeyFile(
        formatVersion: FormatVersion(1, 0, 0),
        keyMetadata: KeyMetadata(
          keyId: 'k_test123',
          createdAt: '2026-05-01T12:00:00Z',
          associatedCardTitle: '测试卡片',
          keyAlgorithm: 'AES-256-GCM',
          keyLengthBits: 256,
        ),
        keyData: KeyData(
          keyBase64: 'xK9mP2vR7wN4jQ8tL5yH3bF6dA1cE0gU6sZ9oI2eM=',
          encoding: 'base64',
        ),
        integrity: IntegrityInfo(
          hash: 'sha256:testhash',
          hashAlgorithm: 'SHA-256',
        ),
      );
    }

    test('成功保存 .key 文件', () async {
      // Arrange
      final keyFile = createTestKeyFile();

      when(
        () => mockFileIOService.writeKeyFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await fileRepository.saveKeyFile(
        keyFile: keyFile,
        targetPath: '/path/to/secret.key',
      );

      // Assert
      verify(
        () => mockFileIOService.writeKeyFile(
          content: any(named: 'content'),
          targetPath: '/path/to/secret.key',
        ),
      ).called(1);
    });

    test('验证调用 toJson 和 writeKeyFile', () async {
      // Arrange
      final keyFile = createTestKeyFile();

      when(
        () => mockFileIOService.writeKeyFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await fileRepository.saveKeyFile(
        keyFile: keyFile,
        targetPath: '/path/to/secret.key',
      );

      // Assert: 验证 writeKeyFile 被调用，且 content 参数是 JSON 字符串
      final captured = verify(
        () => mockFileIOService.writeKeyFile(
          content: captureAny(named: 'content'),
          targetPath: captureAny(named: 'targetPath'),
        ),
      ).captured;

      expect(captured[0], isA<String>());
      expect(captured[1], '/path/to/secret.key');
    });

    test('写入失败时抛出 FileException', () async {
      // Arrange
      final keyFile = createTestKeyFile();

      when(
        () => mockFileIOService.writeKeyFile(
          content: any(named: 'content'),
          targetPath: any(named: 'targetPath'),
        ),
      ).thenThrow(
        const FileException(
          '写入密钥文件失败',
          code: 'WRITE_FAILED',
        ),
      );

      // Act & Assert
      expect(
        () async => fileRepository.saveKeyFile(
          keyFile: keyFile,
          targetPath: '/invalid/path/secret.key',
        ),
        throwsA(
          isA<FileException>().having(
            (e) => e.code,
            'code',
            'WRITE_FAILED',
          ),
        ),
      );
    });
  });
}
