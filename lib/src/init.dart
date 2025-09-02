// lib/src/init.dart

import 'package:get/get.dart';
import 'query_core/query_cache.dart';
import 'query_core/infinite_query_cache.dart';
import 'query_core/online_manager.dart';

Future<void> setupGetQuery() async {
  // Prevent re-initialization
  if (!Get.isRegistered<QueryCache>()) {
    Get.put(QueryCache());
  }

  if (!Get.isRegistered<InfiniteQueryCache>()) {
    Get.put(InfiniteQueryCache());
  }

  if (!Get.isRegistered<OnlineManager>()) {
    await Get.putAsync(() async => OnlineManager());
  }
}
