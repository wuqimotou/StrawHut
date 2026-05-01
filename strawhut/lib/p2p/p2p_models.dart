/// P2P 卡片发现结果模型
class DiscoveredCard {
  final String cardId;
  final String title;
  final String? description;

  const DiscoveredCard({
    required this.cardId,
    required this.title,
    this.description,
  });
}

/// P2P 服务状态模型
class P2PStatus {
  final bool isConnected;
  final int peerCount;
  final List<DiscoveredCard> discoveredCards;

  const P2PStatus({
    required this.isConnected,
    required this.peerCount,
    required this.discoveredCards,
  });
}
