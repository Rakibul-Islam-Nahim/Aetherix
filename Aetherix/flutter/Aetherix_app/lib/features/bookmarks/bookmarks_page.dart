import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/article.dart';
import '../../services/news_service.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load bookmarks: $e'),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No bookmarks yet.'));
          }
          final fmt = DateFormat.MMMd().add_jm();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bookmarksProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final Bookmark b = list[i];
                return Dismissible(
                  key: ValueKey('bookmark-${b.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    try {
                      await ref
                          .read(newsServiceProvider)
                          .unbookmark(b.articleId);
                      ref.invalidate(bookmarksProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Remove failed: $e')),
                        );
                      }
                    }
                  },
                  child: ListTile(
                    title: Text('Article #${b.articleId}'),
                    subtitle: Text(fmt.format(b.createdAt)),
                    onTap: () => context.push('/article/${b.articleId}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}