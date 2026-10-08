import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_config.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
    final now = DateFormat.yMMMd().add_Hms().format(DateTime.now());
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
          Column(
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
              MonoText('UPDATED $now', color: AppColors.textMuted, size: 10),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(title: 'API ENDPOINT'),
          const SizedBox(height: AppSpacing.xs),
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
          _Section(title: 'ABOUT'),
          const SizedBox(height: AppSpacing.xs),
          _AboutTile(
            icon: Icons.bolt_outlined,
            label: 'AETHERIX',
            value: 'v0.1.0',
          ),
          const SizedBox(height: AppSpacing.xxs),
          _AboutTile(
            icon: Icons.dns_outlined,
            label: 'BACKEND',
            value: apiUrl,
          ),
        ],
      ),
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