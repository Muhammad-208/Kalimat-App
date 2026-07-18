import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/result/word_result_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/comparison/comparison_screen.dart';
import 'features/verses/verses_screen.dart';
import 'features/auth/auth_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    GoRoute(
      path: '/root/:query',
      builder: (_, state) =>
          WordResultScreen(query: state.pathParameters['query']!),
    ),
    GoRoute(
      path: '/verses/:rootId',
      builder: (_, state) => VersesScreen(
          rootId: int.parse(state.pathParameters['rootId']!)),
    ),
    GoRoute(
      path: '/compare/:a/:b',
      builder: (_, state) => ComparisonScreen(
        rootA: state.pathParameters['a']!,
        rootB: state.pathParameters['b']!,
      ),
    ),
    // TODO: '/admin'  → editor panel (screen 6) — keep out of public build
  ],
);
