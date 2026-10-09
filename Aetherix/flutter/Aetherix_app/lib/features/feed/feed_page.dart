import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/article.dart';
import '../../services/news_service.dart';
import '../../widgets/article_card.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/hive_effects.dart';

/// Returns ``YYYY-MM-DD`` for today (local time). Kept as a top-level
/// helper so the same string format is used everywhere the feed needs
/// to scope its date range.
String _todayIso(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

final _feedFilterProvider = StateProvider<FilterCriteria>(
  (ref) => const FilterCriteria(),
);

/// Maps a ``FilterCriteria`` (UI-side state) to a server-side
/// ``NewsListFilter`` only when the criteria change. Keyed on the
/// criteria instance so Riverpod caches it per filter — prevents the
/// per-frame refire loop that left the page stuck on LOADING FEED.
///
/// Feed is TODAY-only: we always pass ``from`` and ``to`` covering the
/// current local day so the backend returns today's articles
/// regardless of what other filters the user picked.
final _feedNewsProvider =
    FutureProvider.autoDispose.family<List<ArticleSummary>, FilterCriteria>(
  (ref, criteria) async {
    final today = _todayIso(DateTime.now());
    final filter = NewsListFilter(
      tag: criteria.tag,
      from: today,
      to: today,
      limit: 100,
    );
    return ref.watch(newsServiceProvider).list(filter: filter);
  },
);

/// Filter-driven intelligence feed with a collapsing app bar.
///
/// The top bar holds:
///   - left:    ``DASHBOARD`` heading + status dot
///   - right:   ``LAST UPDATED · MMM d, HH:mm`` real stamp (refreshes
///     whenever fresh data lands or the user hits the refresh button)
///   - middle:  Critical / High / Medium / Low stat tiles (computed
///     from the today-scoped article list)
///
/// On scroll the bar collapses — only the search bar remains sticky.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criteria = ref.watch(_feedFilterProvider);
    final newsAsync = ref.watch(_feedNewsProvider(criteria));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: newsAsync.when(
        loading: () => const Center(child: StatusDot('LOADING FEED')),
        error: (e, _) => Center(
          child: Text(
            '$e',
            style: const TextStyle(color: AppColors.critical),
          ),
        ),
        data: (articles) => _FeedBody(articles: articles, criteria: criteria),
      ),
    );
  }
}

class _FeedBody extends ConsumerStatefulWidget {
  const _FeedBody({required this.articles, required this.criteria});
  final List<ArticleSummary> articles;
  final FilterCriteria criteria;

  @override
  ConsumerState<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends ConsumerState<_FeedBody> {
  // 0 = expanded (full hero), 1 = fully collapsed. Stored in a notifier
  // so that scroll updates only rebuild the floating bar, not the whole
  // list. Without this the scroll feels janky because the SliverList is
  // being rebuilt on every pixel.
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);

  /// Measured height of the floating app bar (hero + divider + filter
  /// bar). Updated by the bar itself in a post-frame callback so the
  /// list reservation can match it exactly. Without this measurement
  /// the first article gets hidden underneath the bar because the
  /// static `headerHeight` constant doesn't include the filter bar.
  final ValueNotifier<double> _barHeight = ValueNotifier<double>(0);

  /// Real "last refreshed" timestamp. Updated whenever fresh data
  /// arrives (via ref.listen) or when the user hits the refresh
  /// button. epoch = "never loaded yet", rendered as ``—``.
  final ValueNotifier<DateTime> _lastUpdated =
      ValueNotifier(DateTime.fromMillisecondsSinceEpoch(0));

  @override
  void dispose() {
    _lastUpdated.dispose();
    _barHeight.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onScroll(double offset, double maxCollapseOffset) {
    final c = (offset / maxCollapseOffset).clamp(0.0, 1.0);
    // Quantize to 1/64 so micro-frames don't spam rebuilds.
    final quantized = (c * 64).round() / 64;
    if (quantized != _collapse.value) {
      _collapse.value = quantized;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stamp "last updated" on every successful load (including the
    // first one). ref.listen fires only on transitions, so this also
    // covers reloads via the FilterBar refresh button.
    ref.listen<AsyncValue<List<ArticleSummary>>>(
      _feedNewsProvider(widget.criteria),
      (_, next) {
        if (next.hasValue) {
          _lastUpdated.value = DateTime.now();
        }
      },
    );

    // Apply filter to articles list.
    final all = widget.articles;
    final filtered = all.where((a) {
      if (widget.criteria.minImportance > 0 &&
          (a.importanceScore ?? 0) < widget.criteria.minImportance) {
        return false;
      }
      if (widget.criteria.tier != null &&
          ImportanceTier.fromScore(a.importanceScore) != widget.criteria.tier) {
        return false;
      }
      if (widget.criteria.keyword.trim().isNotEmpty) {
        final q = widget.criteria.keyword.toLowerCase();
        if (!a.title.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    // Tally counts per tier on the filtered list.
    final stats = <ImportanceTier, int>{
      ImportanceTier.critical: 0,
      ImportanceTier.high: 0,
      ImportanceTier.medium: 0,
      ImportanceTier.low: 0,
    };
    for (final a in filtered) {
      stats[ImportanceTier.fromScore(a.importanceScore)] =
          (stats[ImportanceTier.fromScore(a.importanceScore)] ?? 0) + 1;
    }
    final visible = filtered.length;
    final total = all.length;

    // 160 px of content scrolls away before the search bar takes over.
    // This is the hero's expanded height; the FilterBar always sits
    // beneath it. The actual reservation used by the Sliver is the
    // measured `_barHeight` (hero + divider + filter bar), updated by
    // the bar itself after layout.
    const headerHeight = 160.0;

    return Stack(
      children: [
        // List sits underneath; the app bar floats on top.
        // We push the first item below the bar by the *measured* bar
        // height (not the static headerHeight) so the filter bar
        // never covers the first news card.
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification) {
                _onScroll(n.metrics.pixels, headerHeight);
              }
              return false;
            },
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _barHeight,
                builder: (context, barHeight, _) {
                  // Fall back to headerHeight + a generous filter-bar
                  // estimate until the bar reports its real height.
                  // This avoids a one-frame "card hidden" pop.
                  final reservation = barHeight > 0
                      ? barHeight + AppSpacing.sm
                      : headerHeight + 140;
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.normal,
                    ),
                    slivers: [
                      // Reserve room for the floating bar.
                      SliverToBoxAdapter(
                        child: SizedBox(height: reservation),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          top: AppSpacing.xs,
                          bottom: AppSpacing.xl,
                        ),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) => RepaintBoundary(
                            child: ArticleCard(article: filtered[i]),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        // The collapsing app bar floats at the top. Wrapped in
        // RepaintBoundary + ValueListenableBuilder so its 60fps animation
        // never forces the list beneath it to relayout.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _collapse,
              builder: (context, collapse, _) {
                return _CollapsingAppBar(
                  collapse: collapse,
                  headerHeight: headerHeight,
                  stats: stats,
                  visible: visible,
                  total: total,
                  lastUpdated: _lastUpdated,
                  onHeightChanged: (size) {
                    final h = size.height;
                    if ((_barHeight.value - h).abs() > 0.5) {
                      _barHeight.value = h;
                    }
                  },
                  child: FilterBar(
                    criteria: widget.criteria,
                    onChanged: (c) =>
                        ref.read(_feedFilterProvider.notifier).state = c,
                    onRefresh: () {
                      // Stamp "just now" immediately so the user sees
                      // the refresh take effect even before the
                      // network call completes. ref.invalidate kicks
                      // the FutureProvider; ref.listen will then
                      // stamp it again on success.
                      _lastUpdated.value = DateTime.now();
                      ref.invalidate(_feedNewsProvider(widget.criteria));
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsingAppBar extends StatelessWidget {
  const _CollapsingAppBar({
    required this.collapse,
    required this.headerHeight,
    required this.stats,
    required this.visible,
    required this.total,
    required this.lastUpdated,
    required this.onHeightChanged,
    required this.child,
  });

  final double collapse;
  final double headerHeight;
  final Map<ImportanceTier, int> stats;
  final int visible;
  final int total;
  final ValueNotifier<DateTime> lastUpdated;
  final ValueChanged<Size> onHeightChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Hero content fades out as we collapse. The FilterBar stays.
    final heroOpacity = (1 - collapse * 1.4).clamp(0.0, 1.0);
    final heroHeight = headerHeight * (1 - collapse);
    return Container(
      color: AppColors.bgSecondary,
      // Measure the bar's real rendered height so the list reservation
      // matches it (otherwise the FilterBar covers the first card).
      // Post-frame callback avoids the setState-in-build error.
      child: MeasureSize(
        onChange: onHeightChanged,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // When the hero is fully collapsed, hide it entirely so the
            // inner Column doesn't try to lay out inside a ~0-px slot and
            // overflow. During the partial-collapse range we keep it
            // visible so the fade-out animates smoothly.
            Visibility(
              visible: heroHeight > 1,
              maintainState: true,
              child: SizedBox(
                width: double.infinity,
                height: heroHeight,
                child: ClipRect(
                  child: Opacity(
                    opacity: heroOpacity,
                    child: IgnorePointer(
                      ignoring: collapse > 0.5,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: _HeroContent(
                          stats: stats,
                          visible: visible,
                          total: total,
                          lastUpdated: lastUpdated,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Always visible - the search/filter bar.
            child,
          ],
        ),
      ),
    );
  }
}

/// Reports its own rendered size via [onChange] after each layout pass.
///
/// Used by the feed's floating app bar so the list reservation tracks
/// the real height (hero + divider + filter bar), not a static constant.
class MeasureSize extends StatefulWidget {
  const MeasureSize({super.key, required this.onChange, required this.child});
  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        widget.onChange(box.size);
      }
    });
    return widget.child;
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.stats,
    required this.visible,
    required this.total,
    required this.lastUpdated,
  });

  final Map<ImportanceTier, int> stats;
  final int visible;
  final int total;
  final ValueNotifier<DateTime> lastUpdated;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusDot('INTELLIGENCE FEED'),
              const Spacer(),
              Icon(Icons.schedule,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              ValueListenableBuilder<DateTime>(
                valueListenable: lastUpdated,
                builder: (_, ts, ___) {
                  // epoch = no data yet
                  final stamp = ts.millisecondsSinceEpoch == 0
                      ? '—'
                      : fmt.format(ts);
                  return MonoText(
                    'LAST UPDATED · $stamp',
                    color: AppColors.textMuted,
                    size: 10,
                    letterSpacing: 1.0,
                    weight: FontWeight.w700,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'FEED',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              MonoText(
                '$visible / $total ARTICLES',
                color: AppColors.lime,
                size: 11,
                letterSpacing: 1.0,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final t in const [
                ImportanceTier.critical,
                ImportanceTier.high,
                ImportanceTier.medium,
                ImportanceTier.low,
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t == ImportanceTier.low ? 0 : AppSpacing.xs,
                    ),
                    child: _StatTile(
                      label: t.label,
                      value: stats[t] ?? 0,
                      color: t.color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBorder(
      color: color.withValues(alpha: 0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCounter(
              value: value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: MonoText(
                label,
                color: AppColors.textMuted,
                size: 9,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}