import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../screens/camera_ai_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/task_form_screen.dart';
import '../screens/voice_screen.dart';
import '../widgets/scaffold_with_nav_bar.dart';

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder:
        (BuildContext context, Animation<double> animation,
                Animation<double> secondaryAnimation, Widget child) =>
            FadeTransition(opacity: animation, child: child),
  );
}

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _authSub;
  late final ProviderSubscription<bool?> _onboardingSub;

  _RouterNotifier(this._ref) {
    _authSub = _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _onboardingSub =
        _ref.listen(onboardingProvider, (_, _) => notifyListeners());
  }

  @override
  void dispose() {
    _authSub.close();
    _onboardingSub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final authAsync = ref.read(authStateProvider);

      // Firebase still restoring persisted session — don't redirect yet
      if (authAsync.isLoading) return null;

      final bool isLoggedIn = authAsync.valueOrNull != null;
      final String loc = state.matchedLocation;
      final bool isAuthPage = loc == '/login' || loc == '/register';

      if (!isLoggedIn && !isAuthPage) return '/login';
      if (!isLoggedIn) return null;

      // Logged in from here on — gate on onboarding once auth is resolved.
      final bool? onboardingCompleted = ref.read(onboardingProvider);
      if (onboardingCompleted == null) return null; // still restoring

      final bool isOnboardingPage = loc == '/onboarding';
      if (!onboardingCompleted && !isOnboardingPage) return '/onboarding';
      if (onboardingCompleted && (isAuthPage || isOnboardingPage)) return '/';
      return null;
    },
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const _ErrorScreen(),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/statistics',
                builder: (_, _) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/voice',
                builder: (_, _) => const VoiceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _fadePage(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/task/new',
        pageBuilder: (_, state) => _fadePage(state, const TaskFormScreen()),
      ),
      GoRoute(
        path: '/task/edit/:id',
        pageBuilder: (_, state) => _fadePage(
          state,
          TaskFormScreen(taskId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/qr-scan',
        pageBuilder: (_, state) => _fadePage(state, const CameraAiScreen()),
      ),
    ],
  );
});

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('404 — Ruta no encontrada',
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
