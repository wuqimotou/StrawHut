/// P2P 服务接口
abstract class IP2PService {
  Future<void> publishToNetwork();
  Future<void> discoverCards();
  Future<void> downloadCard();
  Future<void> getStatus();
  Future<void> shutdown();
}
