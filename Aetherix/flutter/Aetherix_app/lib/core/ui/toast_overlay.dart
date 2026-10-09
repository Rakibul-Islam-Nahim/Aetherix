import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'toast.dart';

/// Sits at the top of the screen and renders the current queue of
/// [Toast]s as sliding banners. Mounted once via `MaterialApp.builder`
/// in `app.dart`.
class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastControllerProvider);
    return Stack(
      children: [
        child,
        if (toasts.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in toasts)
                      _ToastBanner(
                        key: ValueKey(identical(t, t) ? t.hashCode : t),
                        toast: t,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastBanner extends ConsumerStatefulWidget {
  const _ToastBanner({super.key, required this.toast});
  final Toast toast;

  @override
  ConsumerState<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends ConsumerState<_ToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();
    _scheduleDismiss();
  }

  @override
  void didUpdateWidget(covariant _ToastBanner old) {
    super.didUpdateWidget(old);
    if (!identical(old.toast, widget.toast)) {
      // Different toast with the same widget slot — keep the timer
      // running; new toast already has its own controller if remounted.
    }
  }

  void _scheduleDismiss() {
    _autoDismiss?.cancel();
    final d = widget.toast.duration;
    if (d > Duration.zero) {
      _autoDismiss = Timer(d, _dismiss);
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ac.reverse();
    if (!mounted) return;
    ref.read(toastControllerProvider.notifier).dismiss(widget.toast);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _ac.dispose();
    super.dispose();
  }

  ({Color accent, Color bg, Color fg}) _palette() {
    switch (widget.toast.kind) {
      case ToastKind.error:
        return (
          accent: AppColors.danger,
          bg: AppColors.dangerDim,
          fg: AppColors.textPrimary,
        );
      case ToastKind.success:
        return (
          accent: AppColors.lime,
          bg: AppColors.successDim,
          fg: AppColors.textPrimary,
        );
      case ToastKind.warning:
        return (
          accent: AppColors.warning,
          bg: AppColors.warningDim,
          fg: AppColors.textPrimary,
        );
      case ToastKind.info:
        return (
          accent: AppColors.info,
          bg: AppColors.surfaceElevated,
          fg: AppColors.textPrimary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: p.bg,
            elevation: 4,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: InkWell(
              onTap: _dismiss,
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: p.accent, width: 1),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left accent bar — the Aetherix "branded" look.
                    Container(
                      width: 3,
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadii.small),
                          bottomLeft: Radius.circular(AppRadii.small),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(widget.toast.icon, size: 16, color: p.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.toast.title,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: p.fg,
                              ),
                            ),
                            if (widget.toast.body != null &&
                                widget.toast.body!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.toast.body!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      color: AppColors.textMuted,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: _dismiss,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
