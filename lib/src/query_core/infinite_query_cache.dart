import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/query_core/infinite_query.dart';
import 'package:get_query/src/query_core/infinite_query_cache_notify_event.dart';
import 'package:get_query/src/query_core/subscribable.dart';

typedef QueryCacheListener = void Function(InfiniteQueryCacheNotifyEvent event);

class InfiniteQueryCache<TQueryFnData, T, TPageParam>
    extends Subscribable<QueryCacheListener> {
  final Map<String, InfinitQuery<dynamic, dynamic, dynamic>> _queries = {};
  final List<void Function(InfiniteQueryCacheNotifyEvent event)> _subscribers =
      [];

  static InfiniteQueryCache get to =>
      Get.find<InfiniteQueryCache>();

  Map<String, InfinitQuery<dynamic, dynamic, dynamic>> get queries => _queries;
  final Map<String, List<void Function(InfinitQuery)>> _listeners = {};

  void listen(String key, void Function(InfinitQuery) callback) {
    _listeners.putIfAbsent(key, () => []).add(callback);
  }

  void notify(String key, InfinitQuery query) {
    if (_listeners.containsKey(key)) {
      for (final cb in _listeners[key]!) {
        cb(query);
      }
    }
  }

  InfinitQuery<TQueryFnData, T, TPageParam>? find<TQueryFnData, T, TPageParam>(
    String key,
  ) {
    final query = _queries[key];
    return query as InfinitQuery<TQueryFnData, T, TPageParam>?;
  }

    List<InfinitQuery<TQueryFnData, T, TPageParam>> findAll({String? queryKey}) {
    if (queryKey == null) {
      return _queries.values.toList() as List<InfinitQuery<TQueryFnData, T, TPageParam>>;
    }

    return _queries.entries
        .where((entry) => entry.key.startsWith(queryKey))
        .map((e) => e.value)
        .toList() as List<InfinitQuery<TQueryFnData, T, TPageParam>>;
  }

  

  void fetchQueryCache<TQueryFnData, T, TPageParam>(
    InfinitQuery<TQueryFnData, T, TPageParam> query,
    EventType type,
  ) {
    _queries[query.queryKey] = query;
    _notify(InfiniteQueryCacheNotifyEvent(type: type, query: query));
  }

  void removeQueryCache<TQueryFnData, T, TPageParam>(
    InfinitQuery<TQueryFnData, T, TPageParam> query,
  ) {
    _queries.remove(query.queryKey);
    _notify(
      InfiniteQueryCacheNotifyEvent(type: EventType.removed, query: query),
    );
  }

  VoidCallback subscribe(
    void Function(InfiniteQueryCacheNotifyEvent event) listener,
  ) {
    _subscribers.add(listener);
    return () => _subscribers.remove(listener);
  }

  void clear() {
    _queries.clear();
  }

  void _notify<T>(
    InfiniteQueryCacheNotifyEvent<TQueryFnData, T, TPageParam> event,
  ) {
    for (final listener in _subscribers) {
      listener(event);
    }
  }

  InfinitQuery? getQuery(String queryKey) {
    return _queries[queryKey];
  }

}
