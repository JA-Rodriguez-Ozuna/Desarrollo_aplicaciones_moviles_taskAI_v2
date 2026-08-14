import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'router/app_router.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Android, google-services.json hace que el SDK nativo de Firebase se
  // auto-inicialice antes de que corra este código Dart, así que
  // initializeApp() lanza duplicate-app; es seguro ignorarlo porque la app
  // nativa ya está configurada con las mismas opciones de firebase_options.dart.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Firebase AI Logic exige App Check activo, incluso en desarrollo.
  // El proveedor debug emite un token de depuración válido solo para
  // este build; en producción debe cambiarse a Play Integrity.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  final HiveService hive = HiveService();
  await hive.init();

  try {
    await NotificationService.initialize();
  } catch (_) {}

  runApp(const ProviderScope(child: TaskAIApp()));
}

class TaskAIApp extends ConsumerWidget {
  const TaskAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TaskAI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
