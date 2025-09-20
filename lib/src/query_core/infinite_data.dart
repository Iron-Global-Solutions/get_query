class InfiniteData<TQueryFnData,T,TPageParam> {
  final List<TQueryFnData> pages;
  final List<TPageParam> pageParams;

  InfiniteData({
    required this.pages,
    required this.pageParams,
  });
}
