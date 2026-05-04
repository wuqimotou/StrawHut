import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class CoverImageService {
  CoverImageService._();

  static const String _tEXtKeyword = 'strawhut';

  static final List<int> _crcTable = _makeCrcTable();

  static List<int> _makeCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        if (c & 1 != 0) {
          c = 0xEDB88320 ^ (c >> 1);
        } else {
          c = c >> 1;
        }
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  static List<int> _buildPngChunk(String type, Uint8List data) {
    final typeBytes = utf8.encode(type);
    final lengthBytes = _uint32ToBytes(data.length);
    final crcInput = Uint8List.fromList([...typeBytes, ...data]);
    final crcValue = _crc32(crcInput);
    final crcBytes = _uint32ToBytes(crcValue);
    return [...lengthBytes, ...typeBytes, ...data, ...crcBytes];
  }

  static List<int> _uint32ToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  static int _readUint32(List<int> data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static Future<Uint8List> generateCoverImage({
    required String title,
    required String publisherAlias,
    required String publishDate,
    required List<String> tags,
    String? description,
    bool isAnonymous = false,
    Uint8List? customImageBytes,
  }) async {
    if (customImageBytes != null) {
      final codec = await ui.instantiateImageCodec(customImageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    }

    const width = 800;
    const height = 1200;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    const bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F0C29),
        Color(0xFF302B63),
        Color(0xFF24243E),
      ],
    );
    canvas.drawRect(bgRect, Paint()..shader = bgGradient.createShader(bgRect));

    _drawDecoCircles(canvas, width, height);

    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 40, 720, 1120),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      cardRect,
      Paint()..color = const Color(0x18FFFFFF),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawTextOnCanvas(
      canvas,
      'STRAWHUT',
      80,
      80,
      14,
      const Color(0x88FFFFFF),
      ui.FontWeight.w600,
      letterSpacing: 4,
    );

    canvas.drawRect(
      const Rect.fromLTWH(80, 108, 40, 3),
      Paint()..color = const Color(0xFF7C4DFF),
    );

    _drawEncryptedBadge(canvas, width, height);

    _drawCenteredTextOnCanvas(
      canvas,
      title,
      width.toDouble(),
      220,
      50,
      const Color(0xFFFFFFFF),
      ui.FontWeight.w700,
      maxWidth: width - 160,
      maxLines: 3,
    );

    var tagX = 80.0;
    var tagY = 480.0;
    for (final tag in tags.take(5)) {
      final tagWidth = _estimateTextWidth(tag, 13) + 24;
      if (tagX + tagWidth > width - 80) {
        tagX = 80;
        tagY += 38;
      }
      _drawTagPill(canvas, tag, tagX, tagY, tagWidth, fontSize: 13, height: 32);
      tagX += tagWidth + 10;
    }

    if (description != null && description.isNotEmpty) {
      _drawTextOnCanvas(
        canvas,
        description,
        80,
        tagY + 52,
        22,
        const Color(0x99FFFFFF),
        ui.FontWeight.w400,
        maxWidth: width - 160,
        maxLines: 4,
        lineHeight: 1.6,
      );
    }

    final publisherText = isAnonymous ? 'Anonymous' : publisherAlias;
    _drawCenteredTextOnCanvas(
      canvas,
      '\u4F5C\u8005\uFF1A$publisherText',
      width.toDouble(),
      1080,
      25,
      const Color(0xBBFFFFFF),
      ui.FontWeight.w400,
      maxWidth: width - 160,
    );

    _drawCenteredTextOnCanvas(
      canvas,
      _formatPublishDate(publishDate),
      width.toDouble(),
      1114,
      25,
      const Color(0x88FFFFFF),
      ui.FontWeight.w400,
      maxWidth: width - 160,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static void _drawDecoCircles(Canvas canvas, int width, int height) {
    canvas.drawCircle(
      Offset(width * 0.85, height * 0.12),
      120,
      Paint()..color = const Color(0x0D7C4DFF),
    );
    canvas.drawCircle(
      Offset(width * 0.15, height * 0.85),
      160,
      Paint()..color = const Color(0x0D7C4DFF),
    );
    canvas.drawCircle(
      Offset(width * 0.9, height * 0.75),
      80,
      Paint()..color = const Color(0x08FFFFFF),
    );
  }

  static void _drawEncryptedBadge(Canvas canvas, int width, int height) {
    const badgeY = 170.0;
    const badgeHeight = 36.0;
    const badgePadding = 16.0;

    final badgeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 13,
        fontWeight: ui.FontWeight.w600,
      ),
    )..pushStyle(ui.TextStyle(color: const Color(0xFF69F0AE)));
    badgeBuilder.addText('\u{1F512} \u5DF2\u52A0\u5BC6');
    final badgeParagraph = badgeBuilder.build();
    badgeParagraph.layout(const ui.ParagraphConstraints(width: 200));

    final badgeWidth = badgeParagraph.maxIntrinsicWidth + badgePadding * 2;
    final badgeX = (width - badgeWidth) / 2;

    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      badgeRRect,
      Paint()..color = const Color(0x1A69F0AE),
    );
    canvas.drawRRect(
      badgeRRect,
      Paint()
        ..color = const Color(0x4469F0AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textX = badgeX + badgePadding;
    final textY = badgeY + (badgeHeight - 13) / 2;
    canvas.drawParagraph(badgeParagraph, Offset(textX, textY));
  }

  static String _formatPublishDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
    } on Exception {
      return isoDate;
    }
  }

  static void _drawTextOnCanvas(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color,
    ui.FontWeight fontWeight, {
    double? maxWidth,
    int maxLines = 1,
    double? letterSpacing,
    double? lineHeight,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        maxLines: maxLines,
        ellipsis: '...',
        height: lineHeight,
      ),
    )..pushStyle(ui.TextStyle(
        color: color,
        letterSpacing: letterSpacing,
      ));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth ?? 800));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  static void _drawCenteredTextOnCanvas(
    Canvas canvas,
    String text,
    double canvasWidth,
    double y,
    double fontSize,
    Color color,
    ui.FontWeight fontWeight, {
    double? maxWidth,
    int maxLines = 1,
  }) {
    final constrainedWidth = maxWidth ?? canvasWidth;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        maxLines: maxLines,
        ellipsis: '...',
        textAlign: ui.TextAlign.center,
      ),
    )..pushStyle(ui.TextStyle(color: color));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: constrainedWidth));
    final x = (canvasWidth - constrainedWidth) / 2;
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  static void _drawRightAlignedTextOnCanvas(
    Canvas canvas,
    String text,
    double rightX,
    double y,
    double fontSize,
    Color color,
    ui.FontWeight fontWeight, {
    double? maxWidth,
    int maxLines = 1,
  }) {
    final constrainedWidth = maxWidth ?? 200.0;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        maxLines: maxLines,
        ellipsis: '...',
        textAlign: ui.TextAlign.right,
      ),
    )..pushStyle(ui.TextStyle(color: color));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: constrainedWidth));
    final x = rightX - paragraph.maxIntrinsicWidth;
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  static void _drawTagPill(
    Canvas canvas,
    String tag,
    double x,
    double y,
    double width, {
    double fontSize = 12,
    double height = 28,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0x1A7C4DFF));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x447C4DFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawTextOnCanvas(
      canvas,
      tag,
      x + 12,
      y + (height - fontSize) / 2,
      fontSize,
      const Color(0xDDFFFFFF),
      ui.FontWeight.w400,
    );
  }

  static double _estimateTextWidth(String text, double fontSize) {
    return text.length * fontSize * 0.6;
  }

  static Future<Uint8List> embedStrawData(
    Uint8List pngBytes,
    String strawJson,
  ) async {
    final base64Data = base64Encode(utf8.encode(strawJson));
    final keywordBytes = utf8.encode(_tEXtKeyword);
    final contentBytes = utf8.encode(base64Data);
    final chunkData = Uint8List.fromList([...keywordBytes, 0, ...contentBytes]);
    final tEXtChunkBytes = _buildPngChunk('tEXt', chunkData);

    final ihdrLength = _readUint32(pngBytes, 8);
    final ihdrEnd = 8 + 4 + 4 + ihdrLength + 4;

    final result = BytesBuilder()
      ..add(pngBytes.sublist(0, ihdrEnd))
      ..add(tEXtChunkBytes)
      ..add(pngBytes.sublist(ihdrEnd));

    return result.toBytes();
  }

  static Future<String?> extractStrawData(Uint8List pngBytes) async {
    try {
      return await Isolate.run(() => _extractStrawDataSync(pngBytes));
    } on Exception {
      return null;
    }
  }

  static String? _extractStrawDataSync(Uint8List pngBytes) {
    if (pngBytes.length < 8) return null;

    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < 8; i++) {
      if (pngBytes[i] != pngSignature[i]) return null;
    }

    var offset = 8;
    var iterations = 0;
    const maxIterations = 1000;

    while (offset + 12 <= pngBytes.length && iterations < maxIterations) {
      iterations++;
      final length = _readUint32(pngBytes, offset);
      if (length < 0 || offset + 12 + length > pngBytes.length) break;

      final chunkType =
          String.fromCharCodes(pngBytes.sublist(offset + 4, offset + 8));

      if (chunkType == 'tEXt') {
        final chunkData = pngBytes.sublist(offset + 8, offset + 8 + length);
        final nullIndex = chunkData.indexOf(0);
        if (nullIndex < 0) {
          offset += 4 + 4 + length + 4;
          continue;
        }
        final keyword =
            utf8.decode(chunkData.sublist(0, nullIndex), allowMalformed: true);
        if (keyword == _tEXtKeyword) {
          final contentBytes = chunkData.sublist(nullIndex + 1);
          final base64Str = utf8.decode(contentBytes, allowMalformed: true);
          final jsonBytes = base64Decode(base64Str);
          return utf8.decode(jsonBytes);
        }
      }

      if (chunkType == 'IEND') break;

      offset += 4 + 4 + length + 4;
    }

    return null;
  }

  static Future<bool> isStrawHutPng(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final extension = filePath.split('.').last.toLowerCase();
    if (extension != 'png') return false;

    try {
      final bytes = await file.readAsBytes();
      final data = await extractStrawData(bytes);
      return data != null;
    } on Exception {
      return false;
    }
  }

  static Future<Uint8List> createStrawPng({
    required String strawJson,
    required String title,
    required String publisherAlias,
    required String publishDate,
    required List<String> tags,
    String? description,
    bool isAnonymous = false,
    Uint8List? customImageBytes,
  }) async {
    final coverBytes = await generateCoverImage(
      title: title,
      publisherAlias: publisherAlias,
      publishDate: publishDate,
      tags: tags,
      description: description,
      isAnonymous: isAnonymous,
      customImageBytes: customImageBytes,
    );

    return embedStrawData(coverBytes, strawJson);
  }
}
