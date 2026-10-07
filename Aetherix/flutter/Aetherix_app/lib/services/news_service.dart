import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_config.dart';
import '../models/article.dart';

class NewsService {
  NewsService(this._dio);
  final Dio _dio;

  Future<List<ArticleSummary>> list({int limit = 50, int offset = 0}) async {
    final res = await _dio.get<List<dynamic>>(
      '/news',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ArticleSummary.fromJson)
        .toList();
  }

  Future<ArticleDetail> detail(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/news/$id');
    return ArticleDetail.fromJson(res.data!);
  }

  Future<List<Category>> categories() async {
    final res = await _dio.get<List<dynamic>>('/categories');
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList();
  }

  Future<List<NewsSource>> sources() async {
    final res = await _dio.get<List<dynamic>>('/sources');
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(NewsSource.fromJson)
        .toList();
  }

  Future<void> bookmark(int articleId) async {
    await _dio.post('/bookmarks', data: {'article_id': articleId});
  }

  Future<List<Bookmark>> bookmarks() async {
    final res = await _dio.get<List<dynamic>>('/bookmarks');
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(Bookmark.fromJson)
        .toList();
  }

  Future<void> unbookmark(int articleId) async {
    await _dio.delete('/bookmarks/$articleId');
  }

  Future<List<ArticleSummary>> search(String q, {int limit = 50}) async {
    final res = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {'q': q, 'limit': limit},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ArticleSummary.fromJson)
        .toList();
  }
}

final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService(ref.watch(dioProvider));
});

final latestNewsProvider = FutureProvider<List<ArticleSummary>>((ref) async {
  return ref.watch(newsServiceProvider).list();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(newsServiceProvider).categories();
});

final sourcesProvider = FutureProvider<List<NewsSource>>((ref) async {
  return ref.watch(newsServiceProvider).sources();
});

final articleDetailProvider =
    FutureProvider.family<ArticleDetail, int>((ref, id) async {
  return ref.watch(newsServiceProvider).detail(id);
});

final bookmarksProvider = FutureProvider<List<Bookmark>>((ref) async {
  return ref.watch(newsServiceProvider).bookmarks();
});