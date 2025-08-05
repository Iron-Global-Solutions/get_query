typedef GetPreviousPageParamFunction<TPageParam, TQueryFnData> =
    TPageParam? Function(
      TQueryFnData firstPage,
      List<TQueryFnData> allPages,
      TPageParam firstPageParam,
      List<TPageParam> allPageParams,
    );

typedef GetNextPageParamFunction<TPageParam, TQueryFnData> =
    TPageParam? Function(
      TQueryFnData lastPage,
      List<TQueryFnData> allPages,
      TPageParam lastPageParam,
      List<TPageParam> allPageParams,
    );


class InitialPageParam<TPageParam> {
  final TPageParam initialPageParam;

  const InitialPageParam({required this.initialPageParam});
}

class InfiniteQueryPageParamsOptions<TQueryFnData, TPageParam>
    extends InitialPageParam<TPageParam> {
  final GetPreviousPageParamFunction<TPageParam, TQueryFnData>?
  getPreviousPageParam;
  final GetNextPageParamFunction<TPageParam, TQueryFnData> getNextPageParam;
  final Object? queryFn;
  final String? queryHash;
  final String? queryKey;
  final Map<String, dynamic>? meta;
  final int? maxPages;

  const InfiniteQueryPageParamsOptions({
    required super.initialPageParam,
    this.getPreviousPageParam,
    required this.getNextPageParam,
    this.queryFn,
    this.queryHash,
    this.queryKey,
    this.meta,
    this.maxPages,
  });
}
