## 1.0.0+12
fix(useInfiniteQuery): refetch all the pages instead of refetching just the first page

### Initial Release

- Inspired by TanStack Query (React Query)
- Built for Flutter with GetX integration
- Features:
  - ✅ Caching of async queries
  - ✅ Stale time and refetch management
  - ✅ Automatic retry and garbage collection
  - ✅ Pagination with `useInfiniteQuery`
  - ✅ Centralized error/loading states
  - ✅ Fully reactive with GetX (`Rx`, `Obx`)
- Includes:
  - `useQuery()` for single async fetching
  - `useInfiniteQuery()` for paginated data
  - Query key management
  - Query invalidation support
