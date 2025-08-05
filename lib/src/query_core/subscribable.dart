import 'package:flutter/material.dart';

typedef Listener = void Function();

class Subscribable<TListener extends Function> {
  final List<TListener> _listeners = [];

  VoidCallback subscribe(TListener listener) {
    _listeners.add(listener);
    onSubscribe();

    return () {
      _listeners.remove(listener);
      onUnsubscribe();
    };
  }

  bool hasListeners() => _listeners.isNotEmpty;

  @protected
  void onSubscribe() {}

  @protected
  void onUnsubscribe() {}

  List<TListener> get listeners => _listeners;
}
