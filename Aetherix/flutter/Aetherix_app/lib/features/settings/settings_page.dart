import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alerts/alert_delivery.dart';
import '../../core/alerts/alert_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/toast.dart';
import '../admin/admin_login_page.dart';

/// User-facing settings. **Only** contains alert preferences — the API
/// endpoint and other operator-only knobs have moved to the admin
/// panel (see features/admin/admin_panel_page.dart).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPreferencesProvider);
    final ctrl = ref.read(alertPreferencesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.lg),

          // ── Master switch ────────────────────────────────────────────
          const _Section(title: 'ALERTS'),
          const SizedBox(height: AppSpacing.xs),
          _AlertMasterTile(
            enabled: prefs.enabled,
            onChanged: ctrl.setEnabled,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Per-tag toggles ──────────────────────────────────────────
          const _Section(title: 'TAGS'),
          const SizedBox(height: AppSpacing.xs),
          MonoText(
            'NOTIFY ME ONLY FOR ARTICLES TAGGED WITH:',
            color: AppColors.textMuted,
            size: 10,
            letterSpacing: 1.2,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final t in AlertTag.values) ...[
            _TagTile(
              tag: t,
              selected: prefs.enabledTags.contains(t),
              onChanged: (_) => ctrl.toggleTag(t),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          const SizedBox(height: AppSpacing.lg),

          // ── Minimum importance ───────────────────────────────────────
          const _Section(title: 'MIN IMPORTANCE'),
          const SizedBox(height: AppSpacing.xs),
          MonoText(
            'ONLY ALERT ME WHEN AN ARTICLE IS AT OR ABOVE:',
            color: AppColors.textMuted,
            size: 10,
            letterSpacing: 1.2,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TierPicker(
            current: prefs.minImportance,
            onChanged: ctrl.setMinImportance,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Reset / About ────────────────────────────────────────────
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt, size: 14),
                label: const Text('RESET TO DEFAULTS'),
                onPressed: () async {
                  await ctrl.reset();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alert preferences reset'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Section(title: 'ABOUT'),
          const SizedBox(height: AppSpacing.xs),
          const _SecretVersionTile(
            icon: Icons.bolt_outlined,
            label: 'AETHERIX',
            value: 'V1.1.0',
          ),
          const SizedBox(height: AppSpacing.xxs),
          _AboutTile(
            icon: Icons.notifications_active_outlined,
            label: 'ACTIVE FILTER',
            value: _summarize(prefs),
          ),
        ],
      ),
    );
  }

  static String _summarize(AlertPreferences p) {
    if (!p.enabled) return 'DISABLED';
    final n = p.enabledTags.length;
    final tagPart = n == 0 ? 'no tags' : '$n tag${n == 1 ? '' : 's'}';
    return '${p.minImportance.label} & $tagPart';
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusDot('CONFIGURATION'),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 2),
        MonoText(
          'ALERT PREFERENCES',
          color: AppColors.textMuted,
          size: 10,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
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

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoText(
                  label,
                  color: AppColors.textPrimary,
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.lime,
          ),
        ],
      ),
    );
  }
}

/// Master "ENABLE ALERTS" switch. When the user turns it ON, asks for
/// POST_NOTIFICATIONS permission the first time only. If the user
/// denies, we revert the switch and surface a warning banner telling
/// them how to fix it in system settings.
class _AlertMasterTile extends ConsumerStatefulWidget {
  const _AlertMasterTile({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  ConsumerState<_AlertMasterTile> createState() => _AlertMasterTileState();
}

class _AlertMasterTileState extends ConsumerState<_AlertMasterTile> {
  bool _busy = false;

  Future<void> _onChanged(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) {
        // Turning ON — gate on OS permission.
        final result = await ref.read(alertDeliveryProvider).ensurePermission();
        if (result == NotificationAskResult.denied) {
          // Permission denied (or already denied previously). Show a
          // banner explaining how to fix, but still leave alerts ON
          // so the in-app filtering is active for when the user
          // grants the permission later.
          if (mounted) {
            showWarningToast(
              ref,
              'NOTIFICATIONS BLOCKED',
              body:
                  'Enable in Android Settings → Apps → Aetherix → Notifications.',
            );
          }
        }
      }
      // Persist the new value either way.
      widget.onChanged(v);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoText(
                  'ENABLE ALERTS',
                  color: AppColors.textPrimary,
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Master switch. Background alerts require notification permission.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // _busy flag isn't visually obvious on the switch itself
          // (Android renders its own ripple), so the user gets
          // immediate feedback via the toast above. No separate
          // spinner needed.
          Switch.adaptive(
            value: widget.enabled,
            onChanged: _busy ? null : _onChanged,
            activeColor: AppColors.lime,
          ),
        ],
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.selected,
    required this.onChanged,
  });
  final AlertTag tag;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.lime.withValues(alpha: 0.05)
            : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.lime : AppColors.border,
          width: selected ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: selected ? AppColors.lime : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: MonoText(
              tag.label.toUpperCase(),
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
              size: 12,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          Switch.adaptive(
            value: selected,
            onChanged: onChanged,
            activeColor: AppColors.lime,
          ),
        ],
      ),
    );
  }
}

class _TierPicker extends StatelessWidget {
  const _TierPicker({required this.current, required this.onChanged});
  final ImportanceTier current;
  final ValueChanged<ImportanceTier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in ImportanceTier.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: t == ImportanceTier.values.last ? 0 : AppSpacing.xs,
              ),
              child: _TierChip(
                tier: t,
                selected: t == current,
                onTap: () => onChanged(t),
              ),
            ),
          ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.tier,
    required this.selected,
    required this.onTap,
  });
  final ImportanceTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tier.color : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? tier.color.withValues(alpha: 0.10)
              : AppColors.surface,
          border: Border.all(
            color: selected ? tier.color : AppColors.border,
            width: selected ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Center(
          child: MonoText(
            tier.label,
            color: color,
            size: 10,
            weight: selected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.lime),
          const SizedBox(width: AppSpacing.sm),
          MonoText(label, color: AppColors.textMuted, size: 11),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// About row that doubles as the secret entry into the admin panel.
///
/// Seven taps within [_tapWindow] open [AdminLoginPage]. Anything less
/// (or too slow) just resets silently — there is no visible state until
/// the threshold is hit, so the gesture stays inconspicuous in normal
/// use.
class _SecretVersionTile extends StatefulWidget {
  const _SecretVersionTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  static const int _tapsRequired = 7;
  static const Duration _tapWindow = Duration(seconds: 3);

  @override
  State<_SecretVersionTile> createState() => _SecretVersionTileState();
}

class _SecretVersionTileState extends State<_SecretVersionTile> {
  int _count = 0;
  DateTime? _firstTapAt;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > _SecretVersionTile._tapWindow) {
      _firstTapAt = now;
      _count = 1;
    } else {
      _count += 1;
    }
    _resetTimer?.cancel();
    _resetTimer = Timer(_SecretVersionTile._tapWindow, _reset);
    if (_count >= _SecretVersionTile._tapsRequired) {
      _reset();
      _openAdmin();
    }
  }

  void _reset() {
    _resetTimer?.cancel();
    _resetTimer = null;
    if (_count != 0 || _firstTapAt != null) {
      setState(() {
        _count = 0;
        _firstTapAt = null;
      });
    }
  }

  Future<void> _openAdmin() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 14, color: AppColors.lime),
            const SizedBox(width: AppSpacing.sm),
            MonoText(widget.label, color: AppColors.textMuted, size: 11),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
