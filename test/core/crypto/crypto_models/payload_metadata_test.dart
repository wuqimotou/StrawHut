import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';

void main() {
  group('PayloadMetadata 构造', () {
    test('应正确构造含必填字段的实例', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      expect(metadata.sourceType, SourceType.richText);
      expect(metadata.originalExtension, 'delta');
      expect(metadata.originalFileName, isNull);
    });

    test('应正确构造含可选字段的实例', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );

      expect(metadata.sourceType, SourceType.rawFile);
      expect(metadata.originalExtension, 'pdf');
      expect(metadata.originalFileName, 'report.pdf');
    });

    test('richText 模式下 originalFileName 应为 null', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      expect(metadata.originalFileName, isNull);
    });
  });

  group('PayloadMetadata.toJson / fromJson 往返', () {
    test('富文本模式序列化循环应还原所有字段', () {
      const original = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final json = original.toJson();
      final restored = PayloadMetadata.fromJson(json);

      expect(restored.sourceType, original.sourceType);
      expect(restored.originalExtension, original.originalExtension);
      expect(restored.originalFileName, original.originalFileName);
    });

    test('文件模式序列化循环应还原所有字段（含 originalFileName）', () {
      const original = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );

      final json = original.toJson();
      final restored = PayloadMetadata.fromJson(json);

      expect(restored.sourceType, original.sourceType);
      expect(restored.originalExtension, original.originalExtension);
      expect(restored.originalFileName, original.originalFileName);
    });

    test('toJson 应使用正确的 snake_case 键名', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'mp4',
        originalFileName: 'video.mp4',
      );

      final json = metadata.toJson();

      expect(json.containsKey('source_type'), true);
      expect(json.containsKey('original_extension'), true);
      expect(json.containsKey('original_file_name'), true);
      expect(json['source_type'], 'raw_file');
      expect(json['original_extension'], 'mp4');
      expect(json['original_file_name'], 'video.mp4');
    });

    test('originalFileName 为 null 时 toJson 不应包含 original_file_name 键', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final json = metadata.toJson();

      expect(json.containsKey('original_file_name'), false);
    });

    test('sourceType 字段应序列化为字符串值', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'txt',
      );

      final json = metadata.toJson();

      expect(json['source_type'], 'raw_file');
    });
  });

  group('PayloadMetadata.toBytes / fromBytes 往返', () {
    test('富文本模式字节序列化循环应还原所有字段', () {
      const original = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final bytes = original.toBytes();
      final restored = PayloadMetadata.fromBytes(bytes);

      expect(restored.sourceType, original.sourceType);
      expect(restored.originalExtension, original.originalExtension);
      expect(restored.originalFileName, original.originalFileName);
    });

    test('文件模式字节序列化循环应还原所有字段', () {
      const original = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'md',
        originalFileName: 'notes.md',
      );

      final bytes = original.toBytes();
      final restored = PayloadMetadata.fromBytes(bytes);

      expect(restored.sourceType, original.sourceType);
      expect(restored.originalExtension, original.originalExtension);
      expect(restored.originalFileName, original.originalFileName);
    });

    test('toBytes 返回的应为有效的 UTF-8 JSON 字节', () {
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: '测试文档.pdf',
      );

      final bytes = metadata.toBytes();

      // 验证可以通过 UTF-8 解码并重新解析为 JSON
      final decoded = utf8.decode(bytes);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      expect(json['original_file_name'], '测试文档.pdf');
    });
  });

  group('PayloadMetadata 相等性', () {
    test('两个字段完全相同的实例应相等', () {
      const metadata1 = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );
      const metadata2 = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );

      expect(metadata1, equals(metadata2));
      expect(metadata1.hashCode, equals(metadata2.hashCode));
    });

    test('originalFileName 不同时不应相等', () {
      const metadata1 = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );
      const metadata2 = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'other.pdf',
      );

      expect(metadata1, isNot(equals(metadata2)));
    });

    test('sourceType 不同时不应相等', () {
      const metadata1 = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );
      const metadata2 = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'delta',
      );

      expect(metadata1, isNot(equals(metadata2)));
    });
  });
}
