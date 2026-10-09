import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_config.dart';
import '../../core/theme/app_theme.dart';

/// Operator-only configuration panel.
///
/// This page is **not** wired into the user-facing navigation drawer /
/// sidebar. It exists for two reasons:
///
///   1. To hold controls that regular users should never see
///      (e.g. swapping the backend URL points the app at a different
///      server, which is an admin/operator concern, not a user one).
///   2. To give a future admin shell a place to land without touching
///      the user-facing settings page.
///
/// Access: deep-link only (e.g. `aetherix://admin`) or via a build
/// flag. See scripts/puku_worker.py / app.dart route registration.
class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage> {
  late final TextEditingController _apiCtrl;

  @override
  void initState() {
    super.initState();
    _apiCtrl = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiUrl = ref.watch(apiBaseUrlProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const MonoText(
          'ADMIN PANEL',
          color: AppColors.lime,
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              Container(width: 8, height: 1, color: AppColors.lime),
              const SizedBox(width: AppSpacing.xs),
              const MonoText(
                'API ENDPOINT',
                color: AppColors.lime,
                size: 11,
                letterSpacing: 1.4,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Changes the base URL the app talks to. Restart the app '
            'or pull-to-refresh to take effect.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _apiCtrl,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.api, size: 16),
              hintText: apiUrl,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined, size: 14),
            label: const Text('SAVE ENDPOINT'),
            onPressed: () async {
              await ref
                  .read(apiBaseUrlProvider.notifier)
                  .set(_apiCtrl.text.trim());
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API endpoint saved')),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(width: 8, height: 1, color: AppColors.lime),
              const SizedBox(width: AppSpacing.xs),
              const MonoText(
                'DIAGNOSTICS',
                color: AppColors.lime,
                size: 11,
                letterSpacing: 1.4,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(label: 'CURRENT ENDPOINT', value: apiUrl),
          const SizedBox(height: AppSpacing.xxs),
          const _InfoRow(label: 'BUILD', value: 'V1.1.0'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
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
