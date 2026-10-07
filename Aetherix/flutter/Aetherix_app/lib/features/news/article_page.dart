import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/news_service.dart';

class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});
  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articleDetailProvider(articleId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              try {
                await ref
                    .read(newsServiceProvider)
                    .bookmark(articleId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmarked')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bookmark failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load article: $e'),
          ),
        ),
        data: (a) {
          final url = a.canonicalUrl;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (a.source != null)
                Text(
                  a.source!.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              const SizedBox(height: 4),
              Text(
                a.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (a.importanceScore != null)
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 4),
                    Text('Importance ${a.importanceScore!.round()}/10'),
                  ],
                ),
              const SizedBox(height: 16),
              if (a.summary != null && a.summary!.isNotEmpty) ...[
                Text(
                  a.summary!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              if (a.whatHappened != null && a.whatHappened!.isNotEmpty) ...[
                _section(context, 'What happened', a.whatHappened!),
              ],
              if (a.whyItMatters != null && a.whyItMatters!.isNotEmpty) ...[
                _section(context, 'Why it matters', a.whyItMatters!),
              ],
              if (a.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: a.categories
                      .map((c) => Chip(label: Text(c.name)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              if (url.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read full article'),
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}