import 'dart:async';
import 'package:get/get.dart';
import 'package:get_query/src/enums/query_status.dart';
import 'package:get_query/src/query_core/connectivity_service.dart';
import 'package:get_query/src/query_core/query_cache.dart';
import 'package:get_query/src/query_core/query_client.dart';
import 'package:get_query/src/query_core/query_observer.dart';
import 'package:get_query/src/query_core/query_options.dart';


class Query<T> {
  final String key;
  T? data;
  Object? error;
  DateTime? dataUpdatedAt;
  QueryStatus status;
  QueryOptions<T>? options;
  final bool refetchOnReconnect; 

  final Set<QueryObserver<T>> _observers = {};
  Timer? _gcTimer;

  Query({
    required this.key,
    this.data,
    this.error,
    this.dataUpdatedAt,
    this.status = QueryStatus.idle,
    this.options,
    this.refetchOnReconnect = true,
  }) {
    if (refetchOnReconnect) _setupConnectivityListener();
  }

  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get isLoading => status == QueryStatus.loading;
  bool get isIdle => status == QueryStatus.idle;
  bool get isActive => _observers.isNotEmpty;

  bool isStale(Duration staleTime) {
    if (dataUpdatedAt == null) return true;
    return DateTime.now().difference(dataUpdatedAt!) > staleTime;
  }

  void onObserverRemoved(QueryObserver<T> observer) {
    _observers.remove(observer);

    if (!isActive) {
      _startGcTimer();
    }
  }

  void onObserverAdded(QueryObserver<T> observer) {
    _observers.add(observer);
    _cancelGcTimer(); // No GC while query is active
  }

  void _startGcTimer() {
    final gcTime = options?.gcTime;
    if (gcTime == null) return;

    _gcTimer = Timer(gcTime, () {
      // Safe cleanup from cache when timer ends
      QueryCache.to.removeQueryCache(this);
    });
  }

  void _cancelGcTimer() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  void dispose() {
    _cancelGcTimer();
    _connectivitySub?.cancel();
    _observers.clear();
  }

  StreamSubscription? _connectivitySub;

  void _setupConnectivityListener() {
    final connectivity = Get.find<ConnectivityService>();
    _connectivitySub = connectivity.isOnline.listen((online) {

      final isDataStale = isStale(options?.staleTime ?? Duration.zero);
      final shouldRefetch = options?.refetchOnReconnect ?? true;
      if (online && isDataStale && shouldRefetch) {
        QueryClient.instance.fetchQuery(options: options!);
      }
    });
  }

  void resetGcTimer() {
    _cancelGcTimer();
    _startGcTimer();
  }
}
