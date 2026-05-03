// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$editorContentHash() => r'6379375efc45ca8dfb611981a86b4681037aa44a';

/// 编辑器内容 Provider
///
/// 使用 Riverpod 的 @Riverpod 注解定义，用于管理 EditorScreen 中
/// 当前编辑器的 Delta JSON 内容。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：String（Delta JSON 格式）
/// keepAlive: true（确保无 watcher 时状态不丢失，页面销毁时需手动清理）
///
/// 使用场景：
/// - EditorScreen 监听编辑器内容变化时调用 updateContent
/// - 编辑器恢复草稿时调用 loadFromDraft
/// - 新建空白文档时调用 clear
///
/// 数据流：
/// 1. 用户输入文本 → QuillEditor.onChanged 触发
/// 2. 获取 Delta JSON 字符串
/// 3. 调用 updateContent(deltaJson) 更新 Provider 状态
/// 4. 同时调用 DraftManager.saveToDraft 保存草稿
///
/// 使用示例：
/// ```dart
/// // 更新内容
/// ref.read(editorContentProvider.notifier).updateContent(deltaJson);
/// // 监听内容
/// final content = ref.watch(editorContentProvider);
/// ```
///
/// Copied from [EditorContent].
@ProviderFor(EditorContent)
final editorContentProvider = NotifierProvider<EditorContent, String>.internal(
  EditorContent.new,
  name: r'editorContentProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$editorContentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EditorContent = Notifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
