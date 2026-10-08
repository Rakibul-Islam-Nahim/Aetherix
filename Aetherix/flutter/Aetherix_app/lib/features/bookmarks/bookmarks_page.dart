import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/article.dart';
import '../../services/news_service.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarksProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                StatusDot('SAVED INTELLIGENCE'),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'BOOKMARKS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: StatusDot('LOADING')),
              error: (e, _) => Center(
                child: Text('$e', style: const TextStyle(color: AppColors.critical)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.bookmark_border,
                            size: 36, color: AppColors.textMuted),
                        SizedBox(height: AppSpacing.sm),
                        MonoText(
                          'NO BOOKMARKS YET',
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ],
                    ),
                  );
                }
                final fmt = DateFormat.MMMd().add_Hm();
                return RefreshIndicator(
                  color: AppColors.lime,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(bookmarksProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final Bookmark b = list[i];
                      return Dismissible(
                        key: ValueKey('bookmark-${b.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.critical.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.critical.withValues(alpha: 0.5),
                            ),
                            borderRadius:
                                BorderRadius.circular(AppRadii.small),
                          ),
                          child: const Icon(Icons.delete,
                              color: AppColors.critical),
                        ),
                        onDismissed: (_) async {
                          await ref
                              .read(newsServiceProvider)
                              .unbookmark(b.articleId);
                          ref.invalidate(bookmarksProvider);
                        },
                        child: InkWell(
                          onTap: () => context.go('/article?id=${b.articleId}'),
                          borderRadius:
                              BorderRadius.circular(AppRadii.small),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.small),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark,
                                    color: AppColors.lime, size: 16),
                                const SizedBox(width: AppSpacing.sm),
                                MonoText('ARTICLE #${b.articleId}',
                                    color: AppColors.textSecondary, size: 11),
                                const Spacer(),
                                MonoText(fmt.format(b.createdAt),
                                    color: AppColors.textMuted, size: 10),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}