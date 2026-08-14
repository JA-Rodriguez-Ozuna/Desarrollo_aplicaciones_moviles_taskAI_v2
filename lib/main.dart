import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'router/app_router.dart';
import 'services/ad_service.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/plan_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Android, google-services.json hace que el SDK nativo de Firebase se
  // auto-inicialice antes de que corra este código Dart, así que Firebase.apps
  // (el caché del lado Dart) sigue vacío aunque la app nativa "[DEFAULT]" ya
  // exista. initializeApp() lanza duplicate-app en ese caso; es seguro
  // ignorarlo porque la app nativa ya está configurada con las mismas
  // opciones de firebase_options.dart.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Firebase AI Logic exige App Check activo, incluso en desarrollo.
  // El proveedor debug emite un token de depuración que hay que registrar
  // manualmente en la consola de Firebase (App Check > Manage debug tokens);
  // en release se usa Play Integrity, que no requiere ese paso manual.
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  }

  final HiveService hive = HiveService();
  await hive.init();

  // Inicializaciones no críticas: nunca deben bloquear el arranque.
  try {
    await AdService.initialize();
  } catch (_) {}

  try {
    await PlanService.resetDailyCountersIfNeeded();
  } catch (_) {}

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
