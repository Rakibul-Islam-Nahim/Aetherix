import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final _singleArticleProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, int>((ref, id) async {
  // Hits /news/{id} once detail endpoint is wired.
  // Stub response for now so the UI renders in Phase 1.
  return {
    'id': id,
    'title': 'Loading…',
    'canonical_url': '',
    'summary': 'Article body will appear here once the backend exposes /news/{id}.',
  };
});

class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});
  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_singleArticleProvider(articleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (a) {
          final url = a['canonical_url'] as String?;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(a['title']?.toString() ?? '', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text(a['summary']?.toString() ?? ''),
              const SizedBox(height: 24),
              if (url != null && url.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read full article'),
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                ),
            ],
          );
        },
      ),
    );
  }
}