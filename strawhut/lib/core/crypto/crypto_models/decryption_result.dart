/// 解密结果模型
class DecryptionResult {
  final String deltaJson;
  final bool integrityValid;

  const DecryptionResult({
    required this.deltaJson,
    required this.integrityValid,
  });
}
