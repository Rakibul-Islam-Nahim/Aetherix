import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../services/news_service.dart';

/// The id of the article that is currently expanded as an inline
/// dropdown across all list views (Feed, Archive, Bookmarks).
/// ``null`` = no card is open. Selecting a new card collapses any
/// previously expanded one.
final expandedArticleIdProvider = StateProvider<int?>((_) => null);

/// Dense intelligence card with inline expansion.
///
/// Collapsed header layout (single row):
///   ``[ TIER ]   [ TAG ]   RATING``
/// Headline below.
///
/// On tap the card expands inline:
///   • WHAT HAPPENED (lazy-loaded detail)
///   • action row   ``[ READ SOURCE ] [ VIEW FULL ]``
class ArticleCard extends ConsumerWidget {
  const ArticleCard({
    super.key,
    required this.article,
    this.onToggleBookmark,
  });

  final ArticleSummary article;
  final VoidCallback? onToggleBookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = article;
    final tier = ImportanceTier.fromScore(a.importanceScore);
    final tag = tagOrFallback(a.tag);
    final fmt = DateFormat.MMMd().add_Hm();
    final expanded = ref.watch(expandedArticleIdProvider);
    final isOpen = expanded == a.id;
    void toggle() {
      ref.read(expandedArticleIdProvider.notifier).state =
          isOpen ? null : a.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(
                    tier: tier,
                    tag: tag,
                    score: a.importanceScore,
                    time: fmt.format(a.publishedAt ?? a.discoveredAt),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    a.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          height: 1.3,
                        ),
                  ),
                  if (isOpen) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WhatHappened(articleId: a.id),
                    const SizedBox(height: AppSpacing.md),
                    _Actions(
                      canonicalUrl: a.canonicalUrl,
                      articleId: a.id,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.tier,
    required this.tag,
    required this.score,
    required this.time,
  });
  final ImportanceTier tier;
  final String tag;
  final double? score;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        _TierChip(tier: tier),
        _TagChip(label: tag),
        if (score != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 11, color: AppColors.textPrimary),
              const SizedBox(width: 3),
              MonoText(
                '${score!.toStringAsFixed(1)}/10',
                color: AppColors.textPrimary,
                size: 11,
                weight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: MonoText(time, color: AppColors.textMuted, size: 10),
        ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});
  final ImportanceTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.sharp),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 10, color: tier.color),
          const SizedBox(width: 4),
          MonoText(
            tier.label,
            color: tier.color,
            size: 10,
            weight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadii.sharp),
      ),
      child: MonoText(
        label.toUpperCase(),
        color: AppColors.lime,
        size: 10,
        weight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Lazy-loads the article detail and renders the ``WHAT HAPPENED`` block.
class _WhatHappened extends ConsumerWidget {
  const _WhatHappened({required this.articleId});
  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articleDetailProvider(articleId));
    return async.when(
      loading: () => Row(
        children: const [
          StatusDot('LOADING'),
          SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 16,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              color: AppColors.lime,
              minHeight: 1.5,
            ),
          ),
        ],
      ),
      error: (e, _) => Text(
        'Detail unavailable: $e',
        style: const TextStyle(color: AppColors.critical, fontSize: 12),
      ),
      data: (detail) {
        final what = detail.whatHappened;
        if (what == null || what.trim().isEmpty) {
          return const MonoText(
            'No detail yet. Try again shortly.',
            color: AppColors.textMuted,
            size: 11,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 1, color: AppColors.lime),
                const SizedBox(width: AppSpacing.xs),
                const MonoText(
                  'WHAT HAPPENED',
                  color: AppColors.lime,
                  size: 10,
                  letterSpacing: 1.4,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              what,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.55,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.canonicalUrl,
    required this.articleId,
  });
  final String canonicalUrl;
  final int articleId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('READ SOURCE'),
            onPressed: canonicalUrl.isEmpty
                ? null
                : () => launchUrl(
                      Uri.parse(canonicalUrl),
                      mode: LaunchMode.externalApplication,
                    ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.article_outlined, size: 14),
            label: const Text('VIEW FULL'),
            onPressed: () {
              Navigator.of(context).pushNamed(
                '/article',
                arguments: articleId,
              );
            },
          ),
        ),
      ],
    );
  }
}