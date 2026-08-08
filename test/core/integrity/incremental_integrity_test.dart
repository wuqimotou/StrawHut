import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';

void main() {
  const strawFile = StrawFile(
    formatVersion: FormatVersion(2, 0, 0),
    meta: CardMeta(
      publisherAlias: 'tester',
      publishDate: '2026-07-14T00:00:00Z',
      title: 'incremental hash',
      isAnonymous: false,
    ),
    content: StrawContent(
      encryptionAlgorithm: 'AES-256-GCM',
      chunkSize: 128,
      totalChunks: 2,
      originalPayloadSize: 100,
    ),
    integrity: IntegrityInfo(hash: '', hashAlgorithm: 'SHA-256'),
  );

  final chunks = <ChunkInfo>[
    ChunkInfo(iv: Uint8List(16), encryptedData: Uint8List.fromList([1, 2, 3])),
    ChunkInfo(
      iv: Uint8List.fromList(List<int>.filled(16, 4)),
      encryptedData: Uint8List.fromList([5, 6, 7, 8]),
    ),
  ];

  test('incremental chunk hash matches binary container hash', () async {
    final integrityService = IntegrityService();
    final binary = FileIOService().buildBinaryFileBytes(
      strawFile: strawFile,
      chunks: chunks,
    );

    final incremental = await integrityService.computeHashFromChunks(
      strawFile: strawFile,
      chunks: chunks,
    );

    expect(incremental, integrityService.computeHashFromBytes(binary));
  });

  test('incremental chunk hash can be cancelled during verification', () async {
    final integrityService = IntegrityService();
    final token = CancellationToken();

    await expectLater(
      integrityService.computeHashFromChunks(
        strawFile: strawFile,
        chunks: chunks,
        cancellationToken: token,
        onProgress: (current, total) {
          if (current == 1) token.cancel();
        },
      ),
      throwsA(isA<OperationCancelledException>()),
    );
  });
}
