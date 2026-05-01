import 'package:strawhut/p2p/p2p_interface.dart';

/// P2P 服务的占位实现
class P2PStub implements IP2PService {
  @override
  Future<void> publishToNetwork() async {
    throw UnimplementedError('P2P service not implemented');
  }

  @override
  Future<void> discoverCards() async {
    throw UnimplementedError('P2P service not implemented');
  }

  @override
  Future<void> downloadCard() async {
    throw UnimplementedError('P2P service not implemented');
  }

  @override
  Future<void> getStatus() async {
    throw UnimplementedError('P2P service not implemented');
  }

  @override
  Future<void> shutdown() async {
    throw UnimplementedError('P2P service not implemented');
  }
}
