import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/news_service.dart';
import '../../models/article.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(latestNewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Good morning, Nahim')),
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Backend unreachable: $e')),
        data: (articles) {
          final critical = articles.where((a) => (a.importanceScore ?? 0) >= 8).toList();
          final rest = articles.where((a) => (a.importanceScore ?? 0) < 8).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latestNewsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: '🔥 Critical',
                  count: critical.length,
                  onTap: () => context.go('/latest'),
                ),
                ...critical.map(
                  (a) => _articleTile(context, a),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'ℹ Today',
                  count: rest.length,
                  onTap: () => context.go('/latest'),
                ),
                ...rest.take(10).map((a) => _articleTile(context, a)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _articleTile(BuildContext context, ArticleSummary a) {
    final fmt = DateFormat.MMMd().add_jm();
    return Card(
      child: ListTile(
        title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(fmt.format(a.publishedAt ?? a.discoveredAt)),
        trailing: a.importanceScore != null
            ? CircleAvatar(child: Text(a.importanceScore!.round().toString()))
            : null,
        onTap: () => context.push('/article/${a.id}'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, this.onTap});
  final String title;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          Text('$count'),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onTap),
          ],
        ],
      ),
    );
  }
}