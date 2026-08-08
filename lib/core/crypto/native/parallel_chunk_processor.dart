import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';

/// 并发分块处理器
///
/// 通过滑动窗口并发派发 [compute] 调用，利用多核 CPU 同时加密/解密多个分块。
/// 并发度根据 [Platform.numberOfProcessors] 自适应，避免过度并发导致内存压力。
///
/// 设计要点：
/// - 滑动窗口：维护 `concurrency` 个 in-flight Future，每完成一个立即派发下一个
/// - 顺序保证：结果按原始 chunkIndex 顺序填入预分配数组
/// - 取消传播：[CancellationToken] 触发时停止派发新任务，等待在途任务完成后抛出
/// - 内存控制：在途任务数固定为 `concurrency`，每块 1MB → 最多 `concurrency` MB 内存增量
class ParallelChunkProcessor {
  /// 创建并发分块处理器
  ///
  /// [concurrency] 可显式指定并发度，默认按 CPU 核心数自适应：
  /// - 2 核以下：2（保证基本并发）
  /// - 3-8 核：核数 - 1（留 1 核给主 isolate / UI）
  /// - 8 核以上：8（避免过度并发导致内存压力）
  ParallelChunkProcessor({int? concurrency})
      : concurrency = concurrency ?? _defaultConcurrency();

  /// 并发度
  final int concurrency;

  static int _defaultConcurrency() {
    final cores = Platform.numberOfProcessors;
    if (cores <= 2) return 2;
    if (cores <= 8) return cores - 1;
    return 8;
  }

  /// 并发加密多个分块
  ///
  /// [plaintextChunks] 已切分好的明文分块列表（不含第一块，第一块由调用方单独处理）
  /// [startIndex] 第一个分块对应的 chunkIndex（用于 AAD 绑定）
  /// [totalChunks] 总分块数（用于 AAD 绑定）
  /// [key] 32 字节加密密钥
  /// [useV21Security] 是否使用 v2.1 AAD
  /// [onProgress] 进度回调，参数为已完成数量（含第一块）和总数
  /// [cancellationToken] 取消令牌
  ///
  /// 返回：与 [plaintextChunks] 等长的加密结果列表，顺序与输入一致
  Future<List<NativeChunkEncryptResult>> encryptChunks({
    required List<Uint8List> plaintextChunks,
    required int startIndex,
    required int totalChunks,
    required Uint8List key,
    required bool useV21Security,
    void Function(int completed, int total)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (plaintextChunks.isEmpty) return [];

    final results = List<NativeChunkEncryptResult?>.filled(
      plaintextChunks.length,
      null,
    );
    var completed = 0;

    await _runSlidingWindow(
      total: plaintextChunks.length,
      taskBuilder: (i) => compute(
        nativeEncryptChunkInIsolate,
        NativeChunkEncryptParams(
          plaintext: plaintextChunks[i],
          key: key,
          chunkIndex: startIndex + i,
          totalChunks: totalChunks,
          useV21Security: useV21Security,
        ),
      ),
      onResult: (i, result) {
        results[i] = result as NativeChunkEncryptResult;
        completed++;
        onProgress?.call(completed, totalChunks);
      },
      cancellationToken: cancellationToken,
    );

    return results.cast<NativeChunkEncryptResult>();
  }

  /// 并发解密多个分块
  ///
  /// [ciphertextList] 密文分块列表（不含第一块）
  /// [ivList] 对应的 IV 列表
  /// [startIndex] 第一个分块对应的 chunkIndex
  /// [totalChunks] 总分块数
  /// [key] 32 字节加密密钥
  /// [useV21Security] 是否使用 v2.1 AAD
  /// [onProgress] 进度回调
  /// [cancellationToken] 取消令牌
  ///
  /// 返回：与 [ciphertextList] 等长的明文分块列表，顺序与输入一致
  Future<List<Uint8List>> decryptChunks({
    required List<Uint8List> ciphertextList,
    required List<Uint8List> ivList,
    required int startIndex,
    required int totalChunks,
    required Uint8List key,
    required bool useV21Security,
    void Function(int completed, int total)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    assert(
      ciphertextList.length == ivList.length,
      '密文列表与 IV 列表长度不一致',
    );
    if (ciphertextList.isEmpty) return [];

    final results = List<Uint8List?>.filled(ciphertextList.length, null);
    var completed = 0;

    await _runSlidingWindow(
      total: ciphertextList.length,
      taskBuilder: (i) => compute(
        nativeDecryptChunkInIsolate,
        NativeChunkDecryptParams(
          ciphertext: ciphertextList[i],
          key: key,
          iv: ivList[i],
          chunkIndex: startIndex + i,
          totalChunks: totalChunks,
          useV21Security: useV21Security,
        ),
      ),
      onResult: (i, result) {
        results[i] = result as Uint8List;
        completed++;
        onProgress?.call(completed, totalChunks);
      },
      cancellationToken: cancellationToken,
    );

    return results.cast<Uint8List>();
  }

  /// 滑动窗口并发执行核心逻辑
  ///
  /// 维护 [concurrency] 个 in-flight Future，每完成一个立即派发下一个。
  /// 取消时停止派发新任务，等待在途任务完成后抛出 [OperationCancelledException]。
  Future<void> _runSlidingWindow({
    required int total,
    required Future<dynamic> Function(int index) taskBuilder,
    required void Function(int index, dynamic result) onResult,
    CancellationToken? cancellationToken,
  }) async {
    if (total == 0) return;

    var nextDispatch = 0; // 下一个待派发的 index
    var completedCount = 0;
    Object? firstError;
    OperationCancelledException? cancellation;

    // 在途任务表：index -> Future
    final inFlight = <int, Future<void>>{};

    while (completedCount < total) {
      // 派发新任务直到填满窗口或处理完毕
      while (inFlight.length < concurrency &&
          nextDispatch < total &&
          cancellation == null &&
          firstError == null) {
        final index = nextDispatch++;
        inFlight[index] = taskBuilder(index).then((result) {
          onResult(index, result);
        }).catchError((Object error) {
          // 记录第一个错误，停止派发新任务
          if (firstError == null) {
            if (error is OperationCancelledException) {
              cancellation = error;
            } else {
              firstError = error;
            }
          }
        }).whenComplete(() {
          inFlight.remove(index);
          completedCount++;
        });
      }

      // 无在途任务时退出循环
      if (inFlight.isEmpty) break;

      // 等待任一在途任务完成
      await Future.any(inFlight.values);

      // 检查取消（同步检查，保证响应性）
      if (cancellationToken != null) {
        try {
          cancellationToken.throwIfCancelled();
        } on OperationCancelledException catch (e) {
          cancellation = e;
          // 停止派发新任务，等待在途完成
        }
      }
    }

    // 等待所有在途任务完成（确保资源清理）
    while (inFlight.isNotEmpty) {
      await Future.any(inFlight.values);
    }

    // 抛出优先级：取消 > 其他错误
    if (cancellation != null) {
      throw cancellation!;
    }
    if (firstError != null) {
      final err = firstError!;
      if (err is Exception) {
        throw err;
      }
      throw Exception(err);
    }
  }
}
