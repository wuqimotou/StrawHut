import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';

void main() {
  group('SourceType.value', () {
    test('richText 的 value 应为 "rich_text"', () {
      expect(SourceType.richText.value, 'rich_text');
    });

    test('rawFile 的 value 应为 "raw_file"', () {
      expect(SourceType.rawFile.value, 'raw_file');
    });
  });

  group('SourceType.fromValue', () {
    test('fromValue("rich_text") 应返回 SourceType.richText', () {
      expect(SourceType.fromValue('rich_text'), SourceType.richText);
    });

    test('fromValue("raw_file") 应返回 SourceType.rawFile', () {
      expect(SourceType.fromValue('raw_file'), SourceType.rawFile);
    });

    test('fromValue("unknown") 应返回默认值 SourceType.richText', () {
      // 未知值应回退到默认值 richText，确保安全的降级行为
      expect(SourceType.fromValue('unknown'), SourceType.richText);
    });

    test('fromValue("") 应返回默认值 SourceType.richText', () {
      expect(SourceType.fromValue(''), SourceType.richText);
    });

    test('fromValue 大小写不匹配时应返回默认值', () {
      // "RICH_TEXT" 与 "rich_text" 不同，应回退到默认值
      expect(SourceType.fromValue('RICH_TEXT'), SourceType.richText);
    });
  });

  group('SourceType 枚举完整性', () {
    test('应包含且仅包含 richText 和 rawFile 两个值', () {
      expect(SourceType.values.length, 2);
      expect(SourceType.values, contains(SourceType.richText));
      expect(SourceType.values, contains(SourceType.rawFile));
    });
  });
}
