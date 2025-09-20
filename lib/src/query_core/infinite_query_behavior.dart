import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/query_core/infinite_data.dart';
import 'package:get_query/src/query_core/infinite_query_page_params_options.dart';
import 'package:get_query/src/query_core/query_behavior.dart';
import 'package:get_query/src/query_core/query_client.dart';


QueryBehavior<TQueryFnData, TError, T, TPageParam> infiniteQueryBehavior<
  TQueryFnData,
  TError,
  TData,
  T,
  TPageParam
>({int? pages}) {
  return QueryBehavior<TQueryFnData, TError, T, TPageParam>(
    onFetch: (context, query) async {
      final options = context.options;
      final direction = context.fetchOptions?.meta?.fetchMore?.direction;
      final oldPages = context.state.data?.pages ?? [];
      final oldPageParams = context.state.data?.pageParams ?? [];
      InfiniteData<TQueryFnData, T,TPageParam> result =
          InfiniteData<TQueryFnData, T,TPageParam>(pages: [], pageParams: []);
      int currentPage = 0;

      final QueryFunction<T, TPageParam> queryFn = ensureQueryFn(
        fetchOptions: context.fetchOptions,
        queryFn: context.options.queryFn,
        queryHash: context.options.queryHash,
      );

      Future<InfiniteData<TQueryFnData, T,TPageParam>> fetchPage<T>({
        required InfiniteData<TQueryFnData, T,TPageParam> data,
        dynamic param,
        bool? previous,
      }) async {
        if (param == null && data.pages.isNotEmpty) return data;

        QueryFunctionContext<TPageParam> createQueryFnContext<TPageParam>() {
          return QueryFunctionContext<TPageParam>(
            client: context.client,
            queryKey: context.queryKey,
            pageParam: param,
            direction: previous == true
                ? FetchDirection.backward
                : FetchDirection.forward,
            meta: context.options.meta,
          );
        }

        final queryFnContext = createQueryFnContext();
        final page = await queryFn(
          queryFnContext as QueryFunctionContext<TPageParam>,
        );
        final maxPages = context.options.maxPages ?? 0;
        final addTo = previous == true ? addToStart : addToEnd;

        return InfiniteData<TQueryFnData, T,TPageParam>(
          pages: addTo(data.pages, page as TQueryFnData, maxPages),
          pageParams: addTo(data.pageParams, param, maxPages),
        );
      }

      if (direction != null && oldPages.isNotEmpty) {
        final previous = direction == FetchDirection.backward;
        final pageParamFn = previous ? getPreviousPageParam : getNextPageParam;
        final oldData = InfiniteData<TQueryFnData, T,TPageParam>(
          pages: oldPages as List<TQueryFnData>,
          pageParams: oldPageParams as List<TPageParam>,
        );
        final param = pageParamFn(options, oldData);
        result = await fetchPage(
          data: oldData,
          param: param,
          previous: previous,
        );
      } else {
        final remainingPages = pages ?? oldPages.length;
        do {
          final param = currentPage == 0
              ? (oldPageParams.isNotEmpty
                    ? oldPageParams[0]
                    : options.initialPageParam)
              : getNextPageParam(options, result);

          if (currentPage > 0 && param == null) break;

          result = await fetchPage(data: result, param: param);
          currentPage++;
        } while (currentPage < remainingPages);
      }

      context.fetchFn = () async => result;
    },
  );
}

typedef QueryFunction<T, TPageParam> =
    Future<T> Function(QueryFunctionContext<TPageParam> context);

class QueryFunctionContext<TPageParam> {
  final QueryClient client;
  final String queryKey;
  final TPageParam? pageParam;
  final FetchDirection? direction;
  final Map<String, dynamic>? meta;

  QueryFunctionContext({
    required this.client,
    required this.queryKey,
    this.pageParam,
    this.direction,
    this.meta,
  });
}

QueryFunction<TData, TPageParam> ensureQueryFn<TData, TPageParam>({
  Object? queryFn,
  String? queryHash,
  FetchOptions<TData>? fetchOptions,
}) {
  if (queryFn is SkipToken) {
    print(
      "⚠️ Attempted to invoke queryFn when set to skipToken. Query hash: '$queryHash'",
    );
  }

  if (queryFn == null && fetchOptions?.initialPromise != null) {
    return (_) => fetchOptions!.initialPromise!;
  }

  if (queryFn == null || queryFn is SkipToken) {
    return (_) => Future.error("Missing queryFn: '$queryHash'");
  }

  return queryFn as QueryFunction<TData, TPageParam>;
}

class SkipToken {
  const SkipToken._();
  static const skipToken = SkipToken._();
}

List<TQueryFnData> addToEnd<TQueryFnData>(
  List<TQueryFnData> items,
  TQueryFnData item, [
  int max = 0,
]) {
  final newItems = [...items, item];
  return (max > 0 && newItems.length > max) ? newItems.sublist(1) : newItems;
}

List<TQueryFnData> addToStart<TQueryFnData>(
  List<TQueryFnData> items,
  TQueryFnData item, [
  int max = 0,
]) {
  final newItems = [item, ...items];
  return (max > 0 && newItems.length > max)
      ? newItems.sublist(0, newItems.length - 1)
      : newItems;
}

dynamic getNextPageParam<TQueryFnData, TPageParam, T>(
  InfiniteQueryPageParamsOptions<TQueryFnData, TPageParam> options,
  InfiniteData<TQueryFnData, T,TPageParam> data,
) {
  final pages = data.pages;
  final pageParams = data.pageParams;
  final lastIndex = pages.length - 1;

  return pages.isNotEmpty
      ? options.getNextPageParam(
          pages[lastIndex],
          pages,
          pageParams.isNotEmpty ? pageParams[lastIndex] : null as TPageParam,
          pageParams,
        )
      : null;
}

dynamic getPreviousPageParam<TQueryFnData, TPageParam, T>(
  InfiniteQueryPageParamsOptions<TQueryFnData, TPageParam> options,
  InfiniteData<TQueryFnData, T,TPageParam> data,
) {
  final pages = data.pages;
  final pageParams = data.pageParams;

  return pages.isNotEmpty
      ? options.getPreviousPageParam?.call(
          pages[0],
          pages,
          pageParams.isNotEmpty ? pageParams[0] : null as TPageParam,
          pageParams,
        )
      : null;
}

/// Checks if there is a next page.
bool hasNextPage<TQueryFnData, T,TPageParam>(
  InfiniteQueryPageParamsOptions<TQueryFnData, TPageParam> options,
  InfiniteData<TQueryFnData, T,TPageParam>? data,
) {
  if (data == null) return false;
  return getNextPageParam<TQueryFnData, TPageParam, dynamic>(options, data) !=
      null;
}

/// Checks if there is a previous page.
bool hasPreviousPage<TQueryFnData, T,TPageParam>(
  InfiniteQueryPageParamsOptions<TQueryFnData, TPageParam> options,
  InfiniteData<TQueryFnData, T,TPageParam>? data,
) {
  if (data == null || options.getPreviousPageParam == null) return false;
  return getPreviousPageParam<TQueryFnData, TPageParam, dynamic>(
        options,
        data,
      ) !=
      null;
}
