class QueryOptions<T> {
  final String queryKey;
  final Future<T> Function() queryFn;
  final Duration staleTime;
  final bool enabled;
  final bool refetchOnReconnect;

  /// Retry behavior
  final int retry;
  final Duration Function(int attempt, Object error)? retryDelay;
  final bool? retryOnMount;
  // gc
  final Duration? gcTime;

  final void Function(T data)? onSuccess;
  final void Function(Object error)? onError;

  const QueryOptions({
    required this.queryKey,
    required this.queryFn,
    this.staleTime = Duration.zero,
    this.enabled = true,
    this.refetchOnReconnect = true,

    /// Retry behavior
    this.retry = 1,
    this.retryDelay,
    this.retryOnMount,
    this.gcTime,

    this.onSuccess,
    this.onError,
  });
}
