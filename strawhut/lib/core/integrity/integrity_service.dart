/// 完整性校验服务接口
abstract class IIntegrityService {
  String computeHash(String content);
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  });
}

/// 完整性服务实现（Phase 0 占位实现）
class IntegrityService implements IIntegrityService {
  @override
  String computeHash(String content) {
    // TODO: 实现真实的哈希计算
    throw UnimplementedError('IntegrityService.computeHash 尚未实现');
  }

  @override
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  }) {
    // TODO: 实现真实的完整性校验
    throw UnimplementedError('IntegrityService.verifyIntegrity 尚未实现');
  }
}
