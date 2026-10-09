/// Article models. ``ArticleSummary`` is the list-row shape returned by
/// ``/api/v1/news`` and ``/search``. ``ArticleDetail`` adds the
/// full-text fields used on the article page and on expanded cards.
class ArticleSummary {
  final int id;
  final String title;
  final String canonicalUrl;
  final int sourceId;
  final double? importanceScore;
  final String processingStatus;
  final DateTime? publishedAt;
  final DateTime discoveredAt;

  /// Primary allowlisted tag — one of:
  ///   ``Cyber Security`` | ``Hacking`` | ``AI`` | ``Technology``.
  /// ``null`` only if the row was published before the tag field existed
  /// or the backend failed to normalize. The UI renders ``Technology``
  /// in that case so it never shows a blank.
  final String? tag;

  ArticleSummary({
    required this.id,
    required this.title,
    required this.canonicalUrl,
    required this.sourceId,
    required this.importanceScore,
    required this.processingStatus,
    required this.publishedAt,
    required this.discoveredAt,
    this.tag,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> j) => ArticleSummary(
        id: j['id'] as int,
        title: j['title'] as String,
        canonicalUrl: j['canonical_url'] as String,
        sourceId: j['source_id'] as int,
        importanceScore: (j['importance_score'] as num?)?.toDouble(),
        processingStatus: j['processing_status'] as String,
        publishedAt: j['published_at'] != null
            ? DateTime.parse(j['published_at'] as String)
            : null,
        discoveredAt: DateTime.parse(j['discovered_at'] as String),
        tag: j['tag'] as String?,
      );
}

class ArticleDetail extends ArticleSummary {
  final String? author;
  final String? summary;
  final String? whatHappened;
  final String? whyItMatters;
  final List<Category> categories;
  final NewsSource? source;

  ArticleDetail({
    required super.id,
    required super.title,
    required super.canonicalUrl,
    required super.sourceId,
    required super.importanceScore,
    required super.processingStatus,
    required super.publishedAt,
    required super.discoveredAt,
    super.tag,
    this.author,
    this.summary,
    this.whatHappened,
    this.whyItMatters,
    this.categories = const [],
    this.source,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> j) => ArticleDetail(
        id: j['id'] as int,
        title: j['title'] as String,
        canonicalUrl: j['canonical_url'] as String,
        sourceId: j['source_id'] as int,
        importanceScore: (j['importance_score'] as num?)?.toDouble(),
        processingStatus: j['processing_status'] as String,
        publishedAt: j['published_at'] != null
            ? DateTime.parse(j['published_at'] as String)
            : null,
        discoveredAt: DateTime.parse(j['discovered_at'] as String),
        tag: j['tag'] as String?,
        author: j['author'] as String?,
        summary: j['summary'] as String?,
        whatHappened: j['what_happened'] as String?,
        whyItMatters: j['why_it_matters'] as String?,
        categories: (j['categories'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Category.fromJson)
            .toList(),
        source: j['source'] == null
            ? null
            : NewsSource.fromJson(j['source'] as Map<String, dynamic>),
      );
}

class NewsSource {
  final int id;
  final String name;
  final String url;
  final String type;
  final bool enabled;
  final String? category;

  NewsSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.enabled,
    this.category,
  });

  factory NewsSource.fromJson(Map<String, dynamic> j) => NewsSource(
        id: j['id'] as int,
        name: j['name'] as String,
        url: j['url'] as String,
        type: j['type'] as String,
        enabled: j['enabled'] as bool,
        category: j['category'] as String?,
      );
}

class Category {
  final int id;
  final String name;
  final String? description;

  Category({required this.id, required this.name, this.description});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String?,
      );
}

class Bookmark {
  final int id;
  final int userId;
  final int articleId;
  final DateTime createdAt;
  final String? articleTitle;
  final String? articleCanonicalUrl;

  Bookmark({
    required this.id,
    required this.userId,
    required this.articleId,
    required this.createdAt,
    this.articleTitle,
    this.articleCanonicalUrl,
  });

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        articleId: j['article_id'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
        articleTitle: j['article_title'] as String?,
        articleCanonicalUrl: j['article_canonical_url'] as String?,
      );
}