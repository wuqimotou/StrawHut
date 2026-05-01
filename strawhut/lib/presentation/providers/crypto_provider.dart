import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/draft/draft_manager.dart';
part 'crypto_provider.g.dart';

@riverpod
CryptoService cryptoService(CryptoServiceRef ref) {
  return CryptoService();
}

@riverpod
IntegrityService integrityService(IntegrityServiceRef ref) {
  return IntegrityService();
}

@riverpod
FileIOService fileIOService(FileIOServiceRef ref) {
  return FileIOService();
}

@riverpod
DraftManager draftManager(DraftManagerRef ref) {
  return DraftManager();
}
