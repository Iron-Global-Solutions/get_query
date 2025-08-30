<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# get_query

A **TanStack Query-inspired async caching and pagination package** for **Flutter** using **GetX**.

`get_query` helps manage asynchronous data fetching, caching, and pagination in a reactive and efficient way. It's ideal for Flutter apps using the GetX ecosystem and looking for clean, declarative async state management.

## Features

- 🔁 Auto caching and background refetching
- 📦 Built-in pagination support
- ⚡ Reactive state integration with GetX
- 🧠 Centralized async state and error handling
- 🚀 Clean API inspired by TanStack Query (React Query)

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  get_query: ^1.0.0+11
  ```

## Then import it:
```
import 'package:get_query/get_query.dart';
```
## Usage

```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupGetQuery(); // ✅ initialize everything
  runApp(const MyApp());
}
```

```
import 'package:get/get.dart';
import 'package:get_query/get_query.dart';
import 'package:tanstak_flutter_demo/models/post.dart';
import 'package:tanstak_flutter_demo/repositories/post_repositories.dart';

class PostsController extends GetxController {
  final posts = Rxn<UseQueryResult<List<Post>>>();


  @override
  void onInit() {
    super.onInit();
    posts.value = useQuery(
      queryKey: 'posts',
      queryFn: () async => await PostRepositories().getAllPosts(),
      // staleTime: Duration(minutes: 30),
      // retry: 1,
      // gcTime: Duration(seconds: 10),
    );
  }
}
```
```
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanstak_flutter_demo/screens/posts/posts_controller.dart';

class PostScreen extends GetView<PostsController> {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: Obx(() {
        final result = controller.posts.value;

        if (result!.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (result.error.value != null) {
          return Center(child: Text('Error: ${result.error}'));
        }

        final allPosts = result.data.value;

        return ListView.builder(
          itemCount: allPosts?.length ?? 0,
          itemBuilder: (context, index) {
            final post = allPosts![index];
            return ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(post.images)),
              title: Text(post.username),
              subtitle: Text(post.comment),
            );
          },
        );
      }),
    );
  }
}
```
### 📄 Infinite Pagination Example

```
import 'package:get/get.dart';
import 'package:ta_query/models/posts.dart';
import 'package:ta_query/repo/paginated_response.dart';
import 'package:ta_query/repo/post_repo.dart';
import 'package:ta_query/ta_query/core/cache/infinite_query_options.dart';
import 'package:ta_query/ta_query/core/cache/query.dart';
import 'package:ta_query/ta_query/core/cache/query_observer.dart';
import 'package:ta_query/ta_query/core/client/query_client.dart';
import 'package:ta_query/ta_query/flutter_query/use_infinite_query.dart';
import 'package:ta_query/ta_query/flutter_query/use_query.dart';

class PostController extends GetxController {

  Rx<UseInfiniteQueryResult<PaginatedResponse<Post>, int>?> posts = Rx(null);
  late QueryClient queryClient;

  @override
  void onInit() {
    super.onInit();

    final p = useInfiniteQuery<PaginatedResponse<Post>, int, Post>(
      options: InfiniteQueryOptions<PaginatedResponse<Post>, int>(
        queryKey: 'posts',
        initialPageParam: 1,
        // staleTime: Duration(minutes: 1),
        queryFn: (ctx) => PostRepo().getPosts(page: ctx.pageParam),
        getNextPageParam: (lastPage, pages, lastParam, allParams) =>
            lastPage.pagination.nextPage,
        getPreviousPageParam: (firstPage, pages, firstParam, allParams) =>
            firstPage.pagination.prevPage,
      ),
    );
  }
}
```



```
class PostScreen extends GetView<PostController> {
  const PostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: Obx(() {
        final result = controller.posts.value;

        if (result!.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (result.isError.value) {
          return Center(child: Text('Error: ${result.error}'));
        }

        final allPosts = result.data.value?.pages
            .expand((page) => page.data)
            .toList();

        return NotificationListener<ScrollNotification>(
          onNotification: (scroll) {
            if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 &&
                result.hasNextPage.value && result.isFetching.value == false ) {
              result.fetchNextPage();
            }
            return false;
          },
          child: ListView.builder(
            itemCount: allPosts?.length ?? 0,
            itemBuilder: (context, index) {
              final post = allPosts![index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(post.images),
                ),
                title: Text(post.username),
                subtitle: Text(post.comment),
              );
            },
          ),
        );
      }),
    );
  }
}

```


## Additional information

This package is inspired by TanStack Query (React Query)  and adapts its core principles to Flutter and GetX.

## Contributing / Feedback

We welcome feedback, bug reports, and pull requests!

- [GitHub Repository](https://github.com/Iron-Global-Solutions/get_query)
- [Issue Tracker](https://github.com/Iron-Global-Solutions/get_query/issues)

