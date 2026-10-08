import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/article.dart';
import '../../services/news_service.dart';
import '../../widgets/article_card.dart';

/// Selected day in the Archive. ``null`` means no day selected — show
/// only the calendar. We default to *today* on first load.
final _selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Visible month in the Archive calendar.
final _visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Map of ``YYYY-MM-DD`` -> count of articles on that day (lazy cache).
final _dayCountsProvider =
    FutureProvider.family<Map<String, int>, ({DateTime from, DateTime to})>(
  (ref, range) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final svc = ref.watch(newsServiceProvider);
    final rows = await svc.list(
      filter: NewsListFilter(
        from: fmt.format(range.from),
        to: fmt.format(range.to),
        limit: 200,
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
          limit: 200,
        ),
      );
});

class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDayProvider);
    final visible = ref.watch(_visibleMonthProvider);

    // The counts map covers a wide window so the calendar can mark days
    // with dots. Pulling the whole month at once is fine for the dataset
    // size we expect. If articles grow huge we should page this.
    final counts = ref.watch(_dayCountsProvider((
      from: DateTime(visible.year, visible.month, 1),
      to: DateTime(visible.year, visible.month + 1, 0),
    )));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArchiveHeader(),
          _CalendarPane(
            visible: visible,
            selected: selected,
            countsAsync: counts,
            onSelect: (d) {
              ref.read(_selectedDayProvider.notifier).state = DateTime(
                d.year,
                d.month,
                d.day,
              );
            },
            onPrev: () {
              ref.read(_visibleMonthProvider.notifier).state =
                  DateTime(visible.year, visible.month - 1, 1);
            },
            onNext: () {
              ref.read(_visibleMonthProvider.notifier).state =
                  DateTime(visible.year, visible.month + 1, 1);
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: selected == null
                ? const _EmptyCalendar()
                : _DayPane(day: selected),
          ),
        ],
      ),
    );
  }
}

class _ArchiveHeader extends StatelessWidget {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          StatusDot('HISTORICAL INTELLIGENCE'),
          SizedBox(height: AppSpacing.xs),
          Text(
            'ARCHIVE',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Pick a day. Read what happened.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPane extends StatelessWidget {
  const _CalendarPane({
    required this.visible,
    required this.selected,
    required this.countsAsync,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime visible;
  final DateTime? selected;
  final AsyncValue<Map<String, int>> countsAsync;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _weekdayLabels = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(visible);
    final firstWeekday = DateTime(visible.year, visible.month, 1).weekday;
    // Monday-first grid: convert DateTime.weekday (1=Mon..7=Sun).
    final leadingBlanks = firstWeekday - 1;
    final daysInMonth = DateTime(visible.year, visible.month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      color: AppColors.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: onPrev,
              ),
              Expanded(
                child: Center(
                  child: MonoText(
                    monthLabel.toUpperCase(),
                    color: AppColors.textPrimary,
                    size: 12,
                    weight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // weekday header
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
                style: const TextStyle(color: AppColors.critical, fontSize: 12),
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
      childAspectRatio: 1.05,
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

class _DayPane extends ConsumerWidget {
  const _DayPane({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dayArticlesProvider(day));
    final headerFmt = DateFormat.yMMMMEEEEd();
    final bodyFmt = DateFormat('EEE MMM d  HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: StatusDot('LOADING DAY')),
            error: (e, _) => Center(
              child: Text(
                '$e',
                style: const TextStyle(color: AppColors.critical),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_busy,
                          size: 32, color: AppColors.textMuted),
                      const SizedBox(height: AppSpacing.sm),
                      MonoText(
                        'NO INTELLIGENCE ON ${bodyFmt.format(day).toUpperCase()}',
                        color: AppColors.textMuted,
                        size: 10,
                        letterSpacing: 1.2,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => ArticleCard(article: list[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: MonoText(
        'SELECT A DAY',
        color: AppColors.textMuted,
        size: 11,
        letterSpacing: 1.4,
      ),
    );
  }
}