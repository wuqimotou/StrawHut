import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';

class ImageService {
  ImageService._();

  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int jpegQuality = 85;
  static const int maxSingleImageSizeBytes = 2 * 1024 * 1024;
  static const int maxTotalContentSizeBytes = 10 * 1024 * 1024;

  /// Compress and encode image to base64 data URL.
  ///
  /// For static images (JPG, PNG, BMP, etc.): resize and compress to JPEG.
  /// For GIFs: read original bytes and encode as data URL without re-encoding,
  ///   preserving the animation frames.
  static Future<String> compressAndEncodeImage(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Check if file is GIF - preserve animation by not re-encoding
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.gif')) {
      if (bytes.length > maxSingleImageSizeBytes) {
        throw Exception('GIF 文件过大（超过 2MB），请使用更小的文件');
      }
      final base64Str = base64Encode(bytes);
      return 'data:image/gif;base64,$base64Str';
    }

    // Static image: decode, resize, and compress to JPEG
    final image = decodeImage(bytes);

    if (image == null) {
      throw Exception('图片解码失败');
    }

    final resized = _resizeIfNeeded(image);

    final compressed = encodeJpg(resized, quality: jpegQuality);
    final base64Str = base64Encode(compressed);
    return 'data:image/jpeg;base64,$base64Str';
  }

  static Image _resizeIfNeeded(Image image) {
    if (image.width <= maxImageWidth && image.height <= maxImageHeight) {
      return image;
    }

    final ratio = (image.width / maxImageWidth)
        .clamp(1.0, double.infinity)
        .compareTo(image.height / maxImageHeight);
    final scale = ratio >= 0
        ? image.width / maxImageWidth
        : image.height / maxImageHeight;

    final newWidth = (image.width / scale).round();
    final newHeight = (image.height / scale).round();

    return copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: Interpolation.average,
    );
  }

  static bool isImageSizeExceeded(int base64Length) {
    final approximateBytes = (base64Length * 3) ~/ 4;
    return approximateBytes > maxSingleImageSizeBytes;
  }

  static bool isTotalContentExceeded(String deltaJson) {
    return deltaJson.length > maxTotalContentSizeBytes;
  }
}
