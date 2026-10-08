import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../features/archive/archive_page.dart';
import '../features/bookmarks/bookmarks_page.dart';
import '../features/feed/feed_page.dart';
import '../features/news/article_page.dart';
import '../features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(child: child, location: state.uri.path),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const FeedPage(),
          ),
          GoRoute(
            path: '/archive',
            builder: (_, __) => const ArchivePage(),
          ),
          GoRoute(
            path: '/bookmarks',
            builder: (_, __) => const BookmarksPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/article',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          if (id == null) {
            return const _BadArticleRoute();
          }
          return ArticlePage(articleId: int.parse(id));
        },
      ),
    ],
  );
});

class AetherixApp extends ConsumerWidget {
  const AetherixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final auth = ref.watch(authBootstrapProvider);
    return MaterialApp.router(
      title: 'Aetherix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        return auth.when(
          loading: () => const _SplashScreen(),
          error: (e, _) => _ErrorScreen(error: e.toString()),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AETHERIX',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: AppColors.lime,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: 32,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surface,
                color: AppColors.lime,
                minHeight: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const StatusDot('SYSTEM INITIALIZING'),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.critical, size: 48),
              const SizedBox(height: AppSpacing.md),
              const MonoText('CONNECTION ERROR', color: AppColors.critical),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.location});
  final Widget child;
  final String location;

  static const _nav = [
    _NavItem('/', Icons.dashboard_outlined, Icons.dashboard, 'Feed'),
    _NavItem(
      '/archive',
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      'Archive',
    ),
    _NavItem(
      '/bookmarks',
      Icons.bookmark_border,
      Icons.bookmark,
      'Bookmarks',
    ),
    _NavItem(
      '/settings',
      Icons.settings_outlined,
      Icons.settings,
      'Settings',
    ),
  ];

  bool _isActive(String path, String item) {
    if (item == '/') return location == '/' || location.isEmpty;
    return location.startsWith(item);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          if (wide) _Sidebar(items: _nav, isActive: _isActive),
          Expanded(
            child: Column(
              children: [
                if (!wide) _TopBar(items: _nav, isActive: _isActive),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadArticleRoute extends StatelessWidget {
  const _BadArticleRoute();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => context.go('/'),
        ),
        title: const Text('ARTICLE'),
      ),
      body: const Center(
        child: MonoText('ARTICLE ID MISSING', color: AppColors.critical),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.iconActive, this.label);
  final String path;
  final IconData icon;
  final IconData iconActive;
  final String label;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.isActive});
  final List<_NavItem> items;
  final bool Function(String path, String item) isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _BrandMark(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final n in items)
            _SidebarItem(
              item: n,
              active: isActive(n.path, n.path),
              onTap: () => context.go(n.path),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusDot('SYSTEM ONLINE'),
                SizedBox(height: AppSpacing.xs),
                MonoText('INTELLIGENCE FEED', size: 9, letterSpacing: 1.2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lime, width: 1.4),
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: const Center(
            child: Text(
              'A',
              style: TextStyle(
                color: AppColors.lime,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AETHERIX',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'SEE EVERYTHING.',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.lime : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.lime.withValues(alpha: 0.06) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? AppColors.lime : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(AppRadii.sharp),
        ),
        child: Row(
          children: [
            Icon(active ? item.iconActive : item.icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            MonoText(
              item.label.toUpperCase(),
              color: color,
              size: 11,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.items, required this.isActive});
  final List<_NavItem> items;
  final bool Function(String, String) isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const _BrandMark(),
          const Spacer(),
          for (final n in items)
            IconButton(
              icon: Icon(
                isActive(n.path, n.path) ? n.iconActive : n.icon,
                color: isActive(n.path, n.path)
                    ? AppColors.lime
                    : AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => context.go(n.path),
              tooltip: n.label,
            ),
        ],
      ),
    );
  }
}