import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/article.dart';
import '../services/news_service.dart';

/// Filter criteria applied to a list of articles. The tier + importance
/// predicates are applied client-side; ``tag`` is sent to the backend.
class FilterCriteria {
  const FilterCriteria({
    this.keyword = '',
    this.tag,
    this.minImportance = 0,
    this.tier,
  });

  final String keyword;
  final String? tag; // exact match (Cyber Security / Hacking / AI / Technology)
  final double minImportance;
  final ImportanceTier? tier;

  bool matches(
    ArticleSummary a, {
    String? summary,
    String? whatHappened,
  }) {
    final s = a.importanceScore ?? 0;
    if (s < minImportance) return false;
    if (tier != null && ImportanceTier.fromScore(a.importanceScore) != tier) {
      return false;
    }
    if (keyword.trim().isEmpty) return true;
    final q = keyword.toLowerCase();
    if (a.title.toLowerCase().contains(q)) return true;
    if (summary != null && summary.toLowerCase().contains(q)) return true;
    if (whatHappened != null && whatHappened.toLowerCase().contains(q)) {
      return true;
    }
    return false;
  }

  FilterCriteria copyWith({
    String? keyword,
    Object? tag = _sentinel,
    double? minImportance,
    Object? tier = _sentinel,
  }) =>
      FilterCriteria(
        keyword: keyword ?? this.keyword,
        tag: tag == _sentinel ? this.tag : tag as String?,
        minImportance: minImportance ?? this.minImportance,
        tier: tier == _sentinel ? this.tier : tier as ImportanceTier?,
      );

  static const _sentinel = Object();

  bool get isEmpty =>
      keyword.isEmpty && tag == null && minImportance == 0 && tier == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCriteria &&
        other.keyword == keyword &&
        other.tag == tag &&
        other.minImportance == minImportance &&
        other.tier == tier;
  }

  @override
  int get hashCode => Object.hash(keyword, tag, minImportance, tier);
}

class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    required this.criteria,
    required this.onChanged,
    this.onRefresh,
  });

  final FilterCriteria criteria;
  final ValueChanged<FilterCriteria> onChanged;

  /// Optional reload handler. When non-null a small refresh icon is
  /// rendered at the right end of the tag-chip row.
  final VoidCallback? onRefresh;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final TextEditingController _ctrl;
  late FilterCriteria _draft;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.criteria.keyword);
    _draft = widget.criteria;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            onChanged: (v) {
              _draft = _draft.copyWith(keyword: v);
              widget.onChanged(_draft);
            },
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'KEYWORD SEARCH',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Tag chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Pill(
                        label: 'ALL TAGS',
                        selected: _draft.tag == null,
                        color: AppColors.textSecondary,
                        onTap: () {
                          setState(() => _draft = _draft.copyWith(tag: null));
                          widget.onChanged(_draft);
                        },
                      ),
                      for (final t in kAetherixTags)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: _Pill(
                            label: t.toUpperCase(),
                            selected: _draft.tag == t,
                            color: AppColors.lime,
                            onTap: () {
                              setState(
                                () => _draft = _draft.copyWith(
                                  tag: _draft.tag == t ? null : t,
                                ),
                              );
                              widget.onChanged(_draft);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.onRefresh != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: AppColors.lime,
                  ),
                  tooltip: 'Refresh',
                  onPressed: widget.onRefresh,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Importance tier chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in const [
                  null,
                  ImportanceTier.critical,
                  ImportanceTier.high,
                  ImportanceTier.medium,
                  ImportanceTier.low,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _Pill(
                      label: t == null ? 'ALL' : t.label,
                      selected: _draft.tier == t,
                      color: t?.color ?? AppColors.textSecondary,
                      onTap: () {
                        setState(() => _draft = _draft.copyWith(tier: t));
                        widget.onChanged(_draft);
                      },
                    ),
                  ),
                if (!_draft.isEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('CLEAR'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _draft = const FilterCriteria());
                      widget.onChanged(_draft);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sharp),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.sharp),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            MonoText(
              label,
              color: selected ? color : AppColors.textMuted,
              size: 10,
              letterSpacing: 1.0,
              weight: FontWeight.w700,
            ),
          ],
        ),
      ),
    );
  }
}