import 'package:get/get.dart';
import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/enums/query_status.dart';
import 'package:get_query/src/query_core/infinite_data.dart';
import 'package:get_query/src/query_core/infinite_query.dart';
import 'package:get_query/src/query_core/infinite_query_cache.dart';
import 'package:get_query/src/query_core/infinite_query_options.dart';
import 'package:get_query/src/query_core/query_client.dart';

class UseInfiniteQueryResult<TQueryFnData, TPageParam> {
  final Rx<InfiniteData<TQueryFnData, TPageParam>?> data;
  final RxBool isLoading;
  final RxBool isFetching;
  final RxBool isSuccess;
  final RxBool isError;
  final Rx<Object?> error;
  final RxBool hasNextPage;
  final RxBool hasPreviousPage;

  final Future<void> Function() fetchNextPage;
  final Future<void> Function() fetchPreviousPage;

  UseInfiniteQueryResult({
    required this.data,
    required this.isLoading,
    required this.isFetching,
    required this.isSuccess,
    required this.isError,
    required this.error,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
  });
}

final Set<String> _fetchingQueries = {};

UseInfiniteQueryResult<TQueryFnData, TPageParam> useInfiniteQuery<
  TQueryFnData,
  TPageParam,
  T
>({required InfiniteQueryOptions<TQueryFnData, TPageParam> options}) {
  final client = QueryClient.instance;
  final Rx<InfiniteData<TQueryFnData, TPageParam>?> data = Rx(null);
  final RxBool isLoading = false.obs;
  final RxBool isFetching = false.obs;
  final RxBool isSuccess = false.obs;
  final RxBool isError = false.obs;
  final Rx<Object?> error = Rx(null);
  final RxBool hasNextPage = false.obs;
  final RxBool hasPreviousPage = false.obs;

  final cached = client.getInfiniteQueryState<TQueryFnData, T, TPageParam>(
    options.queryKey,
  );

  if (cached != null && !cached.isStale(options.staleTime)) {
    final qData = cached.data;
    if (qData != null) {
      List<TPageParam> pageParams = [];
      try {
        pageParams = qData.pageParams.cast<TPageParam>();
      } catch (_) {}

      data.value = InfiniteData<TQueryFnData, TPageParam>(
        pages: qData.pages,
        pageParams: pageParams,
      );

      isLoading.value = false;
      isFetching.value = false;
      isSuccess.value = cached.status == QueryStatus.success;
      isError.value = cached.status == QueryStatus.error;
      error.value = cached.error;

      if (qData.pages.isNotEmpty) {
        final next = options.getNextPageParam(
          qData.pages.last,
          qData.pages,
          pageParams.last,
          pageParams,
        );

        final prev = options.getPreviousPageParam?.call(
          qData.pages.first,
          qData.pages,
          pageParams.first,
          pageParams,
        );

        hasNextPage.value = next != null;
        hasPreviousPage.value = prev != null;
      }
    }

    return UseInfiniteQueryResult<TQueryFnData, TPageParam>(
      data: data,
      isLoading: isLoading,
      isFetching: isFetching,
      isSuccess: isSuccess,
      isError: isError,
      error: error,
      hasNextPage: hasNextPage,
      hasPreviousPage: hasPreviousPage,
      fetchNextPage: () async {
        final d = data.value;
        if (d == null || _fetchingQueries.contains(options.queryKey)) return;

        final nextParam = options.getNextPageParam(
          d.pages.last,
          d.pages,
          d.pageParams.last,
          d.pageParams,
        );
        if (nextParam == null) return;

        _fetchingQueries.add(options.queryKey);
        isFetching.value = true;

        await client.fetchInfiniteQuery(
          options: options,
          pageParam: nextParam,
          direction: FetchDirection.forward,
        );

        _fetchingQueries.remove(options.queryKey);
        isFetching.value = false;

        final latest = client
            .getInfiniteQueryState<TQueryFnData, T, TPageParam>(
              options.queryKey,
            );
        if (latest != null && latest.data != null) {
          data.value = InfiniteData<TQueryFnData, TPageParam>(
            pages: latest.data!.pages,
            pageParams: latest.data!.pageParams.cast<TPageParam>(),
          );
        }
      },
      fetchPreviousPage: () async {
        final d = data.value;
        if (d == null ||
            options.getPreviousPageParam == null ||
            _fetchingQueries.contains(options.queryKey)) {
          return;
        }

        final prevParam = options.getPreviousPageParam!(
          d.pages.first,
          d.pages,
          d.pageParams.first,
          d.pageParams,
        );
        if (prevParam == null) return;

        _fetchingQueries.add(options.queryKey);
        isFetching.value = true;

        await client.fetchInfiniteQuery(
          options: options,
          pageParam: prevParam,
          direction: FetchDirection.backward,
        );

        _fetchingQueries.remove(options.queryKey);
        isFetching.value = false;

        final latest = client
            .getInfiniteQueryState<TQueryFnData, T, TPageParam>(
              options.queryKey,
            );
        if (latest != null && latest.data != null) {
          data.value = InfiniteData<TQueryFnData, TPageParam>(
            pages: latest.data!.pages,
            pageParams: latest.data!.pageParams.cast<TPageParam>(),
          );
        }
      },
    );
  }

  final query = InfinitQuery<TQueryFnData, T, TPageParam>(
    options: options,
    queryKey: options.queryKey,
  );

  void updateIsFetching() {
    isFetching.value = _fetchingQueries.contains(options.queryKey);
  }

  void updateFromQuery(InfinitQuery<TQueryFnData, T, TPageParam> q) {
    final qData = q.data;
    if (qData == null) return;

    List<TPageParam> pageParams = [];
    try {
      pageParams = qData.pageParams.cast<TPageParam>();
    } catch (_) {
      return;
    }

    data.value = InfiniteData<TQueryFnData, TPageParam>(
      pages: qData.pages,
      pageParams: pageParams,
    );

    isLoading.value = q.isLoading;
    updateIsFetching();
    isSuccess.value = q.status == QueryStatus.success;
    isError.value = q.status == QueryStatus.error;
    error.value = q.error;

    if (qData.pages.isNotEmpty) {
      final next = options.getNextPageParam(
        qData.pages.last,
        qData.pages,
        pageParams.last,
        pageParams,
      );

      final prev = options.getPreviousPageParam?.call(
        qData.pages.first,
        qData.pages,
        pageParams.first,
        pageParams,
      );

      hasNextPage.value = next != null;
      hasPreviousPage.value = prev != null;
    }
  }

  Future<void> fetchInitial() async {
    if (cached == null) {
      isLoading.value = true;
    }
    _fetchingQueries.add(options.queryKey);
    updateIsFetching();

    await client.fetchInfiniteQuery(
      options: options,
      pageParam: options.initialPageParam,
      direction: FetchDirection.forward,
    );

    _fetchingQueries.remove(options.queryKey);
    updateIsFetching();

    final latest = client.getInfiniteQueryState<TQueryFnData, T, TPageParam>(
      options.queryKey,
    );
    if (latest != null) updateFromQuery(latest);

    isLoading.value = false;
  }

  client.subscribeInfinite(options.queryKey, (query) {
    updateFromQuery(query as InfinitQuery<TQueryFnData, T, TPageParam>);
  });

  InfiniteQueryCache.to.fetchQueryCache(query, EventType.added);

  final cachedQuery = client.getInfiniteQueryState<TQueryFnData, T, TPageParam>(
    options.queryKey,
  );
  if (cachedQuery != null && cachedQuery.data != null) {
    updateFromQuery(cachedQuery);
  } else if (options.enabled && query.status == QueryStatus.idle) {
    query.status = QueryStatus.loading;
    fetchInitial();
  }

  return UseInfiniteQueryResult<TQueryFnData, TPageParam>(
    data: data,
    isLoading: isLoading,
    isFetching: isFetching,
    isSuccess: isSuccess,
    isError: isError,
    error: error,
    hasNextPage: hasNextPage,
    hasPreviousPage: hasPreviousPage,
    fetchNextPage: () async {
      final d = data.value;
      if (d == null || _fetchingQueries.contains(options.queryKey)) return;

      final nextParam = options.getNextPageParam(
        d.pages.last,
        d.pages,
        d.pageParams.last,
        d.pageParams,
      );
      if (nextParam == null) return;

      _fetchingQueries.add(options.queryKey);
      updateIsFetching();

      await client.fetchInfiniteQuery(
        options: options,
        pageParam: nextParam,
        direction: FetchDirection.forward,
      );

      _fetchingQueries.remove(options.queryKey);
      updateIsFetching();
    },
    fetchPreviousPage: () async {
      final d = data.value;
      if (d == null ||
          options.getPreviousPageParam == null ||
          _fetchingQueries.contains(options.queryKey)) {
        return;
      }

      final prevParam = options.getPreviousPageParam!(
        d.pages.first,
        d.pages,
        d.pageParams.first,
        d.pageParams,
      );
      if (prevParam == null) return;

      _fetchingQueries.add(options.queryKey);
      updateIsFetching();

      await client.fetchInfiniteQuery(
        options: options,
        pageParam: prevParam,
        direction: FetchDirection.backward,
      );

      _fetchingQueries.remove(options.queryKey);
      updateIsFetching();
    },
  );
}

