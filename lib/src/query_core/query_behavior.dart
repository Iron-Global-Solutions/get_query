import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/query_core/infinite_query.dart';
import 'package:get_query/src/query_core/infinite_query_page_params_options.dart';
import 'package:get_query/src/query_core/query_client.dart';


class QueryBehavior<TQueryFnData, TError,T, TPageParam> {
  final void Function(
    FetchContext<TQueryFnData, TError,T, TPageParam> context,
    InfinitQuery query,
  ) onFetch;

  const QueryBehavior({
    required this.onFetch,
  });
}

class FetchContext<TQueryFnData, TError,T, TPageParam> {
  Future<dynamic> Function() fetchFn;
  final FetchOptions<T>? fetchOptions;
  final InfiniteQueryPageParamsOptions options;
  final QueryClient client;
  final String queryKey;
  final InfinitQuery state;

  FetchContext({
    required this.fetchFn,
    this.fetchOptions,
    required this.options,
    required this.client,
    required this.queryKey,
    required this.state,
  });
}

class FetchOptions<T> {
  final bool? cancelRefetch;
  final FetchMeta? meta;
  final Future<T>? initialPromise;

  const FetchOptions({
    this.cancelRefetch,
    this.meta,
    this.initialPromise,
  });
}

class FetchMeta {
  final FetchMore? fetchMore;

  const FetchMeta({this.fetchMore});
}

class FetchMore {
  final FetchDirection direction;

  const FetchMore({required this.direction});
}


