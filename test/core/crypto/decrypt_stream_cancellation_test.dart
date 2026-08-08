import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';

void main() {
  test(
    'stream cancellation removes partial plaintext and preserves source',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('strawhut_cancel_');
      final sourcePath = '${tempDir.path}${Platform.pathSeparator}source.straw';
      final targetPath = '${tempDir.path}${Platform.pathSeparator}plain.bin';

      try {
        final cryptoService = CryptoService(IntegrityService());
        final key = await cryptoService.generateKey();
        final payload = Uint8List.fromList(
          List<int>.generate(4096, (index) => index % 256),
        );
        final encrypted = await cryptoService.encrypt(
          payloadBytes: payload,
          payloadMetadata: const PayloadMetadata(
            sourceType: SourceType.rawFile,
            originalExtension: 'bin',
          ),
          key: key.bytes,
          chunkSize: 256,
          useV21Security: false,
        );
        final strawFile = StrawFile(
          formatVersion: const FormatVersion(2, 0, 0),
          meta: const CardMeta(
            publisherAlias: 'tester',
            publishDate: '2026-07-14T00:00:00Z',
            title: 'cancel stream',
            isAnonymous: false,
          ),
          content: StrawContent(
            encryptionAlgorithm: 'AES-256-GCM',
            chunkSize: encrypted.chunkSize,
            totalChunks: encrypted.totalChunks,
            originalPayloadSize: encrypted.originalPayloadSize,
          ),
          integrity: const IntegrityInfo(
            hash: 'sha256:test',
            hashAlgorithm: 'SHA-256',
          ),
        );
        final sourceBytes = FileIOService().buildBinaryFileBytes(
          strawFile: strawFile,
          chunks: encrypted.chunks,
        );
        await File(sourcePath).writeAsBytes(sourceBytes);
        final token = CancellationToken();

        await expectLater(
          cryptoService.decryptStream(
            strawFilePath: sourcePath,
            key: key.bytes,
            targetPath: targetPath,
            chunkSize: encrypted.chunkSize,
            originalPayloadSize: encrypted.originalPayloadSize,
            cancellationToken: token,
            onProgress: (current, total) {
              if (current == 1) token.cancel();
            },
          ),
          throwsA(isA<OperationCancelledException>()),
        );

        expect(await File(targetPath).exists(), isFalse);
        expect(await File(sourcePath).readAsBytes(), sourceBytes);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
