import 'dart:ui';
import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/enums/query_status.dart';
import 'package:get_query/src/enums/refetch_type.dart';
import 'package:get_query/src/query_core/infinite_data.dart';
import 'package:get_query/src/query_core/infinite_query.dart';
import 'package:get_query/src/query_core/infinite_query_cache.dart';
import 'package:get_query/src/query_core/infinite_query_options.dart';
import 'package:get_query/src/query_core/invalidate_options.dart';
import 'package:get_query/src/query_core/query.dart';
import 'package:get_query/src/query_core/query_cache.dart';
import 'package:get_query/src/query_core/query_function_context.dart';
import 'package:get_query/src/query_core/query_options.dart';

typedef QueryListener = void Function(Query query);

class QueryClient {
  static final QueryClient instance = QueryClient._internal();

  factory QueryClient() => instance;
  QueryClient._internal();

  final InfiniteQueryCache _infinitcache = InfiniteQueryCache.to;
  final QueryCache _cache = QueryCache.to;
  final Map<String, List<QueryListener>> _listeners = {};

  VoidCallback subscribe(String queryKey, QueryListener listener) {
    _listeners.putIfAbsent(queryKey, () => []).add(listener);

    return () {
      unsubscribe(queryKey, listener);
    };
  }

  void unsubscribe(String queryKey, QueryListener listener) {
    _listeners[queryKey]?.remove(listener);
    if (_listeners[queryKey]?.isEmpty ?? true) {
      _listeners.remove(queryKey);
    }
  }

  void _notifyListeners(String queryKey) {
    final query = _cache.find(queryKey);
    if (query == null) return;

    if (_listeners.containsKey(queryKey)) {
      for (final listener in _listeners[queryKey]!) {
        listener(query);
      }
    }
  }

  // Update this in fetchQuery and backgroundRefetch
  void _updateQuery(Query query) {
    _cache.fetchQueryCache(query, EventType.updated);
    _notifyListeners(query.key);
  }

  // fetchQueryCache
  Future<T> fetchQuery<T>({required QueryOptions options}) async {
    Query? existingQuery = _cache.find(options.queryKey);
    // ❌ Case 1: Disabled
    if (!options.enabled) {
      if (existingQuery != null && existingQuery.data != null) {
        return existingQuery.data as T;
      }
      throw Exception('Query is disabled and no cached data exists.');
    }

    // ✅ Case 2: Use cached if not stale

    if (existingQuery != null && !existingQuery.isStale(options.staleTime)) {
      // return existingQuery.data as T;
      if (existingQuery.data != null) {
        return existingQuery.data as T;
      } else {
        throw Exception('No cached data available.');
      }
    }

    // ✅ Case 3: We have cached data and stale (run background refetch)
    if (existingQuery != null && existingQuery.isStale(options.staleTime)) {
      if (existingQuery.data != null) {
        // 🔄 Return stale data immediately and start background refetch
        _backgroundRefetch<T>(existingQuery, options as QueryOptions<T>);
        return existingQuery.data as T;
      } else {
        _backgroundRefetch<T>(existingQuery, options as QueryOptions<T>);
      }
    }

    // ✅ Case 4: Create new query
    existingQuery ??= Query<T>(
      key: options.queryKey,
      status: QueryStatus.idle,
      options: options as QueryOptions<T>,
    );
    existingQuery.status = QueryStatus.loading;

    // Add or update in cache and notify
    _cache.fetchQueryCache(existingQuery, EventType.added);

    // if (existingQuery == null) {
    //   final initData = options.initialData?.call();

    //   existingQuery = Query<T>(
    //     key: options.queryKey,
    //     data: initData,
    //     status: initData != null ? QueryStatus.success : QueryStatus.idle,
    //     dataUpdatedAt: initData != null ? DateTime.now() : null,
    //     options: options as QueryOptions<T>,
    //   );

    //   // push into cache immediately
    //   _cache.fetchQueryCache(existingQuery, EventType.added);
    // }
    // existingQuery.status = QueryStatus.loading;

    try {
      T data = await _runWithRetry<T>(
        queryFn: options.queryFn as Future<T> Function(),
        retry: options.retry,
        retryDelay: options.retryDelay,
      );

      existingQuery
        ..data = data
        ..error = null
        ..status = QueryStatus.success
        ..dataUpdatedAt = DateTime.now();

      _updateQuery(existingQuery);
      return data;
    } catch (error) {
      existingQuery
        ..error = error
        ..status = QueryStatus.error;

      _updateQuery(existingQuery);

      rethrow;
    }
  }

  // getQueryState
  Query<T>? getQueryState<T>(String queryKey) {
    final query = _cache.find(queryKey);
    if (query == null) return null;

    return query as Query<T>;
  }

  InfinitQuery<TQueryFnData, T, TPageParam>?
  getInfinitQueryState<TQueryFnData, T, TPageParam>(String queryKey) {
    final query = _infinitcache.find(queryKey);
    if (query == null) return null;

    return query as InfinitQuery<TQueryFnData, T, TPageParam>;
  }

  // fetchInfiniteQuery
  Future<InfinitQuery<TQueryFnData, T, TPageParam>>
  fetchInfiniteQuery<TQueryFnData, T, TPageParam>({
    required InfiniteQueryOptions<TQueryFnData, TPageParam> options,
    required TPageParam pageParam,
    required FetchDirection direction,
  }) async {
    final key = options.queryKey;
    final existing = _infinitcache.find<TQueryFnData, T, TPageParam>(key);

    // ⛔️ Stop early if direction is backward and getPreviousPageParam returns null
    //    and if pageParam == initialPageParam (start page)
    if (direction == FetchDirection.backward &&
        pageParam == options.initialPageParam &&
        options.getPreviousPageParam != null) {
      // We need to run the queryFn once to get first page data to call getPreviousPageParam
      final firstPage = await options.queryFn(
        QueryFunctionContext<TPageParam>(
          pageParam: pageParam,
          queryKey: key,
          client: this,
          direction: direction,
        ),
      );
      final prev = options.getPreviousPageParam!(
        firstPage,
        const [],
        pageParam,
        const [],
      );
      if (prev == null) {
        // No previous page to fetch, so don't fetch anything.
        // Return existing if present, else return new query with idle status.
        return existing ??
            InfinitQuery<TQueryFnData, T, TPageParam>(
              queryKey: key,
              options: options,
              status: QueryStatus.idle,
            );
      }
    }

    // ✅ Return early if requested pageParam is already fetched
    final isAlreadyFetched =
        existing?.data?.pageParams.contains(pageParam) ?? false;

    if (isAlreadyFetched) {
      if (existing!.isStale(options.staleTime)) {
        // Trigger background refetch only if NOT already fetching
        _backgroundRefetchInfiniteQuery(
          options: existing.options,
          query: existing,
        );
      }

      // Always return immediately so stale data is displayed
      return existing;
    }

    // Note: No early return based on overall staleness if pageParam not cached.
    // We want to fetch new pages even if overall data is fresh.

    final query =
        existing ??
        InfinitQuery<TQueryFnData, T, TPageParam>(
          queryKey: key,
          options: options,
        );

    int attempt = 0;
    while (true) {
      try {
        _infinitcache.fetchQueryCache(
          query,
          existing != null ? EventType.updated : EventType.added,
        );

        await query.fetchInfinitePage(
          pageParam: pageParam,
          direction: direction,
          options: options,
        );

        _infinitcache.notify(key, query);
        return query;
      } catch (e) {
        attempt++;
        if (attempt > options.retry) {
          query.status = QueryStatus.error;
          query.error = e;
          _infinitcache.notify(key, query);
          return query;
        }

        final delay =
            options.retryDelay?.call(attempt, e) ??
            Duration(
              milliseconds: (1000 * (1 << (attempt - 1))).clamp(0, 30000),
            );
        await Future.delayed(delay);
      }
    }
  }

  // invalidateQueries
  Future<void> invalidateQueries<TPageParam>({
    String? queryKey,
    bool exact = false,
    RefetchType refetchType = RefetchType.active,
    InvalidateOptions options = const InvalidateOptions(),
  }) async {
    final queries = _cache.findAll(queryKey: queryKey);
    final infinitQueries = _infinitcache.findAll(queryKey: queryKey);

    for (final query in queries) {
      final match = exact
          ? query.key == queryKey
          : query.key.startsWith(queryKey ?? '');
      if (!match) continue;

      // ✅ Determine status BEFORE mutating it
      final isActive =
          query.status == QueryStatus.success ||
          query.status == QueryStatus.loading;
      final isInactive = !isActive;

      final shouldRefetch = switch (refetchType) {
        RefetchType.active => isActive,
        RefetchType.inactive => isInactive,
        RefetchType.all => true,
        RefetchType.none => false,
      };

      // 🔄 Mark as invalidated
      query.status = QueryStatus.idle;

      // If query is being re-fetched, cancel GC timer
      if (query.options?.gcTime != null) {
        query.resetGcTimer();
      }
      print('invalidate fetch for query ${query.key}');

      if (shouldRefetch && query.options?.queryFn != null) {
        if (options.cancelRefetch && query.status == QueryStatus.loading) {
          // cancellation not implemented
          continue;
        }

        try {
          query.status = QueryStatus.loading;
          final data = await query.options!.queryFn();
          query.data = data;
          query.status = QueryStatus.success;
          query.dataUpdatedAt = DateTime.now();
          query.error = null;

          _cache.fetchQueryCache(query, EventType.updated);
        } catch (e) {
          query.status = QueryStatus.error;
          query.error = e;

          _cache.fetchQueryCache(query, EventType.updated);

          if (options.throwOnError) {
            rethrow;
          }
        }
      } else {
        // Just notify the cache that query was invalidated
        _cache.fetchQueryCache(query, EventType.updated);
      }
    }

    for (final infinitquery in infinitQueries) {
      final match = exact
          ? infinitquery.queryKey == queryKey
          : infinitquery.queryKey.startsWith(queryKey ?? '');
      if (!match) continue;

      final isActive =
          infinitquery.status == QueryStatus.success ||
          infinitquery.status == QueryStatus.loading;
      final isInactive = !isActive;

      final shouldRefetch = switch (refetchType) {
        RefetchType.active => isActive,
        RefetchType.inactive => isInactive,
        RefetchType.all => true,
        RefetchType.none => false,
      };

      infinitquery.status = QueryStatus.idle;

      if (infinitquery.options.gcTime != null) {
        infinitquery.resetGcTimer();
      }

      print('invalidate fetch for query ${infinitquery.queryKey}');

      if (shouldRefetch) {
        if (options.cancelRefetch &&
            infinitquery.status == QueryStatus.loading) {
          continue;
        }

        try {
          infinitquery.status = QueryStatus.loading;

          final infiniteData = await infinitquery.fetchAllPages(
            infinitquery.data!.pages.length,
          );
          infinitquery.data = infiniteData;

          infinitquery.status = QueryStatus.success;
          infinitquery.dataUpdatedAt = DateTime.now();
          infinitquery.error = null;

          _infinitcache.fetchQueryCache(infinitquery, EventType.updated);
        } catch (e) {
          infinitquery.status = QueryStatus.error;
          infinitquery.error = e;

          _infinitcache.fetchQueryCache(infinitquery, EventType.updated);

          if (options.throwOnError) {
            rethrow;
          }
        }
      } else {
        _infinitcache.fetchQueryCache(infinitquery, EventType.updated);
      }
    }
  }

  // clear
  void clear() {
    _cache.clear();
    _infinitcache.clear();
  }
  // helpers

  Future<T> _runWithRetry<T>({
    required Future<T> Function() queryFn,
    dynamic retry,
    Duration Function(int attempt, Object error)? retryDelay,
  }) async {
    int failureCount = 0;

    while (true) {
      try {
        return await queryFn();
      } catch (error) {
        failureCount++;

        // Determine whether to retry
        final shouldRetry = switch (retry) {
          bool b => b, // true = infinite, false = never
          int n => failureCount <= n,
          Function() => retry(failureCount, error),
          _ => false,
        };

        if (!shouldRetry) rethrow;

        // Determine delay
        final delay =
            retryDelay?.call(failureCount, 'e') ??
            Duration(
              milliseconds: (1000 * (1 << (failureCount - 1))).clamp(0, 30000),
            );
        await Future.delayed(delay);
      }
    }
  }

  void _backgroundRefetch<T>(
    Query existingQuery,
    QueryOptions<T> options,
  ) async {
    // Avoid refetching if one is already in progress

    existingQuery.status = QueryStatus.loading;
    _cache.fetchQueryCache(
      existingQuery,
      EventType.updated,
    ); // trigger observers

    try {
      final data = await _runWithRetry<T>(
        queryFn: existingQuery.options!.queryFn as Future<T> Function(),
        retry: options.retry,
        retryDelay: options.retryDelay,
      );

      existingQuery
        ..data = data
        ..error = null
        ..status = QueryStatus.success
        ..dataUpdatedAt = DateTime.now()
        ..options = options;

      _updateQuery(existingQuery);
    } catch (error) {
      existingQuery
        ..error = error
        ..status = QueryStatus.error;

      _updateQuery(existingQuery);
    }
  }

  Future<void> _backgroundRefetchInfiniteQuery<TQueryFnData, T, TPageParam>({
    required InfinitQuery<TQueryFnData, T, TPageParam> query,
    required InfiniteQueryOptions<TQueryFnData, TPageParam> options,
  }) async {
    if (query.status == QueryStatus.loading) return;

    query.status = QueryStatus.success;
    _infinitcache.fetchQueryCache(query, EventType.updated);

    try {
      final newPage = await options.queryFn(
        QueryFunctionContext<TPageParam>(
          pageParam: options.initialPageParam,
          queryKey: options.queryKey,
          client: this,
          direction: FetchDirection.forward,
        ),
      );

      final oldData = query.data;

      if (oldData == null) {
        query.data = InfiniteData<TQueryFnData, TPageParam>(
          pages: [newPage],
          pageParams: [options.initialPageParam],
        );
      } else {
        final index = oldData.pageParams.indexOf(options.initialPageParam);
        final updatedPages = [...oldData.pages];
        final updatedParams = [...oldData.pageParams];

        if (index >= 0) {
          updatedPages[index] = newPage;
        } else {
          updatedPages.insert(0, newPage);
          updatedParams.insert(0, options.initialPageParam);
        }

        query.data = InfiniteData<TQueryFnData, TPageParam>(
          pages: updatedPages,
          pageParams: updatedParams,
        );
      }

      query
        ..error = null
        ..status = QueryStatus.success
        ..dataUpdatedAt = DateTime.now();

      _infinitcache.notify(options.queryKey, query);
    } catch (error) {
      query
        ..error = error
        ..status = QueryStatus.error;

      _infinitcache.notify(options.queryKey, query);
    }
  }

  void subscribeInfinite<TQueryFnData, T, TPageParam>(
    String queryKey,
    void Function(InfinitQuery<TQueryFnData, T, TPageParam> query) onUpdate,
  ) {
    _infinitcache.listen(queryKey, (query) {
      if (query is InfinitQuery<TQueryFnData, T, TPageParam>) {
        onUpdate(query);
      }
    });
  }

  InfinitQuery<TQueryFnData, T, TPageParam>?
  getInfiniteQueryState<TQueryFnData, T, TPageParam>(String queryKey) {
    final query =
        _infinitcache.getQuery(queryKey)
            as InfinitQuery<TQueryFnData, T, TPageParam>?;

    return query;
  }
}
