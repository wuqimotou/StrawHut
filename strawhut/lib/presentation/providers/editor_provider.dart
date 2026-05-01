import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'editor_provider.g.dart';

@Riverpod(keepAlive: false)
class EditorContent extends _$EditorContent {
  @override
  String build() {
    return '';
  }

  void updateContent(String deltaJson) {
    state = deltaJson;
  }

  void loadFromDraft() {
    // 由 draft manager 处理
  }

  void clear() {
    state = '';
  }
}
