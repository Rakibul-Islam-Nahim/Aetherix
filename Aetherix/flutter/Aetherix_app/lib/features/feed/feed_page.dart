import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/news_service.dart';
import '../../widgets/article_card.dart';
import '../../widgets/filter_bar.dart';

final _feedFilterProvider = StateProvider<FilterCriteria>(
  (ref) => const FilterCriteria(),
);

/// Filter-driven intelligence feed. Server-side ``tag`` is sent to the
/// backend; importance tier / keyword are applied client-side because
/// the backend's relevance search is broader than the spec demands.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criteria = ref.watch(_feedFilterProvider);
    final filter = NewsListFilter(tag: criteria.tag, limit: 100);
    final newsAsync = ref.watch(latestNewsProvider(filter));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: newsAsync.when(
        loading: () => const Center(child: StatusDot('LOADING FEED')),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppColors.critical)),
        ),
        data: (articles) {
          final filtered = articles.where((a) {
            if (criteria.minImportance > 0 &&
                (a.importanceScore ?? 0) < criteria.minImportance) {
              return false;
            }
            if (criteria.tier != null &&
                ImportanceTier.fromScore(a.importanceScore) != criteria.tier) {
              return false;
            }
            if (criteria.keyword.trim().isNotEmpty) {
              final q = criteria.keyword.toLowerCase();
              if (!a.title.toLowerCase().contains(q)) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              _FeedHeader(count: filtered.length, total: articles.length),
              FilterBar(
                criteria: criteria,
                onChanged: (c) =>
                    ref.read(_feedFilterProvider.notifier).state = c,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) =>
                      ArticleCard(article: filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              StatusDot('INTELLIGENCE FEED'),
              SizedBox(height: AppSpacing.xs),
              Text(
                'FEED',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'See everything. Understand what matters.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          MonoText(
            '$count / $total ARTICLES',
            color: AppColors.lime,
            size: 11,
            letterSpacing: 1.0,
            weight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}