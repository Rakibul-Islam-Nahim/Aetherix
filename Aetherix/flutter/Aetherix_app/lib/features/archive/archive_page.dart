import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/article.dart';
import '../../services/news_service.dart';
import '../../widgets/article_card.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/hive_effects.dart';
import '../../widgets/measure_size.dart';

/// Selected day in the Archive. Defaults to *today* on first load.
final _selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Whether the calendar pane is currently shown. Starts visible (popped
/// up). Picking a day dismisses it; the appbar "RECHECK" button re-opens
/// it.
final _calendarVisibleProvider = StateProvider<bool>((ref) => true);

/// Filter applied to the day's article list. Independent of the feed
/// page's filter so navigating away doesn't reset it.
final _archiveFilterProvider =
    StateProvider<FilterCriteria>((ref) => const FilterCriteria());

/// The archive is locked to the current month — there is no
/// prev/next navigation. The provider exists so a future "history"
/// mode can swap it out without changing the UI.
final _visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Map of ``YYYY-MM-DD`` -> count of articles on that day (lazy cache).
/// Scoped to the visible month.
final _dayCountsProvider =
    FutureProvider.family<Map<String, int>, ({DateTime from, DateTime to})>(
  (ref, range) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final svc = ref.watch(newsServiceProvider);
    final rows = await svc.list(
      filter: NewsListFilter(
        from: fmt.format(range.from),
        to: fmt.format(range.to),
        limit: 500,
      ),
    );
    final out = <String, int>{};
    for (final r in rows) {
      final ts = r.publishedAt ?? r.discoveredAt;
      final key = fmt.format(ts.toLocal());
      out[key] = (out[key] ?? 0) + 1;
    }
    return out;
  },
);

/// Articles for a specific day.
final _dayArticlesProvider =
    FutureProvider.family<List<ArticleSummary>, DateTime>((ref, day) async {
  final fmt = DateFormat('yyyy-MM-dd');
  return ref.watch(newsServiceProvider).list(
        filter: NewsListFilter(
          from: fmt.format(day),
          to: fmt.format(day),
          limit: 500,
        ),
      );
});

class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDayProvider);
    final visible = ref.watch(_visibleMonthProvider);
    final calendarOpen = ref.watch(_calendarVisibleProvider);

    final counts = ref.watch(_dayCountsProvider((
      from: DateTime(visible.year, visible.month, 1),
      to: DateTime(visible.year, visible.month + 1, 0),
    )));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: ArchiveBody(
        selected: selected,
        visible: visible,
        calendarOpen: calendarOpen,
        countsAsync: counts,
      ),
    );
  }
}

class ArchiveBody extends ConsumerStatefulWidget {
  const ArchiveBody({
    super.key,
    required this.selected,
    required this.visible,
    required this.calendarOpen,
    required this.countsAsync,
  });

  final DateTime? selected;
  final DateTime visible;
  final bool calendarOpen;
  final AsyncValue<Map<String, int>> countsAsync;

  @override
  ConsumerState<ArchiveBody> createState() => _ArchiveBodyState();
}

class _ArchiveBodyState extends ConsumerState<ArchiveBody> {
  // 0 = expanded, 1 = fully collapsed.
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);
  final ValueNotifier<double> _barHeight = ValueNotifier<double>(0);

  // Approximate hero+filter height until the bar reports its real one.
  // Used to seed the list reservation and to compute the scroll range.
  static const _approxBarHeight = 200.0;

  @override
  void dispose() {
    _collapse.dispose();
    _barHeight.dispose();
    super.dispose();
  }

  void _onScroll(double offset) {
    final c = (offset / _approxBarHeight).clamp(0.0, 1.0);
    final q = (c * 64).round() / 64;
    if (q != _collapse.value) _collapse.value = q;
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.selected;
    final articlesAsync = day == null
        ? const AsyncValue<List<ArticleSummary>>.data([])
        : ref.watch(_dayArticlesProvider(day));
    final filter = ref.watch(_archiveFilterProvider);
    final headerFmt = DateFormat.yMMMMEEEEd();
    final fmt = DateFormat('EEE MMM d  HH:mm');

    return Stack(
      children: [
        // List of articles for the selected day, with the filter applied
        // client-side. When the calendar is open it sits underneath
        // the calendar sheet (which is non-scrolling).
        Positioned.fill(
          child: _ArchiveList(
            calendarOpen: widget.calendarOpen,
            articlesAsync: articlesAsync,
            filter: filter,
            day: day,
            headerFmt: headerFmt,
            fmt: fmt,
            barHeight: _barHeight,
            onScroll: _onScroll,
            onOpenCalendar: () {
              ref.read(_calendarVisibleProvider.notifier).state = true;
            },
            onRefresh: () {
              if (day != null) {
                ref.invalidate(_dayArticlesProvider(day));
              }
              ref.invalidate(_dayCountsProvider((
                from: DateTime(
                    widget.visible.year, widget.visible.month, 1),
                to: DateTime(
                    widget.visible.year, widget.visible.month + 1, 0),
              )));
            },
          ),
        ),
        // Floating app bar (hero + filter row). Scrolls away with
        // the list so the body becomes clean.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _collapse,
              builder: (context, collapse, _) {
                return _CollapsingArchiveBar(
                  collapse: collapse,
                  selectedDay: day,
                  calendarOpen: widget.calendarOpen,
                  onHeightChanged: (size) {
                    final h = size.height;
                    if ((_barHeight.value - h).abs() > 0.5) {
                      _barHeight.value = h;
                    }
                  },
                  onOpenCalendar: () {
                    ref.read(_calendarVisibleProvider.notifier).state = true;
                  },
                  onFilterChanged: (c) {
                    ref.read(_archiveFilterProvider.notifier).state = c;
                  },
                );
              },
            ),
          ),
        ),
        // Calendar sheet. Pushed in below the floating bar; non-
        // scrolling. We measure the bar's current height so the sheet
        // starts just under it.
        if (widget.calendarOpen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _barHeight,
              builder: (context, barHeight, _) {
                return Padding(
                  padding: EdgeInsets.only(top: barHeight),
                  child: _CalendarSheet(
                    visible: widget.visible,
                    selected: day,
                    countsAsync: widget.countsAsync,
                    onSelect: (d) {
                      ref.read(_selectedDayProvider.notifier).state =
                          DateTime(d.year, d.month, d.day);
                      ref.read(_calendarVisibleProvider.notifier).state = false;
                    },
                    onClose: () {
                      ref.read(_calendarVisibleProvider.notifier).state = false;
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({
    required this.calendarOpen,
    required this.articlesAsync,
    required this.filter,
    required this.day,
    required this.headerFmt,
    required this.fmt,
    required this.barHeight,
    required this.onScroll,
    required this.onOpenCalendar,
    required this.onRefresh,
  });

  final bool calendarOpen;
  final AsyncValue<List<ArticleSummary>> articlesAsync;
  final FilterCriteria filter;
  final DateTime? day;
  final DateFormat headerFmt;
  final DateFormat fmt;
  final ValueNotifier<double> barHeight;
  final ValueChanged<double> onScroll;
  final VoidCallback onOpenCalendar;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<double>(
      valueListenable: barHeight,
      builder: (context, measuredBar, _) {
        // Reserve room for the floating bar plus a small gap.
        // When the calendar is open we use a generous reservation
        // (the sheet pushes content down) so the list doesn't peek
        // through behind it.
        final reservation = calendarOpen
            ? MediaQuery.of(context).size.height * 0.5
            : (measuredBar > 0
                ? measuredBar + AppSpacing.sm
                : _ArchiveBodyState._approxBarHeight + 60);
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification && !calendarOpen) {
              onScroll(n.metrics.pixels);
            }
            return false;
          },
          child: RefreshIndicator(
            color: AppColors.lime,
            backgroundColor: AppColors.surface,
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.normal,
              ),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: reservation)),
                if (day == null)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PickADayState(),
                  )
                else
                  ..._buildDaySlivers(articlesAsync, filter),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDaySlivers(
    AsyncValue<List<ArticleSummary>> async,
    FilterCriteria filter,
  ) {
    return [
      SliverToBoxAdapter(
        child: _DayHeader(
          day: day!,
          headerFmt: headerFmt,
          onOpenCalendar: onOpenCalendar,
          async: async,
        ),
      ),
      ...async.when(
        loading: () => [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: StatusDot('LOADING DAY')),
          ),
        ],
        error: (e, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '$e',
                style: const TextStyle(color: AppColors.critical),
              ),
            ),
          ),
        ],
        data: (list) {
          final filtered = list.where(filter.matches).toList();
          if (filtered.isEmpty) {
            final empty = list.isEmpty
                ? 'NO INTELLIGENCE ON ${fmt.format(day!).toUpperCase()}'
                : 'NO ARTICLES MATCH YOUR FILTER';
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_busy,
                          size: 32, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.sm),
                      MonoText(
                        empty,
                        color: AppColors.textMuted,
                        size: 10,
                        letterSpacing: 1.2,
                      ),
                    ],
                  ),
                ),
              ),
            ];
          }
          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
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
          ];
        },
      ),
    ];
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.headerFmt,
    required this.onOpenCalendar,
    required this.async,
  });
  final DateTime day;
  final DateFormat headerFmt;
  final VoidCallback onOpenCalendar;
  final AsyncValue<List<ArticleSummary>> async;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const StatusDot('SELECTED DAY'),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: MonoText(
              headerFmt.format(day).toUpperCase(),
              color: AppColors.textPrimary,
              size: 11,
              letterSpacing: 1.2,
              weight: FontWeight.w700,
            ),
          ),
          async.maybeWhen(
            data: (list) => MonoText(
              '${list.length} ARTICLES',
              color: AppColors.lime,
              size: 10,
              letterSpacing: 1.0,
              weight: FontWeight.w700,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Open calendar',
            icon: const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.lime),
            onPressed: onOpenCalendar,
          ),
        ],
      ),
    );
  }
}

class _PickADayState extends StatelessWidget {
  const _PickADayState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 36, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.sm),
          MonoText(
            'PICK A DAY FROM THE CALENDAR',
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ],
      ),
    );
  }
}

/// The hero (title + status dot) plus the filter row. Both collapse
/// together on scroll. The filter row is part of the same widget so
/// they animate as one block.
class _CollapsingArchiveBar extends StatelessWidget {
  const _CollapsingArchiveBar({
    required this.collapse,
    required this.selectedDay,
    required this.calendarOpen,
    required this.onHeightChanged,
    required this.onOpenCalendar,
    required this.onFilterChanged,
  });

  final double collapse;
  final DateTime? selectedDay;
  final bool calendarOpen;
  final ValueChanged<Size> onHeightChanged;
  final VoidCallback onOpenCalendar;
  final ValueChanged<FilterCriteria> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final heroOpacity = (1 - collapse * 1.4).clamp(0.0, 1.0);
    final heroHeight = 96.0 * (1 - collapse);
    return Material(
      color: AppColors.bgSecondary,
      elevation: collapse > 0.01 ? 2 : 0,
      shadowColor: Colors.black54,
      child: MeasureSize(
        onChange: onHeightChanged,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero — fades and shrinks on scroll. Visibility-gated so
            // it doesn't try to lay out inside a ~0-px slot.
            Visibility(
              visible: heroHeight > 1,
              maintainState: true,
              child: SizedBox(
                width: double.infinity,
                height: heroHeight,
                child: Opacity(
                  opacity: heroOpacity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const StatusDot('HISTORICAL INTELLIGENCE'),
                            const Spacer(),
                            if (!calendarOpen)
                              TextButton.icon(
                                onPressed: onOpenCalendar,
                                icon: const Icon(
                                  Icons.event_repeat,
                                  size: 14,
                                  color: AppColors.lime,
                                ),
                                label: const Text(
                                  'RECHECK',
                                  style: TextStyle(
                                    color: AppColors.lime,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'ARCHIVE',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          calendarOpen
                              ? 'Pick a day. Read what happened.'
                              : (selectedDay == null
                                  ? 'No day selected.'
                                  : 'Showing: ${DateFormat('EEEE, MMM d').format(selectedDay!)}'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Filter row — slides up with the hero. Hidden when no
            // day is selected because there's nothing to filter.
            if (selectedDay != null && !calendarOpen)
              FilterBar(
                criteria: const FilterCriteria(),
                onChanged: onFilterChanged,
                onRefresh: () {},
              ),
          ],
        ),
      ),
    );
  }
}

/// Calendar sheet that pops in below the floating bar. The month is
/// fixed (the archive is current-month-only) so no prev/next
/// navigation is rendered.
class _CalendarSheet extends StatelessWidget {
  const _CalendarSheet({
    required this.visible,
    required this.selected,
    required this.countsAsync,
    required this.onSelect,
    required this.onClose,
  });

  final DateTime visible;
  final DateTime? selected;
  final AsyncValue<Map<String, int>> countsAsync;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onClose;

  static const _weekdayLabels = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(visible).toUpperCase();
    final firstWeekday = DateTime(visible.year, visible.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;
    final daysInMonth = DateTime(visible.year, visible.month + 1, 0).day;

    return Material(
      color: AppColors.bgPrimary,
      elevation: 4,
      shadowColor: Colors.black87,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: MonoText(
                        monthLabel,
                        color: AppColors.textPrimary,
                        size: 12,
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close calendar',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: _weekdayLabels
                    .map(
                      (l) => Expanded(
                        child: Center(
                          child: MonoText(
                            l,
                            color: AppColors.textMuted,
                            size: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xs),
              countsAsync.when(
                loading: () => const _CalendarSkeleton(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'Calendar unavailable: $e',
                    style: const TextStyle(
                        color: AppColors.critical, fontSize: 12),
                  ),
                ),
                data: (counts) => _Grid(
                  visible: visible,
                  leadingBlanks: leadingBlanks,
                  daysInMonth: daysInMonth,
                  counts: counts,
                  selected: selected,
                  onSelect: onSelect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.visible,
    required this.leadingBlanks,
    required this.daysInMonth,
    required this.counts,
    required this.selected,
    required this.onSelect,
  });
  final DateTime visible;
  final int leadingBlanks;
  final int daysInMonth;
  final Map<String, int> counts;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final children = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      children.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(visible.year, visible.month, d);
      final key = fmt.format(day);
      final count = counts[key] ?? 0;
      final isSelected = selected != null &&
          selected!.year == day.year &&
          selected!.month == day.month &&
          selected!.day == day.day;
      final isToday = _isToday(day);
      children.add(_DayCell(
        day: day,
        count: count,
        isSelected: isSelected,
        isToday: isToday,
        onTap: () => onSelect(day),
      ));
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: children,
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return n.year == d.year && n.month == d.month && n.day == d.day;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });
  final DateTime day;
  final int count;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limeDot = count > 0;
    final bgColor = isSelected
        ? AppColors.lime.withValues(alpha: 0.15)
        : Colors.transparent;
    final borderColor = isSelected
        ? AppColors.lime
        : (isToday ? AppColors.border : Colors.transparent);
    final dayColor = isSelected
        ? AppColors.lime
        : (isToday ? AppColors.textPrimary : AppColors.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: dayColor,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 5,
              height: 5,
              child: limeDot
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lime.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          children: [
            StatusDot('LOADING CALENDAR'),
            SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: 24,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surface,
                color: AppColors.lime,
                minHeight: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
