import 'package:strawhut/p2p/p2p_interface.dart';

/// P2P 服务的占位实现
///
/// 提供 IP2PService 接口的空实现，用于 Phase 1-5 的编译和测试。
/// 所有方法抛出 UnimplementedError，表示 P2P 功能尚未实现。
///
/// 架构位置：P2P 模块 → 占位实现
/// 使用场景：
/// - Phase 1-5 的依赖注入中使用，避免编译错误
/// - Phase 6 时替换为真实的 P2P 服务实现
///
/// 未来实现方案（Phase 6）：
/// - 使用 libp2p（dart-libp2p）实现 DHT 和消息传递
/// - 或使用 Matrix SDK 实现去中心化通信
/// - 实现卡片发布、发现、下载的完整流程
class P2PStub implements IP2PService {
  /// 发布知识卡片到 P2P 网络（未实现）
  @override
  Future<void> publishToNetwork() async {
    throw UnimplementedError('P2P service not implemented');
  }

  /// 发现网络中的知识卡片（未实现）
  @override
  Future<void> discoverCards() async {
    throw UnimplementedError('P2P service not implemented');
  }

  /// 下载指定知识卡片（未实现）
  @override
  Future<void> downloadCard() async {
    throw UnimplementedError('P2P service not implemented');
  }

  /// 获取 P2P 服务状态（未实现）
  @override
  Future<void> getStatus() async {
    throw UnimplementedError('P2P service not implemented');
  }

  /// 关闭 P2P 连接（未实现）
  @override
  Future<void> shutdown() async {
    throw UnimplementedError('P2P service not implemented');
  }
}
