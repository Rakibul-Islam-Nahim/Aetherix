class ArticleSummary {
  final int id;
  final String title;
  final String canonicalUrl;
  final int sourceId;
  final double? importanceScore;
  final String processingStatus;
  final DateTime? publishedAt;
  final DateTime discoveredAt;

  ArticleSummary({
    required this.id,
    required this.title,
    required this.canonicalUrl,
    required this.sourceId,
    required this.importanceScore,
    required this.processingStatus,
    required this.publishedAt,
    required this.discoveredAt,
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