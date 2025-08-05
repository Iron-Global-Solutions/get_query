import 'package:flutter/material.dart';
import 'package:get_query/src/query_core/query.dart';

class QueryObserver<T> {
  final Query<T> query;
  late final VoidCallback _unsubscribe;

  QueryObserver({required this.query}) {
    _unsubscribe = () => query.onObserverRemoved(this);
    query.onObserverAdded(this);
  }

  void dispose() {
    _unsubscribe(); 
  }
}