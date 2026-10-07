import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/article.dart';
import '../../services/news_service.dart';

final _searchResultsProvider =
    FutureProvider.autoDispose.family<List<ArticleSummary>, String>(
  (ref, q) async {
    if (q.trim().isEmpty) return const [];
    return ref.watch(newsServiceProvider).search(q);
  },
);

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_searchResultsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, summary, category, source',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => setState(() => _query = v.trim()),
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  setState(() => _query = '');
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: results.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  if (_query.isEmpty) {
                    return const Center(
                      child: Text('Type and press enter to search.'),
                    );
                  }
                  if (list.isEmpty) {
                    return Center(child: Text('No results for "$_query".'));
                  }
                  final fmt = DateFormat.MMMd().add_jm();
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = list[i];
                      return ListTile(
                        title: Text(a.title),
                        subtitle: Text(
                          fmt.format(a.publishedAt ?? a.discoveredAt),
                        ),
                        onTap: () => context.push('/article/${a.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}