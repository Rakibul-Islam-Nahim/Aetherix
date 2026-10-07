import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/news/latest_page.dart';
import '../features/news/article_page.dart';
import '../features/categories/categories_page.dart';
import '../features/bookmarks/bookmarks_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../core/theme/app_theme.dart';

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
    return MaterialApp.router(
      title: 'Aetherix',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
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
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Latest'),
          NavigationDestination(icon: Icon(Icons.category_outlined), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'Bookmarks'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
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
              context.go('/settings');
              break;
          }
        },
      ),
    );
  }
}