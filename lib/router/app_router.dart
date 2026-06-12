import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/qr_scan_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/task_form_screen.dart';
import '../screens/voice_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (BuildContext context, GoRouterState state) =>
      const _ErrorScreen(),
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/task/new',
      builder: (BuildContext context, GoRouterState state) =>
          const TaskFormScreen(),
    ),
    GoRoute(
      path: '/task/edit/:id',
      builder: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id']!;
        return TaskFormScreen(taskId: id);
      },
    ),
    GoRoute(
      path: '/statistics',
      builder: (BuildContext context, GoRouterState state) =>
          const StatisticsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: '/voice',
      builder: (BuildContext context, GoRouterState state) =>
          const VoiceScreen(),
    ),
    GoRoute(
      path: '/qr-scan',
      builder: (BuildContext context, GoRouterState state) =>
          const QRScanScreen(),
    ),
  ],
);

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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              '404 — Ruta no encontrada',
              style: TextStyle(fontSize: 20),
            ),
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
