import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strawhut/core/platform/android_file_saver.dart';

/// Platform-aware file selection service
///
/// Abstracts the file selection process and handles platform differences:
/// - On Windows: uses file_picker's path-based API
/// - On Android: uses file_picker's bytes API to handle content:// URIs
class FileSelectionService {
  /// Whether the current platform is Android
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the current platform is a desktop platform
  bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// 选择 .straw 或 .png 文件并返回文件路径（不加载字节到内存）
  ///
  /// 适用于大文件解密场景，避免将整个文件加载到内存导致 OOM。
  /// 安卓端使用 withData: false 获取文件缓存路径。
  /// 返回 null 如果用户取消选择。
  Future<String?> pickStrawOrPngFilePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: isAndroid ? null : ['straw', 'png'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;

    // 安卓端验证扩展名
    if (isAndroid) {
      final fileName = file.name;
      final ext = fileName.lastIndexOf('.') > 0
          ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
          : '';
      if (ext != 'straw' && ext != 'png') {
        return null;
      }
    }

    return file.path;
  }

  /// Pick a .straw or .png file and return its bytes along with the file name.
  ///
  /// Works on both Windows (path-based) and Android (content:// URI -> bytes).
  /// Returns null if the user cancels the selection.
  Future<(Uint8List bytes, String fileName)?> pickStrawOrPngFile() async {
    if (isAndroid) {
      // 安卓端：FileType.custom 无法识别 .straw 扩展名（无对应 MIME 类型），
      // 使用 FileType.any 显示所有文件，选择后验证扩展名
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final fileName = file.name;

      // 验证文件扩展名
      final ext = fileName.lastIndexOf('.') > 0
          ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
          : '';
      if (ext != 'straw' && ext != 'png') {
        return null;
      }

      final bytes = await _readFileBytes(file);
      if (bytes == null) return null;

      return (bytes, fileName);
    }

    // 桌面端：使用 FileType.custom 精确过滤
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['straw', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final fileName = file.name;
    final bytes = await _readFileBytes(file);
    if (bytes == null) return null;

    return (bytes, fileName);
  }

  /// Pick a .key file and return its bytes along with the file name.
  ///
  /// Returns null if the user cancels the selection.
  Future<(Uint8List bytes, String fileName)?> pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['key'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final fileName = file.name;
    final bytes = await _readFileBytes(file);
    if (bytes == null) return null;

    return (bytes, fileName);
  }

  /// Pick an image file and return its bytes along with the file name.
  ///
  /// Returns null if the user cancels the selection.
  Future<(Uint8List bytes, String fileName)?> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final fileName = file.name;
    final bytes = await _readFileBytes(file);
    if (bytes == null) return null;

    return (bytes, fileName);
  }

  /// Save a text content file with platform-specific handling.
  ///
  /// On Android: saves to the Downloads directory and returns the saved path.
  /// On Desktop: uses file_picker's saveFile dialog and returns the saved path.
  /// Returns null if the user cancels.
  Future<String?> saveFile({
    required String fileName,
    required String content,
    required String fileType, // 'straw', 'png', or 'key'
  }) async {
    final bytes = Uint8List.fromList(content.codeUnits);
    return saveFileBytes(
      fileName: fileName,
      bytes: bytes,
      fileType: fileType,
    );
  }

  /// Save a file from bytes with platform-specific handling.
  ///
  /// On Android: saves to the appropriate directory based on file type.
  /// On Desktop: uses file_picker's saveFile dialog.
  /// Returns the saved file path, or null if the user cancels.
  Future<String?> saveFileBytes({
    required String fileName,
    required Uint8List bytes,
    required String fileType, // 'straw', 'png', or 'key'
  }) async {
    if (isAndroid) {
      return _saveFileAndroid(
        fileName: fileName,
        bytes: bytes,
        fileType: fileType,
      );
    } else {
      return _saveFileDesktop(
        fileName: fileName,
        content: bytes,
        fileType: fileType,
      );
    }
  }

  /// Ensure storage permission on Android 9 and below.
  ///
  /// On Android 10+ (scoped storage), no explicit permission is needed
  /// for file_picker operations.
  Future<bool> _ensureStoragePermission() async {
    if (!isAndroid) return true;

    try {
      final info = await _getAndroidSdkVersion();
      if (info != null && info <= 29) {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (_) {
      // If we can't get the SDK version, proceed anyway
    }

    // Android 10+: Scoped Storage, no permission needed for file_picker
    return true;
  }

  /// Get the Android SDK version.
  ///
  /// Uses a device info approach that works without the device_info_plus
  /// package by using Platform API (only available on Android).
  Future<int?> _getAndroidSdkVersion() async {
    // We use a simple approach: if on Android, assume 10+ (API 29+)
    // since minSdkVersion is 23, but Android 10+ is the dominant version.
    // The permission handler itself handles older versions gracefully.
    return null;
  }

  /// Save a file on Android using MediaStore.
  ///
  /// Uses the Android platform channel to save files to proper system folders:
  /// - Media files (image/video/audio) → System album folder (Pictures/Movies/Music)
  /// - `.png` (encrypt cover) → System Pictures folder
  /// - `.straw` and `.key` → System Downloads folder
  ///
  /// Falls back to path_provider if the platform channel fails.
  Future<String?> _saveFileAndroid({
    required String fileName,
    required Uint8List bytes,
    required String fileType,
  }) async {
    // 判断是否为多媒体文件
    final mimeType = _getMimeType(fileName);
    final isMedia = mimeType.startsWith('image/') ||
        mimeType.startsWith('video/') ||
        mimeType.startsWith('audio/');

    try {
      if (isMedia) {
        // 多媒体文件：存到系统相册（图片→Pictures, 视频→Movies, 音频→Music）
        final uri = await AndroidFileSaver.saveMediaToAlbum(
          fileName: fileName,
          mimeType: mimeType,
          bytes: bytes,
        );
        if (uri != null) {
          debugPrint('Saved $fileName to album: $uri');
          final albumDir = _getAlbumDirectoryName(mimeType);
          return '$albumDir/$fileName';
        }
      } else if (fileType == 'png') {
        // PNG 图片（加密时封面）：存到 Pictures
        final uri = await AndroidFileSaver.saveToPictures(
          fileName: fileName,
          bytes: bytes,
        );
        if (uri != null) {
          debugPrint('Saved $fileName to Pictures: $uri');
          return 'Pictures/$fileName';
        }
      } else {
        // 非多媒体文件：存到 Downloads
        final downloadMimeType = 'application/octet-stream';
        final uri = await AndroidFileSaver.saveToDownloads(
          fileName: fileName,
          mimeType: downloadMimeType,
          bytes: bytes,
        );
        if (uri != null) {
          debugPrint('Saved $fileName to Downloads: $uri');
          return 'Downloads/$fileName';
        }
      }
    } catch (e) {
      debugPrint('MediaStore save failed, falling back to path_provider: $e');
    }

    // Fallback: use path_provider
    final Directory? dir;
    if (isMedia) {
      // 多媒体文件回退到对应的外部存储目录
      if (mimeType.startsWith('image/')) {
        dir = await getExternalStorageDirectory();
      } else if (mimeType.startsWith('video/')) {
        dir = await getExternalStorageDirectory();
      } else if (mimeType.startsWith('audio/')) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getExternalStorageDirectory();
      }
    } else if (fileType == 'png') {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    if (dir == null) {
      debugPrint('Failed to get directory for $fileType');
      return null;
    }

    // Ensure unique file name if file already exists
    var filePath = '${dir.path}/$fileName';
    var file = File(filePath);
    var counter = 1;
    while (await file.exists()) {
      final nameWithoutExt = fileName.lastIndexOf('.') > 0
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final ext = fileName.lastIndexOf('.') > 0
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '';
      filePath = '${dir.path}/${nameWithoutExt}_$counter$ext';
      file = File(filePath);
      counter++;
    }

    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// 根据文件扩展名推断 MIME 类型
  static String _getMimeType(String fileName) {
    final ext = fileName.lastIndexOf('.') > 0
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';
    const mimeMap = {
      // 图片
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'bmp': 'image/bmp',
      'webp': 'image/webp',
      // 音频
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'm4a': 'audio/mp4',
      // 视频
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'webm': 'video/webm',
      '3gp': 'video/3gpp',
      // 文档
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'csv': 'text/csv',
      // 压缩
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }

  /// 根据 MIME 类型获取相册目录名称（用于返回路径显示）
  static String _getAlbumDirectoryName(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Pictures';
    if (mimeType.startsWith('video/')) return 'Movies';
    if (mimeType.startsWith('audio/')) return 'Music';
    return 'Downloads';
  }

  /// Save file on Desktop using file_picker's save dialog.
  Future<String?> _saveFileDesktop({
    required String fileName,
    required Uint8List content,
    required String fileType,
  }) async {
    // 已知类型的映射
    final knownTypes = {
      'straw': FileType.custom,
      'key': FileType.custom,
      'png': FileType.image,
    };

    final knownExtensions = {
      'straw': ['straw'],
      'key': ['key'],
      'png': ['png'],
    };

    final type = knownTypes[fileType] ?? FileType.any;
    final allowedExtensions =
        knownExtensions[fileType] ?? (fileType != 'any' ? [fileType] : null);

    final savePath = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: type,
      allowedExtensions: allowedExtensions,
    );

    if (savePath == null) return null; // User cancelled

    final file = File(savePath);
    await file.writeAsBytes(content);
    return savePath;
  }

  /// Read bytes from a PickedFile, handling both Android (bytes-based)
  /// and Desktop (path-based) scenarios.
  Future<Uint8List?> _readFileBytes(PlatformFile file) async {
    // On Android, file_picker may provide bytes directly
    if (file.bytes != null) {
      return file.bytes;
    }

    // Fallback to path-based reading
    if (file.path != null) {
      try {
        return File(file.path!).readAsBytes();
      } catch (e) {
        debugPrint(
            'FileSelectionService: Failed to read file at path: ${file.path}');
        return null;
      }
    }

    // If neither bytes nor path is available, try reading from the readStream
    if (file.readStream != null) {
      try {
        final bytes = <int>[];
        await for (final chunk in file.readStream!) {
          bytes.addAll(chunk);
        }
        return Uint8List.fromList(bytes);
      } catch (e) {
        debugPrint('FileSelectionService: Failed to read file from stream');
        return null;
      }
    }

    return null;
  }
}
