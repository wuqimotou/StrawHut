/// 加密内容模型
class EncryptedContent {
  final String encryptedDataBase64;
  final String ivBase64;
  final String algorithm;

  const EncryptedContent({
    required this.encryptedDataBase64,
    required this.ivBase64,
    required this.algorithm,
  });

  Map<String, dynamic> toJson() => {
    'encrypted_data': encryptedDataBase64,
    'encryption_algorithm': algorithm,
    'iv': ivBase64,
  };
}
