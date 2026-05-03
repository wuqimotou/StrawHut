import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:strawhut/core/errors/file_exception.dart';

/// 解密对话框 - 密钥文件上传组件
///
/// 提供 .key 文件上传功能，通过文件选择器读取密钥文件中的 Base64 密钥。
///
/// 架构位置：应用层（Presentation Layer）→ 解密对话框子组件
/// 使用场景：DecryptDialog 中方式 B 解密
///
/// 功能说明：
/// - "上传 .key 文件" 按钮
/// - 使用 file_picker 选择 .key 文件
/// - 解析文件获取 key_base64
/// - 验证 .key 文件格式和完整性
/// - 成功后通过 [onKeyFileLoaded] 回调返回解析到的 Base64 密钥
///
/// 文件处理流程：
/// 1. 用户点击"上传 .key 文件"按钮
/// 2. 弹出文件选择器，仅接受 .key 扩展名
/// 3. 读取文件内容（JSON）
/// 4. 解析 JSON 获取 key_data.key_base64
/// 5. 验证文件格式（检查必填字段和格式）
/// 6. 验证通过 → 通过回调传递密钥
/// 7. 验证失败 → 显示错误提示
class KeyFileUpload extends StatefulWidget {
  /// 创建密钥文件上传组件实例
  ///
  /// 参数：
  /// - [onKeyFileLoaded] - 成功解析 .key 文件后的回调，
  ///   参数为提取到的 Base64 密钥字符串
  const KeyFileUpload({
    super.key,
    required this.onKeyFileLoaded,
  });

  /// 密钥文件加载成功回调
  final void Function(String keyBase64) onKeyFileLoaded;

  @override
  State<KeyFileUpload> createState() => _KeyFileUploadState();
}

class _KeyFileUploadState extends State<KeyFileUpload> {
  /// 是否正在加载文件
  bool _isLoading = false;

  /// 上次加载的文件名（用于显示成功状态）
  String? _loadedFileName;

  /// 错误消息（用于显示在按钮下方）
  String? _errorMessage;

  /// 处理文件上传流程
  ///
  /// 完整流程：
  /// 1. 弹出文件选择器（仅 .key 文件）
  /// 2. 读取文件内容
  /// 3. 解析 JSON
  /// 4. 验证格式和完整性
  /// 5. 提取 key_base64
  /// 6. 回调通知父组件
  Future<void> _handleFileUpload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ========== 步骤 1：弹出文件选择器 ==========
      // 使用 file_picker 选择文件，限制仅 .key 扩展名
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['key'],
        dialogTitle: '选择密钥文件',
        allowMultiple: false,
      );

      // 用户取消了文件选择
      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '无法获取文件路径';
        });
        return;
      }

      final fileName = result.files.single.name;

      // ========== 步骤 2：读取 .key 文件内容 ==========
      final file = File(filePath);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = '文件不存在：$fileName';
        });
        return;
      }

      final fileContent = await file.readAsString();

      // ========== 步骤 3：解析 JSON ==========
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
      } on FormatException {
        setState(() {
          _isLoading = false;
          _errorMessage = '$fileName 不是有效的 JSON 文件，可能已损坏';
        });
        return;
      }

      // ========== 步骤 4：验证 .key 文件格式 ==========
      final validationResult = _validateKeyFormat(jsonData);
      if (!validationResult.isValid) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              '$fileName 格式不正确：\n${validationResult.errors.join('\n')}';
        });
        return;
      }

      // ========== 步骤 5：验证 .key 文件完整性（可选） ==========
      // 如果 .key 文件中包含完整性哈希，进行校验
      final integrityMap = jsonData['integrity'] as Map<String, dynamic>?;
      if (integrityMap != null && integrityMap['hash'] != null) {
        final expectedHash = integrityMap['hash'] as String;
        if (expectedHash.isNotEmpty) {
          final currentHash = _computeHash(fileContent);
          if (currentHash != expectedHash) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  '$fileName 完整性校验失败，文件可能已被篡改，请勿使用';
            });
            return;
          }
        }
      }

      // ========== 步骤 6：提取 key_base64 ==========
      final keyData = jsonData['key_data'] as Map<String, dynamic>;
      final keyBase64 = keyData['key_base64'] as String;

      if (keyBase64.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '$fileName 中的密钥数据为空';
        });
        return;
      }

      // ========== 步骤 7：成功，回调通知父组件 ==========
      setState(() {
        _isLoading = false;
        _loadedFileName = fileName;
        _errorMessage = null;
      });

      widget.onKeyFileLoaded(keyBase64);
    } on FileException catch (e) {
      // 文件操作异常
      setState(() {
        _isLoading = false;
        _errorMessage = '文件读取失败：${e.message}';
      });
    } on Exception catch (e) {
      // 其他已知异常
      setState(() {
        _isLoading = false;
        _errorMessage = '加载密钥文件时发生错误：$e';
      });
    }
  }

  /// 简易 .key 文件格式验证
  ///
  /// 检查 .key 文件 JSON 中的必填字段。
  /// 返回 ValidationResult 对象，包含验证结果和错误列表。
  ValidationResult _validateKeyFormat(Map<String, dynamic> json) {
    final errors = <String>[];

    // 检查 format_version
    if (json['format_version'] == null) {
      errors.add('缺少 format_version 字段');
    }

    // 检查 key_metadata
    final keyMetadata = json['key_metadata'] as Map<String, dynamic>?;
    if (keyMetadata == null) {
      errors.add('缺少 key_metadata 字段');
    } else {
      if (keyMetadata['key_id'] == null) errors.add('缺少 key_id 字段');
      if (keyMetadata['key_algorithm'] == null) {
        errors.add('缺少 key_algorithm 字段');
      }
      if (keyMetadata['key_length_bits'] == null) {
        errors.add('缺少 key_length_bits 字段');
      }
      if (keyMetadata['key_length_bits'] != null &&
          keyMetadata['key_length_bits'] != 256) {
        errors.add('密钥长度必须为 256 位');
      }
    }

    // 检查 key_data
    final keyData = json['key_data'] as Map<String, dynamic>?;
    if (keyData == null) {
      errors.add('缺少 key_data 字段');
    } else {
      if (keyData['key_base64'] == null) {
        errors.add('缺少 key_base64 字段');
      }
      if (keyData['encoding'] == null) {
        errors.add('缺少 encoding 字段');
      } else if (keyData['encoding'] != 'base64') {
        errors.add('编码方式必须为 base64');
      }
    }

    // 检查 integrity
    if (json['integrity'] == null) {
      errors.add('缺少 integrity 字段');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// 简易 SHA-256 哈希计算（与 IntegrityService.computeHash 逻辑一致）
  ///
  /// 返回格式："sha256:{十六进制哈希值}"
  String _computeHash(String content) {
    final digest = sha256.convert(utf8.encode(content));
    return 'sha256:$digest';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提示标签
        const Text(
          '方式 B：上传 .key 密钥文件',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        // 上传按钮区域
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _handleFileUpload,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.upload_file),
                label: Text(_isLoading ? '正在读取...' : '选择 .key 文件'),
              ),
            ),
          ],
        ),

        // 成功状态显示
        if (_loadedFileName != null && _errorMessage == null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已加载密钥文件：$_loadedFileName',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 错误信息显示
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 验证结果
///
/// 封装格式验证的结果，包含是否有效和错误列表。
class ValidationResult {
  /// 创建验证结果实例
  const ValidationResult({required this.isValid, this.errors = const []});

  /// 验证是否通过
  final bool isValid;

  /// 验证错误列表（仅当 isValid 为 false 时有内容）
  final List<String> errors;
}
