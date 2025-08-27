import 'package:get_query/get_query.dart';
import 'package:get_query/src/query_core/query_function_context.dart';

class InfiniteQueryOptions<TQueryFnData, TPageParam> {
  final String queryKey;

  /// Core infinite query fetcher
  final Future<TQueryFnData> Function(QueryFunctionContext<TPageParam>) queryFn;

  /// Default first page param
  final TPageParam initialPageParam;

  /// Controls next-page fetching
  final TPageParam? Function(
    TQueryFnData lastPage,
    List<TQueryFnData> allPages,
    TPageParam lastPageParam,
    List<TPageParam> allPageParams,
  )
  getNextPageParam;

  /// Optional: Controls previous-page fetching
  final TPageParam? Function(
    TQueryFnData firstPage,
    List<TQueryFnData> allPages,
    TPageParam firstPageParam,
    List<TPageParam> allPageParams,
  )?
  getPreviousPageParam;

  /// Optional limits
  final int? maxPages;


  /// ✅ Shared config with regular query options
  final Duration staleTime;
  final bool enabled;
  final bool refetchOnReconnect;
  final int retry;
  final Duration Function(int attempt, Object error)? retryDelay;
  final bool? retryOnMount;
  final Duration? gcTime;

  /// ✅ Lifecycle callbacks (just like QueryOptions)
  final void Function(List<TQueryFnData>? data)? onSuccess;
  final void Function(Object error)? onError;
  final void Function(List<TQueryFnData>? data, Object? error)? onSettled;


  const InfiniteQueryOptions({
    required this.queryKey,
    required this.queryFn,
    required this.initialPageParam,
    required this.getNextPageParam,
    this.getPreviousPageParam,
    this.maxPages,
    this.staleTime = Duration.zero,
    this.enabled = true,
    this.refetchOnReconnect = true,
    this.retry = 3,
    this.retryDelay,
    this.retryOnMount,
    this.gcTime,

    this.onSuccess,
    this.onError,
    this.onSettled,
  });
}
