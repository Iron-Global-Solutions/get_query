import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/query_core/query.dart';

class QueryCacheNotifyEvent<T> {
  final EventType type;
  final Query query;

  QueryCacheNotifyEvent({
    required this.type,
    required this.query,
  });
}