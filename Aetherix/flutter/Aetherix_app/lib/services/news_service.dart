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