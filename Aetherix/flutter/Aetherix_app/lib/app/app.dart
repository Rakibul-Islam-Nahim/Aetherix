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
import '../widgets/hive_effects.dart';

/// Shared page transition: fade + small slide. Keeps the eye on the
/// content instead of a hard swap.
CustomTransitionPage<T> _fadePage<T>({
  required LocalKey key,
  required Widget Function(BuildContext) childBuilder,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: _Deferred(childBuilder: childBuilder),
    transitionsBuilder: (context, animation, secondary, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: t,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(t),
          child: child,
        ),
      );
    },
  );
}

class _Deferred extends StatelessWidget {
  const _Deferred({required this.childBuilder});
  final Widget Function(BuildContext) childBuilder;
  @override
  Widget build(BuildContext context) => childBuilder(context);
}

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
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              childBuilder: (_) => const FeedPage(),
            ),
          ),
          GoRoute(
            path: '/archive',
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              childBuilder: (_) => const ArchivePage(),
            ),
          ),
          GoRoute(
            path: '/bookmarks',
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              childBuilder: (_) => const BookmarksPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _fadePage(
              key: state.pageKey,
              childBuilder: (_) => const SettingsPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/article',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'];
          if (id == null) {
            return _fadePage(
              key: state.pageKey,
              childBuilder: (_) => const _BadArticleRoute(),
            );
          }
          return _fadePage(
            key: state.pageKey,
            childBuilder: (_) => ArticlePage(articleId: int.parse(id)),
          );
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
        return HackerBackdrop(
          child: auth.when(
            loading: () => const _SplashScreen(),
            error: (e, _) => _ErrorScreen(error: e.toString()),
            data: (_) => child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _scale = CurvedAnimation(
      parent: _ctl,
      curve: Curves.easeOutCubic,
    ).drive(Tween<double>(begin: 0.7, end: 1.0));
    _fade = CurvedAnimation(
      parent: _ctl,
      curve: Curves.easeIn,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lime, width: 1.4),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lime.withValues(alpha: 0.18),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Image.asset(
                      'assets/images/Aetherix-Icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeTransition(
              opacity: _fade,
              child: const GlitchText(
                'AETHERIX',
                intensity: 1.4,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.lime,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: 64,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surface,
                color: AppColors.lime,
                minHeight: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const PulseGlow('SYSTEM INITIALIZING'),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 240,
              child: TerminalMarquee(
                text: 'AETHERIX :: CYBERSENTINEL :: OPS // AETHERIX :: ',
              ),
            ),
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

    // Mobile shell: a Scaffold whose drawer is the slide-in nav. Using
    // Scaffold's drawer (not a manual Stack) means we get the canonical
    // Android swipe-from-left edge gesture for free, plus the scrim
    // and focus-trap behavior users expect.
    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        // We add the body as a SafeArea so the top status bar (battery,
        // time) reserves space above the top bar, and the system gesture
        // bar reserves space below the content. This fixes the overlap
        // the user reported.
        body: SafeArea(
          top: false, // top is handled by _MobileTopBar's own SafeArea
          bottom: true,
          child: _MobileTopBar(
            isActive: _isActive,
            child: child,
            brand: const _BrandMark(),
          ),
        ),
        drawer: _MobileDrawer(items: _nav, isActive: _isActive),
        drawerEnableOpenDragGesture: true,
      );
    }

    // Wide layout: persistent left sidebar (unchanged).
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          _Sidebar(items: _nav, isActive: _isActive),
          Expanded(
            child: Column(
              children: [
                const SizedBox.shrink(),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lime, width: 1.2),
            borderRadius: BorderRadius.circular(AppRadii.small),
            color: AppColors.bgPrimary,
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: Image.asset(
              'assets/images/Aetherix-Icon.png',
              fit: BoxFit.contain,
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

/// Mobile (width < 720) top bar: hamburger left, brand centered, system
/// indicator right. Wrapped in SafeArea so the OS status bar (battery,
/// time, signal) reserves its own row above the bar instead of
/// overlapping the brand text.
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.child,
    required this.isActive,
    required this.brand,
  });

  final Widget child;
  final bool Function(String, String) isActive;
  final Widget brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.bgSecondary,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                // Hamburger — opens the slide-in nav drawer.
                Builder(
                  builder: (innerCtx) => IconButton(
                    icon: const Icon(
                      Icons.menu,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Open navigation',
                    onPressed: () => Scaffold.of(innerCtx).openDrawer(),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: brand),
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Notifications',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: MonoText(
                          'NO NEW ALERTS',
                          color: AppColors.textSecondary,
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Slide-in drawer used on mobile. Renders the same nav items as the
/// desktop sidebar, so users get one consistent mental model regardless
/// of device class.
class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.items, required this.isActive});
  final List<_NavItem> items;
  final bool Function(String path, String item) isActive;

  @override
  Widget build(BuildContext context) {
    // Material's Drawer already gives us the correct width, scrim, and
    // edge-swipe gesture. We just paint the contents.
    return Drawer(
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
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
              _DrawerItem(
                item: n,
                active: isActive(n.path, n.path),
                onTap: () {
                  Navigator.of(context).pop(); // close the drawer
                  context.go(n.path);
                },
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusDot('SYSTEM ONLINE'),
                  SizedBox(height: AppSpacing.xs),
                  MonoText(
                    'INTELLIGENCE FEED',
                    size: 9,
                    letterSpacing: 1.2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.lime : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lime.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? AppColors.lime : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? item.iconActive : item.icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            MonoText(
              item.label.toUpperCase(),
              color: color,
              size: 12,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ],
        ),
      ),
    );
  }
}