import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
part 'card_provider.g.dart';

@Riverpod(keepAlive: false)
class CurrentCard extends _$CurrentCard {
  @override
  AsyncValue<StrawFile?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadFile(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final file = await ref.read(fileIOServiceProvider).readStrawFile(filePath);
      state = AsyncValue.data(file);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
