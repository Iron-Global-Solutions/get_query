import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_query/src/enums/event_type.dart';
import 'package:get_query/src/query_core/query.dart';
import 'package:get_query/src/query_core/query_cache_notify_event.dart';
import 'package:get_query/src/query_core/subscribable.dart';


typedef QueryCacheListener = void Function(QueryCacheNotifyEvent event);

class QueryCache<T> extends Subscribable<QueryCacheListener> {

  final void Function(Object error)? onError;
  final void Function(T data)? onSuccess;
  final void Function(T? data, Object? error)? onSettled;

  QueryCache({this.onError, this.onSettled, this.onSuccess});

  final Map<String, Query<dynamic>> _queries = {};
  final List<void Function(QueryCacheNotifyEvent event)> _subscribers = [];

  static QueryCache get to => Get.find<QueryCache>();

  Map<String, Query<dynamic>> get queries => _queries;


  
  // ---------------------- API ------------------------

  // find
  // filters?: QueryFilters
  Query<T>? find(String key) {
    final query = _queries[key];
    return query as Query<T>?;
  }

  // find all
  // filters?: QueryFilters
  List<Query<dynamic>> findAll({String? queryKey}) {
    if (queryKey == null) {
      return _queries.values.toList();
    }

    return _queries.entries
        .where((entry) => entry.key.startsWith(queryKey))
        .map((e) => e.value)
        .toList();
  }

  
  // subscribe
  // ✅ Subscribe to cache updates
  VoidCallback subscribe(void Function(QueryCacheNotifyEvent event) listener) {
    _subscribers.add(listener);
    return () {
      _subscribers.remove(listener);
    };
  }

  // clear
  void clear() {
    _queries.clear();
  }

  // helpers
  void fetchQueryCache<T>(Query<T> query, EventType type) {
    _queries[query.key] = query;
    _notify(QueryCacheNotifyEvent(type: type, query: query));
  }
  
  void removeQueryCache<T>(Query<T> query) {
    _queries.remove(query.key);
    _notify(QueryCacheNotifyEvent(type: EventType.removed, query: query));
  }

  void _notify<T>(QueryCacheNotifyEvent<T> event) {
    for (final listener in _subscribers) {
      listener(event);
    }
  }

}
