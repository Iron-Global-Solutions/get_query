import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

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
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }
}
