import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/news_service.dart';

class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});
  final int articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(articleDetailProvider(articleId));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () {
            // Back to the previous GoRoute if there is one (the card
            // pushed us via Navigator.pushNamed), otherwise drop into
            // the shell at /.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('ARTICLE'),
        actions: [
          IconButton(
            tooltip: 'Bookmark',
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            onPressed: () async {
              try {
                await ref.read(newsServiceProvider).bookmark(articleId);
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
        loading: () => const Center(child: StatusDot('LOADING ARTICLE')),
        error: (e, _) => Center(
          child: Text('$e',
              style: const TextStyle(color: AppColors.critical)),
        ),
        data: (a) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              if (a.source != null)
                MonoText(
                  'SOURCE: ${a.source!.name}',
                  color: AppColors.textMuted,
                  size: 10,
                  letterSpacing: 1.4,
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                a.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (a.importanceScore != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ImportanceTier.fromScore(a.importanceScore)
                            .color
                            .withValues(alpha: 0.14),
                        border: Border.all(
                          color: ImportanceTier.fromScore(a.importanceScore)
                              .color
                              .withValues(alpha: 0.4),
                        ),
                        borderRadius:
                            BorderRadius.circular(AppRadii.sharp),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 12,
                            color: ImportanceTier.fromScore(a.importanceScore)
                                .color,
                          ),
                          const SizedBox(width: 4),
                          MonoText(
                            ImportanceTier.fromScore(a.importanceScore)
                                .label,
                            color: ImportanceTier.fromScore(a.importanceScore)
                                .color,
                            size: 10,
                            letterSpacing: 1.0,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(width: 4),
                          MonoText(
                            '${a.importanceScore!.toStringAsFixed(1)}/10',
                            color: AppColors.textPrimary,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              if (a.summary != null && a.summary!.isNotEmpty) ...[
                _Section('SUMMARY'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  a.summary!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (a.whatHappened != null && a.whatHappened!.isNotEmpty) ...[
                _Section('WHAT HAPPENED'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  a.whatHappened!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (a.whyItMatters != null && a.whyItMatters!.isNotEmpty) ...[
                _Section('WHY IT MATTERS'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  a.whyItMatters!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.limeHover,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (a.categories.isNotEmpty) ...[
                _Section('TAGS'),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: a.categories
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              border: Border.all(color: AppColors.border),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sharp),
                            ),
                            child: MonoText(
                              c.name.toUpperCase(),
                              color: AppColors.textSecondary,
                              size: 10,
                              letterSpacing: 0.8,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('READ SOURCE'),
                onPressed: () => launchUrl(
                  Uri.parse(a.canonicalUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 1, color: AppColors.lime),
        const SizedBox(width: AppSpacing.xs),
        MonoText(title, color: AppColors.lime, size: 11, letterSpacing: 1.4),
      ],
    );
  }
}