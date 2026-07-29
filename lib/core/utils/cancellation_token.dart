/// Cooperative cancellation token for long-running operations.
///
/// Work already running in a background isolate is allowed to finish its
/// current chunk. The next checkpoint then throws
/// [OperationCancelledException].
class CancellationToken {
  bool _isCancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation. Repeated calls are harmless.
  void cancel() {
    _isCancelled = true;
  }

  /// Throws when cancellation has been requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const OperationCancelledException();
    }
  }
}

/// An intentional user cancellation, not an operation failure.
class OperationCancelledException implements Exception {
  const OperationCancelledException();

  @override
  String toString() => 'Operation cancelled';
}
