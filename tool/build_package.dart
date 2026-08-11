// ==============================================================================
// StrawHut 构建打包脚本
//
// 用法 (通过 flutter pub run 执行，绕过 PowerShell 执行策略):
//   flutter pub run tool/build_package.dart                          # 构建并打包全平台
//   flutter pub run tool/build_package.dart --platform windows        # 仅 Windows
//   flutter pub run tool/build_package.dart --platform android        # 仅 Android
//   flutter pub run tool/build_package.dart --skip-build              # 跳过构建，仅打包
//
// 打包规则:
//   Windows  : release 文件夹 → StrawHut_{版本号}_x64 → 压缩 zip → 剪切到桌面
//   Android  : 每个架构 apk → StrawHut_{版本号}_{架构}.apk → 剪切到桌面
// ==============================================================================

import 'dart:io';

/// 解析命令行参数
({String platform, bool skipBuild}) _parseArgs(List<String> args) {
  var platform = 'all';
  var skipBuild = false;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--platform' && i + 1 < args.length) {
      platform = args[i + 1];
      i++;
    } else if (args[i] == '--skip-build') {
      skipBuild = true;
    }
  }

  return (platform: platform, skipBuild: skipBuild);
}

/// 从 pubspec.yaml 读取版本号 (1.3.0+7 → 1.3.0)
String _readVersion() {
  final pubspec = File('pubspec.yaml');
  final content = pubspec.readAsStringSync();
  final match = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
  if (match == null) {
    stderr.writeln('[错误] 无法从 pubspec.yaml 解析版本号');
    exit(1);
  }
  return match.group(1)!;
}

/// 获取桌面路径
String _getDesktopPath() {
  // 通过 PowerShell -Command 获取桌面路径 (不受执行策略限制)
  final result = Process.runSync(
    'powershell',
    ['-Command', '[Environment]::GetFolderPath("Desktop")'],
  );
  var path = (result.stdout as String).trim();
  if (path.isEmpty) {
    path = '${Platform.environment['USERPROFILE']}\\Desktop';
  }
  return path;
}

/// 实时转发输出执行命令 (异步)
Future<int> _runCommand(String executable, List<String> arguments) async {
  stdout.writeln('\n>>> $executable ${arguments.join(' ')}\n');

  // Windows 上 flutter/dart 是 .bat 文件，需要通过 shell 执行
  final process = await Process.start(
    executable,
    arguments,
    runInShell: true,
  );
  process.stdout.transform(const SystemEncoding().decoder).listen(stdout.write);
  process.stderr.transform(const SystemEncoding().decoder).listen(stderr.write);
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    stderr.writeln('[错误] 命令失败 (exit code: $exitCode): $executable');
  }
  return exitCode;
}

/// 构建并打包 Windows
Future<void> _buildAndPackageWindows(
  String version,
  String desktop,
  bool skipBuild,
) async {
  if (!skipBuild) {
    stdout.writeln('\n========== 构建 Windows ==========');
    final exitCode =
        await _runCommand('flutter', ['build', 'windows', '--release']);
    if (exitCode != 0) {
      stderr.writeln('[错误] flutter build windows 失败');
      exit(1);
    }
  }

  stdout.writeln('\n========== 打包 Windows ==========');
  const releaseDir = r'build\windows\x64\runner\Release';
  final releaseDirectory = Directory(releaseDir);
  if (!releaseDirectory.existsSync()) {
    stderr.writeln('[错误] 未找到 Windows Release 目录: $releaseDir');
    exit(1);
  }

  final folderName = 'StrawHut_${version}_x64';
  final zipPath = '$desktop\\$folderName.zip';

  // 复制 Release 到带版本号的文件夹
  final tempDir = Directory(folderName);
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  stdout.writeln('复制 Release → $folderName ...');
  _copyDirectory(releaseDirectory, tempDir);

  // 调用 PowerShell Compress-Archive 压缩 (从 Dart 进程内部启动，不受执行策略限制)
  final zipFile = File(zipPath);
  if (zipFile.existsSync()) {
    zipFile.deleteSync();
  }
  stdout.writeln('压缩 → $zipPath ...');
  final compressResult = Process.runSync(
    'powershell',
    [
      '-Command',
      "Compress-Archive -Path '$folderName' -DestinationPath '$zipPath' -Force",
    ],
  );
  if (compressResult.exitCode != 0) {
    stderr.writeln('[错误] 压缩失败: ${compressResult.stderr}');
    exit(1);
  }

  // 清理临时文件夹
  tempDir.deleteSync(recursive: true);

  stdout.writeln('Windows 包已生成: $zipPath');
}

/// 构建并打包 Android
Future<void> _buildAndPackageAndroid(
  String version,
  String desktop,
  bool skipBuild,
) async {
  if (!skipBuild) {
    stdout.writeln('\n========== 构建 Android (所有架构) ==========');
    final exitCode = await _runCommand(
      'flutter',
      ['build', 'apk', '--split-per-abi', '--release'],
    );
    if (exitCode != 0) {
      stderr.writeln('[错误] flutter build apk 失败');
      exit(1);
    }
  }

  stdout.writeln('\n========== 打包 Android ==========');
  const apkDir = r'build\app\outputs\flutter-apk';
  final apkDirectory = Directory(apkDir);
  if (!apkDirectory.existsSync()) {
    stderr.writeln('[错误] 未找到 APK 输出目录: $apkDir');
    exit(1);
  }

  final apkPattern = RegExp(r'app-(.+)-release\.apk$');
  var found = 0;

  for (final entity in apkDirectory.listSync()) {
    if (entity is! File) continue;
    final match = apkPattern.firstMatch(entity.uri.pathSegments.last);
    if (match == null) continue;

    final arch = match.group(1)!;
    final newName = 'StrawHut_${version}_$arch.apk';
    final destPath = '$desktop\\$newName';

    // 剪切到桌面 (覆盖已有同名文件)
    final destFile = File(destPath);
    if (destFile.existsSync()) {
      destFile.deleteSync();
    }
    entity.renameSync(destPath);

    stdout.writeln('已移动: $newName');
    found++;
  }

  if (found == 0) {
    stderr.writeln('[错误] 未找到任何 APK 文件');
    exit(1);
  }
}

/// 递归复制目录
void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final newPath = '${destination.path}\\${entity.path.split(r'\').last}';
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(newPath));
    }
  }
}

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln('版本号解析中...');
  final version = _readVersion();
  stdout.writeln('版本号: $version');

  final desktop = _getDesktopPath();
  stdout.writeln('桌面路径: $desktop');

  final doWindows = config.platform == 'all' || config.platform == 'windows';
  final doAndroid = config.platform == 'all' || config.platform == 'android';

  if (!doWindows && !doAndroid) {
    stderr.writeln(
      '[错误] 无效的 platform: ${config.platform} (可选: all, windows, android)',
    );
    exit(1);
  }

  // 清理构建缓存
  if (!config.skipBuild) {
    stdout.writeln('\n========== 清理构建缓存 ==========');
    final exitCode = await _runCommand('flutter', ['clean']);
    if (exitCode != 0) {
      stderr.writeln('[警告] flutter clean 失败，继续执行...');
    }
  }

  if (doWindows) {
    await _buildAndPackageWindows(version, desktop, config.skipBuild);
  }

  if (doAndroid) {
    await _buildAndPackageAndroid(version, desktop, config.skipBuild);
  }

  stdout.writeln('\n========== 构建打包完成 ==========');
}
