import 'package:get/get.dart';
import 'package:get_query/src/enums/query_status.dart';
import 'package:get_query/src/query_core/query.dart';
import 'package:get_query/src/query_core/query_client.dart';
import 'package:get_query/src/query_core/query_options.dart';

class UseQueryResult<T> {
  final Rx<T?> data;
  final Rx<Object?> error;
  final RxBool isLoading;
  final RxBool isError;
  final RxBool isFetching;
  final Rx<QueryStatus> status;
  final Future<void> Function() refetch;

  UseQueryResult({
    required this.data,
    required this.error,
    required this.isLoading,
    required this.isError,
    required this.isFetching,
    required this.status,
    required this.refetch,
  });
}

class UseQueryController<T> extends GetxController {
  final UseQueryResult<T> result;
  final void Function() _unsubscribe;

  UseQueryController({
    required this.result,
    required void Function() unsubscribe,
  }) : _unsubscribe = unsubscribe;

  @override
  void onClose() {
    _unsubscribe();
    super.onClose();
  }
}

UseQueryResult<T> useQuery<T>({
  required String queryKey,
  required Future<T> Function() queryFn,
  Duration staleTime = Duration.zero,
  bool enabled = true,
  Duration? refetchInterval,
  bool refetchIntervalInBackground = false,
  bool refetchOnWindowFocus = true,
  bool refetchOnReconnect = true,
  bool refetchOnMount = true,
  List<String>? notifyOnChangeProps,
  Duration? gcTime,
  int retry = 3,
  Duration Function(int attempt, Object error)? retryDelay,
  bool? retryOnMount,
  void Function(T? data)? onSuccess,
  void Function(Object error)? onError,
}) {
  final queryClient = QueryClient.instance;

  final Rx<T?> data = Rx<T?>(null);
  final Rx<Object?> error = Rx<Object?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isError = false.obs;
  final RxBool isFetching = false.obs;
  final Rx<QueryStatus> status = QueryStatus.idle.obs;

  final QueryOptions<T> options = QueryOptions(
    queryKey: queryKey,
    queryFn: queryFn,
    staleTime: staleTime,
    enabled: enabled,
    refetchOnReconnect: refetchOnReconnect,
    gcTime: gcTime,
    retry: retry,
    retryDelay: retryDelay,
    retryOnMount: retryOnMount,
    onSuccess: onSuccess,
    onError: onError,
  );

  void updateFromQuery(Query query) {
    data.value = query.data as T?;
    error.value = query.error;
    status.value = query.status;
    isFetching.value = query.status == QueryStatus.loading;
    isError.value = query.status == QueryStatus.error;
  }

  Future<void> fetch() async {
    isFetching.value = true;
    isLoading.value = true;
    isError.value = false;
    status.value = QueryStatus.loading;

    try {
      final result = await queryClient.fetchQuery<T>(options: options);
      data.value = result;
      error.value = null;
      status.value = QueryStatus.success;

      if (options.onSuccess != null) {
        options.onSuccess!(result);
      }
    } catch (e) {
      error.value = e;
      isError.value = true;
      status.value = QueryStatus.error;

      if (options.onError != null) {
        options.onError!(e);
      }
    } finally {
      isLoading.value = false;
      isFetching.value = false;
    }
  }

  Future<void> refetch() async {
    isFetching.value = true;
    isError.value = false;
    try {
      final result = await queryClient.fetchQuery<T>(options: options);
      data.value = result;
      error.value = null;
      status.value = QueryStatus.success;

      if (options.onSuccess != null) {
        options.onSuccess!(result);
      }
    } catch (e) {
      error.value = e;
      isError.value = true;
      status.value = QueryStatus.error;
      if (options.onError != null) {
        options.onError!(e);
      }
    } finally {
      isFetching.value = false;
    }
  }

  // Subscribe to query updates
  queryClient.subscribe(queryKey, updateFromQuery);

  final existingQuery = queryClient.getQueryState<T>(queryKey);
  if (existingQuery != null) {
    if (!existingQuery.options!.enabled || !existingQuery.isStale(staleTime)) {
      updateFromQuery(existingQuery);
    }
    if (existingQuery.isStale(staleTime)) {
      refetch();
    }
  } else {
    fetch();
  }
  // if (existingQuery != null && !existingQuery.isStale(staleTime)) {
  //   updateFromQuery(existingQuery);
  // } else if(){
  //   fetch();
  // }

  return UseQueryResult<T>(
    data: data,
    error: error,
    isLoading: isLoading,
    isError: isError,
    isFetching: isFetching,
    status: status,
    refetch: refetch,
  );
}
