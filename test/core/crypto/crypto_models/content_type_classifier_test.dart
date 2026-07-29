import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models/content_type_classifier.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';

void main() {
  group('ContentTypeClassifier.classify - richText 模式', () {
    test('richText sourceType 应始终返回 ContentType.richText', () {
      // 无论 originalExtension 是什么，richText 模式应始终返回 richText
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        ),
        ContentType.richText,
      );
    });

    test('richText 模式下忽略文件后缀', () {
      // 即使扩展名是 pdf、mp4 等，richText 模式仍返回 richText
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.richText,
          originalExtension: 'pdf',
        ),
        ContentType.richText,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.richText,
          originalExtension: 'mp4',
        ),
        ContentType.richText,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + markdown', () {
    test('rawFile + "md" 后缀应返回 ContentType.markdown', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'md',
        ),
        ContentType.markdown,
      );
    });

    test('rawFile + "MD" 大写后缀应返回 ContentType.markdown', () {
      // 分类器应忽略大小写
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'MD',
        ),
        ContentType.markdown,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + text', () {
    test('rawFile + "txt" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'txt',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "json" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'json',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "py" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'py',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "dart" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'dart',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "xml" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'xml',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "csv" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'csv',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "yaml" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'yaml',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "sh" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'sh',
        ),
        ContentType.text,
      );
    });

    test('rawFile + "sql" 后缀应返回 ContentType.text', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'sql',
        ),
        ContentType.text,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + image', () {
    test('rawFile + "jpg" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'jpg',
        ),
        ContentType.image,
      );
    });

    test('rawFile + "jpeg" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'jpeg',
        ),
        ContentType.image,
      );
    });

    test('rawFile + "png" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'png',
        ),
        ContentType.image,
      );
    });

    test('rawFile + "gif" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'gif',
        ),
        ContentType.image,
      );
    });

    test('rawFile + "bmp" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'bmp',
        ),
        ContentType.image,
      );
    });

    test('rawFile + "webp" 后缀应返回 ContentType.image', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'webp',
        ),
        ContentType.image,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + audio', () {
    test('rawFile + "mp3" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'mp3',
        ),
        ContentType.audio,
      );
    });

    test('rawFile + "wav" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'wav',
        ),
        ContentType.audio,
      );
    });

    test('rawFile + "ogg" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'ogg',
        ),
        ContentType.audio,
      );
    });

    test('rawFile + "aac" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'aac',
        ),
        ContentType.audio,
      );
    });

    test('rawFile + "flac" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'flac',
        ),
        ContentType.audio,
      );
    });

    test('rawFile + "m4a" 后缀应返回 ContentType.audio', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'm4a',
        ),
        ContentType.audio,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + video', () {
    test('rawFile + "mp4" 后缀应返回 ContentType.video', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'mp4',
        ),
        ContentType.video,
      );
    });

    test('rawFile + "mkv" 后缀应返回 ContentType.video', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'mkv',
        ),
        ContentType.video,
      );
    });

    test('rawFile + "mov" 后缀应返回 ContentType.video', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'mov',
        ),
        ContentType.video,
      );
    });

    test('rawFile + "avi" 后缀应返回 ContentType.video', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'avi',
        ),
        ContentType.video,
      );
    });

    test('rawFile + "webm" 后缀应返回 ContentType.video', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'webm',
        ),
        ContentType.video,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + pdf', () {
    test('rawFile + "pdf" 后缀应返回 ContentType.pdf', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'pdf',
        ),
        ContentType.pdf,
      );
    });
  });

  group('ContentTypeClassifier.classify - rawFile + other', () {
    test('rawFile + "zip" 后缀应返回 ContentType.other', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'zip',
        ),
        ContentType.other,
      );
    });

    test('rawFile + "rar" 后缀应返回 ContentType.other', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'rar',
        ),
        ContentType.other,
      );
    });

    test('rawFile + "docx" 后缀应返回 ContentType.other', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'docx',
        ),
        ContentType.other,
      );
    });

    test('rawFile + 未知后缀应返回 ContentType.other', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'xyz_unknown',
        ),
        ContentType.other,
      );
    });
  });

  group('ContentTypeClassifier.classify - 大小写不敏感', () {
    test('大写后缀应正确分类', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'JPG',
        ),
        ContentType.image,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'MP3',
        ),
        ContentType.audio,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'MP4',
        ),
        ContentType.video,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'PDF',
        ),
        ContentType.pdf,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'TXT',
        ),
        ContentType.text,
      );
    });

    test('混合大小写后缀应正确分类', () {
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'Jpeg',
        ),
        ContentType.image,
      );
      expect(
        ContentTypeClassifier.classify(
          sourceType: SourceType.rawFile,
          originalExtension: 'Json',
        ),
        ContentType.text,
      );
    });
  });

  group('ContentTypeClassifier.needsTempFile', () {
    test('richText 不需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.richText), false);
    });

    test('text 不需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.text), false);
    });

    test('markdown 不需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.markdown), false);
    });

    test('image 不需要临时文件（小图片场景）', () {
      // 注意：大图片需要临时文件，但此方法不判断大小
      expect(ContentTypeClassifier.needsTempFile(ContentType.image), false);
    });

    test('audio 需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.audio), true);
    });

    test('video 需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.video), true);
    });

    test('pdf 需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.pdf), true);
    });

    test('other 需要临时文件', () {
      expect(ContentTypeClassifier.needsTempFile(ContentType.other), true);
    });
  });
}
