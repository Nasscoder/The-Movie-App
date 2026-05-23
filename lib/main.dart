import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'presentation/home_screen.dart';
import 'presentation/watchlist_screen.dart';
import 'presentation/detail_screen.dart';
import 'presentation/mood_matcher_screen.dart';
import 'presentation/stats_screen.dart';

import 'data/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MediaVaultApp()));
}

class MediaVaultApp extends StatelessWidget {
  const MediaVaultApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MainScaffold(child: HomeScreen(), currentIndex: 0),
        ),
        GoRoute(
          path: '/watchlist',
          builder: (context, state) => const MainScaffold(child: WatchlistScreen(), currentIndex: 1),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const MainScaffold(child: StatsScreen(), currentIndex: 2),
        ),
        GoRoute(
          path: '/mood',
          builder: (context, state) => const MoodMatcherScreen(),
        ),
        GoRoute(
          path: '/details',
          builder: (context, state) {
            final media = state.extra as Media;
            return DetailScreen(media: media);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Media Vault',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Scaffolds the bottom navigation bar across main tabs
class MainScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainScaffold({Key? key, required this.child, required this.currentIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/watchlist');
              break;
            case 2:
              context.go('/stats');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Watchlist'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}
