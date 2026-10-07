import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../features/bookmarks/bookmarks_page.dart';
import '../features/categories/categories_page.dart';
import '../features/home/home_page.dart';
import '../features/news/article_page.dart';
import '../features/news/latest_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _Shell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: '/latest',
            builder: (_, __) => const LatestPage(),
          ),
          GoRoute(
            path: '/categories',
            builder: (_, __) => const CategoriesPage(),
          ),
          GoRoute(
            path: '/bookmarks',
            builder: (_, __) => const BookmarksPage(),
          ),
          GoRoute(
            path: '/search',
            builder: (_, __) => const SearchPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/article/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ArticlePage(articleId: id);
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Block UI until the device has a JWT. Once auth resolves, the
        // router shell takes over.
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
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Text(
                'Cannot reach the Aetherix backend.\n$error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'Latest',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/latest');
              break;
            case 2:
              context.go('/categories');
              break;
            case 3:
              context.go('/bookmarks');
              break;
            case 4:
              context.go('/search');
              break;
          }
        },
      ),
    );
  }
}