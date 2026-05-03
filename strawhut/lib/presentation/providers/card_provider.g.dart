// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentCardHash() => r'cfdb4695bdcd39c15ada71b020f4d26d9d41100f';

/// 当前加载的知识卡片 Provider
///
/// 使用 Riverpod 的 @Riverpod 注解定义，用于管理 ReaderScreen 中
/// 当前正在查看的知识卡片文件状态。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：AsyncValue<StrawFile?>（异步数据流，支持 loading/success/error 状态）
/// keepAlive: false（页面销毁后自动清空，不保留缓存）
///
/// 使用场景：
/// - HomeScreen 用户选择 .straw 文件后调用 loadFile
/// - ReaderScreen 读取当前卡片数据展示元数据和内容
///
/// 使用示例：
/// ```dart
/// // 加载文件
/// await ref.read(currentCardProvider.notifier).loadFile(filePath);
/// // 读取状态
/// final cardAsync = ref.watch(currentCardProvider);
/// cardAsync.when(
///   data: (strawFile) => showMeta(strawFile),
///   loading: () => showLoading(),
///   error: (e, st) => showError(e),
/// );
/// ```
///
/// Copied from [CurrentCard].
@ProviderFor(CurrentCard)
final currentCardProvider =
    AutoDisposeNotifierProvider<CurrentCard, AsyncValue<StrawFile?>>.internal(
  CurrentCard.new,
  name: r'currentCardProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentCardHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentCard = AutoDisposeNotifier<AsyncValue<StrawFile?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
