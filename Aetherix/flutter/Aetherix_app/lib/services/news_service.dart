import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_config.dart';
import '../models/article.dart';

/// List filters. Mirrors the backend query parameters on
/// ``/api/v1/news``. ``from`` / ``to`` are inclusive ISO dates
/// (YYYY-MM-DD) and bound the article's effective timestamp
/// (``published_at`` or ``discovered_at``).
class NewsListFilter {
  const NewsListFilter({
    this.limit = 50,
    this.offset = 0,
    this.tag,
    this.from,
    this.to,
  });

  final int limit;
  final int offset;
  final String? tag;
  final String? from;
  final String? to;

  NewsListFilter copyWith({
    int? limit,
    int? offset,
    Object? tag = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
  }) =>
      NewsListFilter(
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
        tag: tag == _sentinel ? this.tag : tag as String?,
        from: from == _sentinel ? this.from : from as String?,
        to: to == _sentinel ? this.to : to as String?,
      );

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsListFilter &&
        other.limit == limit &&
        other.offset == offset &&
        other.tag == tag &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(limit, offset, tag, from, to);
}

class NewsService {
  NewsService(this._dio);
  final Dio _dio;

  Future<List<ArticleSummary>> list({NewsListFilter filter = const NewsListFilter()}) async {
    final params = <String, dynamic>{
      'limit': filter.limit,
      'offset': filter.offset,
    };
    if (filter.tag != null && filter.tag!.isNotEmpty) {
      params['tag'] = filter.tag;
    }
    if (filter.from != null && filter.from!.isNotEmpty) {
      params['from'] = filter.from;
    }
    if (filter.to != null && filter.to!.isNotEmpty) {
      params['to'] = filter.to;
    }
    final res = await _dio.get<List<dynamic>>('/news', queryParameters: params);
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

/// Live intelligence feed. Filter is everything applied to the Feed UI;
/// the Archive screen uses a dedicated provider because it changes
/// only via the calendar.
final latestNewsProvider =
    FutureProvider.family<List<ArticleSummary>, NewsListFilter>(
  (ref, filter) async => ref.watch(newsServiceProvider).list(filter: filter),
);

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

/// The Aetherix allowlist — kept here so the filter chips stay in sync
/// with the backend normalizer. Update both sides if the allowlist
/// changes.
const kAetherixTags = <String>['Cyber Security', 'Hacking', 'AI', 'Technology'];

String tagOrFallback(String? tag) =>
    (tag == null || tag.isEmpty) ? 'Technology' : tag;