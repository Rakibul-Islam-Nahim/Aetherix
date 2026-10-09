import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/admin/admin_api.dart';
import '../../core/admin/admin_session.dart';
import '../../core/network/dio_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/toast.dart';
import 'admin_login_page.dart';

/// Aetherix admin panel — operator-only.
///
/// Reachable from the Settings page by tapping the version number 7×.
/// All destructive actions (block / unblock / delete device) go
/// through the server-side admin endpoints and write to the database.
class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage> {
  late final TextEditingController _apiCtrl;
  Future<List<AdminDevice>>? _devicesFuture;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _apiCtrl = TextEditingController(text: ref.read(apiBaseUrlProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _devicesFuture = ref.read(adminApiProvider).listDevices();
    });
  }

  Future<void> _saveEndpoint() async {
    await ref
        .read(apiBaseUrlProvider.notifier)
        .set(_apiCtrl.text.trim());
    if (!mounted) return;
    showSuccessToast(ref, 'API ENDPOINT SAVED');
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await ref.read(adminSessionProvider).clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);
    if (!session.isAuthenticated) {
      // Session expired or cleared while we were on the page — bounce
      // back to login. Wrap in a post-frame so we don't try to push
      // during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminLoginPage()),
        );
      });
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const MonoText(
          'ADMIN PANEL',
          color: AppColors.lime,
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: 2,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: _loggingOut
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.lime,
                    ),
                  )
                : const Icon(Icons.logout, size: 18),
            onPressed: _loggingOut ? null : _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.bgSecondary,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            const _Section(title: 'API ENDPOINT'),
            const SizedBox(height: AppSpacing.xs),
            const MonoText(
              'BASE URL THIS APP TALKS TO. CHANGES TAKE EFFECT ON NEXT REQUEST.',
              color: AppColors.textMuted,
              size: 10,
              letterSpacing: 1.2,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _apiCtrl,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.api, size: 16),
                hintText: 'https://news.cybersentinel.top/api/v1',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined, size: 14),
              label: const Text('SAVE ENDPOINT'),
              onPressed: _saveEndpoint,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Section(title: 'CONNECTED DEVICES'),
            const SizedBox(height: AppSpacing.xs),
            const MonoText(
              'EVERY DEVICE THAT HAS REGISTERED. BLOCK DENIES FUTURE LOGIN; '
              'DELETE REMOVES THE DEVICE ROW (USER KEEPS BOOKMARKS).',
              color: AppColors.textMuted,
              size: 10,
              letterSpacing: 1.2,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DevicesList(
              future: _devicesFuture,
              onChanged: _refresh,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Section(title: 'DIAGNOSTICS'),
            const SizedBox(height: AppSpacing.xs),
            const _InfoRow(label: 'BUILD', value: 'V1.1.0'),
            const SizedBox(height: AppSpacing.xxs),
            const _InfoRow(
              label: 'BACKEND',
              value: 'Aetherix FastAPI + Postgres',
            ),
            const SizedBox(height: AppSpacing.xxs),
            const _InfoRow(label: 'ADMIN TOKEN TTL', value: '60 minutes'),
          ],
        ),
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

class _DevicesList extends ConsumerWidget {
  const _DevicesList({required this.future, required this.onChanged});
  final Future<List<AdminDevice>>? future;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AdminDevice>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: StatusDot('LOADING DEVICES')),
          );
        }
        if (snap.hasError) {
          return _ErrorTile(
            error: snap.error.toString(),
            onRetry: onChanged,
          );
        }
        final devices = snap.data ?? const <AdminDevice>[];
        if (devices.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: MonoText(
                'NO DEVICES REGISTERED',
                color: AppColors.textMuted,
                size: 11,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final d in devices) ...[
              _DeviceRow(device: d, onChanged: onChanged),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.critical),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoText(
            'FAILED TO LOAD DEVICES',
            color: AppColors.critical,
            size: 11,
            letterSpacing: 1.2,
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('RETRY'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({required this.device, required this.onChanged});
  final AdminDevice device;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = DateFormat('MMM d, HH:mm');
    final lastSeen = device.lastSeenAt;
    final blocked = device.userBlocked;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: blocked
            ? AppColors.critical.withValues(alpha: 0.05)
            : AppColors.surface,
        border: Border.all(
          color: blocked ? AppColors.critical : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(device.platform),
                size: 16,
                color: blocked ? AppColors.critical : AppColors.lime,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: MonoText(
                  device.displayName.toUpperCase(),
                  color: AppColors.textPrimary,
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              if (blocked) ...[
                const Icon(Icons.block, size: 14, color: AppColors.critical),
                const SizedBox(width: 4),
                const MonoText(
                  'BLOCKED',
                  color: AppColors.critical,
                  size: 9,
                  weight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          MonoText(
            'USER · ${device.username}  ·  LAST SEEN ${lastSeen == null ? '—' : ts.format(lastSeen.toLocal())}',
            color: AppColors.textMuted,
            size: 10,
            letterSpacing: 0.6,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (!blocked)
                _PillButton(
                  label: 'BLOCK',
                  color: AppColors.critical,
                  icon: Icons.block,
                  onPressed: () => _doAction(
                    context,
                    ref,
                    'Block ${device.displayName}?',
                    'This user will not be able to log in until unblocked.',
                    () => ref.read(adminApiProvider).block(device.id),
                  ),
                )
              else
                _PillButton(
                  label: 'UNBLOCK',
                  color: AppColors.lime,
                  icon: Icons.lock_open,
                  onPressed: () => _doAction(
                    context,
                    ref,
                    'Unblock ${device.displayName}?',
                    'This user will be able to log in again.',
                    () => ref.read(adminApiProvider).unblock(device.id),
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              _PillButton(
                label: 'DELETE',
                color: AppColors.warning,
                icon: Icons.delete_outline,
                onPressed: () => _doAction(
                  context,
                  ref,
                  'Delete device ${device.displayName}?',
                  'Removes this device from the database. The user '
                      'account and its bookmarks are kept. The device '
                      'will re-register transparently on next launch.',
                  () => ref.read(adminApiProvider).deleteDevice(device.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _doAction(
    BuildContext context,
    WidgetRef ref,
    String title,
    String body,
    Future<Object?> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: MonoText(
          title.toUpperCase(),
          color: AppColors.lime,
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        content: Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
      onChanged();
      // Note: the global Dio interceptor already surfaces a banner
      // with the full server detail on failure, so we don't double up
      // a snackbar here. We do, however, still want a confirmation
      // toast on success for block/unblock/delete.
      showSuccessToast(ref, 'ACTION COMPLETED');
    } on DioException catch (e) {
      if (!context.mounted) return;
      // The interceptor already posted a banner; this extra call uses
      // the same id so it won't duplicate. We re-call only to give a
      // short inline form-style summary if the banner was dismissed.
      showDioErrorToast(ref, e, id: 'admin.action');
    } catch (e) {
      if (!context.mounted) return;
      showErrorToast(ref, 'ACTION FAILED', body: e.toString());
    }
  }

  IconData _iconFor(String platform) {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.laptop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.laptop_chromebook;
      case 'web':
        return Icons.public;
      default:
        return Icons.devices_other;
    }
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppRadii.sharp),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            MonoText(
              label,
              color: color,
              size: 10,
              weight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ],
        ),
      ),
    );
  }
}
