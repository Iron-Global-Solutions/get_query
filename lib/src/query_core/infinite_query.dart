import 'dart:async';
import 'package:get/get.dart';
import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/enums/query_status.dart';
import 'package:get_query/src/query_core/online_manager.dart';
import 'package:get_query/src/query_core/infinite_data.dart';
import 'package:get_query/src/query_core/infinite_query_cache.dart';
import 'package:get_query/src/query_core/infinite_query_observer.dart';
import 'package:get_query/src/query_core/infinite_query_options.dart';
import 'package:get_query/src/query_core/query_client.dart';
import 'package:get_query/src/query_core/query_function_context.dart';

class InfinitQuery<TQueryFnData, T, TPageParam> {
  final String queryKey;
  InfiniteData<TQueryFnData, T,TPageParam>? data;
  Object? error;
  DateTime? dataUpdatedAt;
  QueryStatus status;
  final InfiniteQueryOptions<TQueryFnData, TPageParam> options;
  final FetchDirection direction;

  final Set<InfiniteQueryObserver<TQueryFnData, T, TPageParam>> _observers = {};
  Timer? _gcTimer;

  InfinitQuery({
    required this.queryKey,
    required this.options,
    this.data,
    this.error,
    this.dataUpdatedAt,
    this.status = QueryStatus.idle,
    this.direction = FetchDirection.forward,
  }) {
    if (options.refetchOnReconnect) {
      _setupConnectivityListener(direction: direction);
    }
  }

  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get isLoading => status == QueryStatus.loading && data == null;
  bool get isIdle => status == QueryStatus.idle;
  bool get isActive => _observers.isNotEmpty;
  bool get isFetching => status == QueryStatus.loading;

  bool isStale(Duration staleTime) {
    if (dataUpdatedAt == null) return true;
    return DateTime.now().difference(dataUpdatedAt!) > staleTime;
  }

  void onObserverRemoved(
    InfiniteQueryObserver<TQueryFnData, T, TPageParam> observer,
  ) {
    _observers.remove(observer);

    if (!isActive) {
      _startGcTimer();
    }
  }

  void onObserverAdded(
    InfiniteQueryObserver<TQueryFnData, T, TPageParam> observer,
  ) {
    _observers.add(observer);
    _cancelGcTimer(); // No GC while query is active
  }

  void _startGcTimer() {
    final gcTime = options.gcTime;
    if (gcTime == null) return;

    _gcTimer = Timer(gcTime, () {
      // Safe cleanup from cache when timer ends
      InfiniteQueryCache.to.removeQueryCache(this);
    });
  }

  void _cancelGcTimer() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  void dispose() {
    _cancelGcTimer();
    _connectivitySub?.cancel();
    _observers.clear();
  }

  StreamSubscription? _connectivitySub;

  void _setupConnectivityListener({required FetchDirection direction}) {
    final connectivity = Get.find<OnlineManager>();

    _connectivitySub = connectivity.isOnline.listen((online) {
      final isDataStale = isStale(options.staleTime);
      final shouldRefetch = options.refetchOnReconnect;
      if (online && isDataStale && shouldRefetch) {
        QueryClient.instance.fetchInfiniteQuery(
          options: options,
          direction: direction,
          pageParam: options.initialPageParam,
        );
      }
    });
  }

  void resetGcTimer() {
    _cancelGcTimer();
    _startGcTimer();
  }

  void setData(InfiniteData<TQueryFnData, T,TPageParam> newData) {
    data = newData;
    dataUpdatedAt = DateTime.now();
    status = QueryStatus.success; // Update status if needed
  }

  Future<void> fetchInfinitePage({
    required TPageParam pageParam,
    required InfiniteQueryOptions<TQueryFnData, TPageParam> options,
    required FetchDirection direction,
  }) async {
    final newPage = await options.queryFn(
      QueryFunctionContext<TPageParam>(
        pageParam: pageParam,
        queryKey: options.queryKey,
        client: QueryClient.instance,
        direction: FetchDirection.forward,
      ),
    );

    final current =
        data ??
        InfiniteData<TQueryFnData, T,TPageParam>(pages: [], pageParams: []);
    // if (current.pageParams.contains(pageParam)) return;
    // final updatedData = direction == FetchDirection.forward
    //     ? InfiniteData<TQueryFnData, TPageParam>(
    //         pages: [...current.pages, newPage],
    //         pageParams: [...current.pageParams, pageParam],
    //       )
    //     : InfiniteData<TQueryFnData, TPageParam>(
    //         pages: [newPage, ...current.pages],
    //         pageParams: [pageParam, ...current.pageParams],
    //       );

    // setData(updatedData);

    final existingIndex = current.pageParams.indexOf(pageParam);
    List<TQueryFnData> newPages;
    List<TPageParam> newParams;

    if (existingIndex != -1) {
      // replace existing page
      newPages = [...current.pages];
      newPages[existingIndex] = newPage;
      newParams = [...current.pageParams];
    } else {
      // append as new page
      if (direction == FetchDirection.forward) {
        newPages = [...current.pages, newPage];
        newParams = [...current.pageParams, pageParam];
      } else {
        newPages = [newPage, ...current.pages];
        newParams = [pageParam, ...current.pageParams];
      }
    }

    final updatedData = InfiniteData<TQueryFnData, T,TPageParam>(
      pages: newPages,
      pageParams: newParams,
    );

    setData(updatedData);
  }

  Future<InfiniteData<TQueryFnData, T,TPageParam>> fetchAllPages(int l) async {
    final pages = <TQueryFnData>[];
    final pageParams = <TPageParam>[];

    int count = 0;
    TPageParam pageParam = options.initialPageParam;
    while (true) {
      final ctx = QueryFunctionContext<TPageParam>(
        pageParam: pageParam,
        queryKey: options.queryKey,
        client: QueryClient.instance,
        direction: FetchDirection.forward,
      );
      final page = await options.queryFn(ctx);

      pages.add(page);
      pageParams.add(pageParam);

      final next = options.getNextPageParam.call(
        page,
        pages,
        pageParam,
        pageParams,
      );

      count++;
      if (next == null || count > l) break;
      pageParam = next;
    }

    return InfiniteData(pages: pages, pageParams: pageParams);
  }
}

extension InfiniteFetchExtension<T, TQueryFnData, TPageParam>
    on InfinitQuery<TQueryFnData, T, TPageParam> {
  Future<void> fetchInfinitePage({
    required TPageParam pageParam,
    required InfiniteQueryOptions<TQueryFnData, TPageParam> options,
    required FetchDirection direction,
  }) async {
    final context = QueryFunctionContext<TPageParam>(
      queryKey: options.queryKey,
      pageParam: pageParam,
      client: QueryClient.instance,
      direction: FetchDirection.forward,
    );

    final newPage = await options.queryFn(context);

    // merge the page into pages[]
    final current =
        data ??
        InfiniteData<TQueryFnData, T,TPageParam>(pages: [], pageParams: []);

    final updated = direction == FetchDirection.forward
        ? current.copyWith(
            pages: [...current.pages, newPage],
            pageParams: [...current.pageParams, pageParam],
          )
        : current.copyWith(
            pages: [newPage, ...current.pages],
            pageParams: [pageParam, ...current.pageParams],
          );

    // update query data
    setData(updated);
  }
}

extension InfiniteDataCopyWith<TQueryFnData, T,TPageParam>
    on InfiniteData<TQueryFnData, T,TPageParam> {
  InfiniteData<TQueryFnData, T,TPageParam> copyWith({
    List<TQueryFnData>? pages,
    List<TPageParam>? pageParams,
  }) {
    return InfiniteData<TQueryFnData, T,TPageParam>(
      pages: pages ?? this.pages,
      pageParams: pageParams ?? this.pageParams,
    );
  }
}
