import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Platform channel wrapper for Android MediaStore-based file saving.
///
/// Uses [MediaStore](https://developer.android.com/training/data-storage/shared/media)
/// to save files to the proper system folders:
/// - `.straw` / `.key` → System Downloads folder
/// - `.png` → System Pictures folder
class AndroidFileSaver {
  static const _channel = MethodChannel('com.strawhut.strawhut/file_saver');

  /// Save a file to the system Downloads folder using MediaStore.
  ///
  /// Returns the content URI of the saved file, or null if save failed.
  /// Only works on Android; returns null on other platforms.
  static Future<String?> saveToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('AndroidFileSaver: saveToDownloads failed: ${e.message}');
      return null;
    }
  }

  /// Save a PNG image to the system Pictures folder using MediaStore.
  ///
  /// Returns the content URI of the saved image, or null if save failed.
  /// Only works on Android; returns null on other platforms.
  static Future<String?> saveToPictures({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('saveToPictures', {
        'fileName': fileName,
        'bytes': bytes,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('AndroidFileSaver: saveToPictures failed: ${e.message}');
      return null;
    }
  }
}
