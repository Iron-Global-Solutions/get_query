import 'package:flutter/foundation.dart';
import 'package:get_query/src/query_core/infinite_query.dart';

class InfiniteQueryObserver<TQueryFnData, T, TPageParam> {
  final InfinitQuery<TQueryFnData, T, TPageParam> query;
  late final VoidCallback _unsubscribe;

  InfiniteQueryObserver({required this.query}) {
    _unsubscribe = () => query.onObserverRemoved(this);
    query.onObserverAdded(this);
  }

  void dispose() {
    _unsubscribe();
  }
}
