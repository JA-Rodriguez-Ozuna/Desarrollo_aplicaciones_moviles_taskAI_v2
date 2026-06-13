import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/qr_scan_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/task_form_screen.dart';
import '../screens/voice_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;

  _RouterNotifier(this._ref) {
    _sub = _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.close();
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
      if (isLoggedIn && isAuthPage) return '/';
      return null;
    },
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const _ErrorScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/task/new',
        builder: (_, _) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '/task/edit/:id',
        builder: (_, state) =>
            TaskFormScreen(taskId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/statistics',
        builder: (_, _) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/voice',
        builder: (_, _) => const VoiceScreen(),
      ),
      GoRoute(
        path: '/qr-scan',
        builder: (_, _) => const QRScanScreen(),
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
