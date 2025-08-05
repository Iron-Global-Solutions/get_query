class InfiniteData<TQueryFnData,TPageParam> {
  final List<TQueryFnData> pages;
  final List<TPageParam> pageParams;

  InfiniteData({
    required this.pages,
    required this.pageParams,
  });
}
