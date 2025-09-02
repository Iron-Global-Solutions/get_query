import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

typedef OnlineListener = void Function(bool isOnline);

class OnlineManager extends GetxService {
  static OnlineManager get to => Get.find();

  final RxBool isOnline = true.obs;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  final _listeners = <OnlineListener>[];

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
  }

  void _initConnectivity() {
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      // Consider the device online if any connection type is active
      // isOnline.value = results.any((r) => r != ConnectivityResult.none);
      final nextState = results.any((r) => r != ConnectivityResult.none);
      setOnline(nextState);
    });
  }

  /// Set online state manually or via connectivity
  void setOnline(bool value) {
    if (isOnline.value == value) return;

    isOnline.value = value;

    // notify all listeners
    for (final listener in _listeners) {
      listener(value);
    }
  }

  /// Register a listener (like React Query’s subscribe)
  void subscribe(OnlineListener listener) {
    _listeners.add(listener);
    // immediately call with current state
    listener(isOnline.value);
  }

  /// Remove a listener (like React Query’s unsubscribe)
  void unsubscribe(OnlineListener listener) {
    _listeners.remove(listener);
  }

  @override
  void onClose() {
    _subscription.cancel();
    _listeners.clear();
    super.onClose();
  }
}
