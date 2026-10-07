import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/news_service.dart';

class LatestPage extends ConsumerWidget {
  const LatestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(latestNewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Latest')),
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = list[i];
            return ListTile(
              title: Text(a.title),
              subtitle: Text(
                DateFormat.MMMd().add_jm().format(a.publishedAt ?? a.discoveredAt),
              ),
              trailing: a.importanceScore != null
                  ? Text(a.importanceScore!.round().toString())
                  : null,
              onTap: () => context.push('/article/${a.id}'),
            );
          },
        ),
      ),
    );
  }
}