import 'package:get_query/src/enums/fetch_direction.dart';
import 'package:get_query/src/query_core/query_client.dart';


class QueryFunctionContext<TPageParam> {
  final TPageParam pageParam;
  final dynamic meta;
  final String queryKey;
  final QueryClient client;
   /// @deprecated
   /// if you want access to the direction, you can add it to the pageParam
  final FetchDirection direction;

  QueryFunctionContext({
    required this.pageParam,
    required this.queryKey,
    required this.client,
    required this.direction,
    this.meta,
  });
}

