/// P2P 卡片发现结果模型
///
/// 封装从 P2P 网络发现的卡片公开元数据。
/// 对应其他用户发布到网络的卡片摘要信息。
///
/// 架构位置：P2P 模块 → 数据模型
/// 使用场景：discoverCards 返回的卡片列表中的每一项
///
/// 安全说明：
/// - 仅包含公开元数据（标题、描述、发布者）
/// - 不包含加密内容和密钥
/// - 用户感兴趣后才能下载完整加密内容
class DiscoveredCard {
  /// 卡片唯一标识
  ///
  /// 由发布方生成的随机 ID，用于在网络中唯一标识此卡片。
  final String cardId;

  /// 卡片标题
  ///
  /// 公开可见，用于在发现列表中展示。
  final String title;

  /// 卡片描述
  ///
  /// 可选字段，公开可见，帮助用户判断是否感兴趣。
  final String? description;

  /// 创建发现卡片实例
  const DiscoveredCard({
    required this.cardId,
    required this.title,
    this.description,
  });
}

/// P2P 服务状态模型
///
/// 封装 P2P 网络的当前连接和运行状态。
///
/// 架构位置：P2P 模块 → 数据模型
/// 使用场景：getStatus 返回的服务状态信息
class P2PStatus {
  /// 是否已连接到 P2P 网络
  ///
  /// true 表示已成功加入网络，可以发布和发现卡片。
  /// false 表示未连接或连接已断开。
  final bool isConnected;

  /// 已连接的节点（Peer）数量
  ///
  /// 表示当前网络中活跃的其他用户数量。
  final int peerCount;

  /// 已发现的卡片列表
  ///
  /// 网络中所有已发布卡片的公开元数据摘要。
  final List<DiscoveredCard> discoveredCards;

  /// 创建 P2P 状态实例
  const P2PStatus({
    required this.isConnected,
    required this.peerCount,
    required this.discoveredCards,
  });
}
