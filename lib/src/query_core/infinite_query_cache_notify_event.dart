import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/query_core/infinite_query.dart';

class InfiniteQueryCacheNotifyEvent<TQueryFnData, T, TPageParam>  {
  final EventType type;
  final InfinitQuery query;

  InfiniteQueryCacheNotifyEvent({
    required this.type,
    required this.query,
  });
}

