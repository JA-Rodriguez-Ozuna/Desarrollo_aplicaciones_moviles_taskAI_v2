import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'task_reminders';
  static const String _channelName = 'Recordatorios de tareas';
  static const String _channelDescription =
      'Avisos de tareas universitarias próximas a vencer';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@drawable/ic_notification',
  );

  static const NotificationDetails _notificationDetails =
      NotificationDetails(android: _androidDetails);

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // POST_NOTIFICATIONS es un permiso runtime en Android 13+ (declararlo
    // en el Manifest no alcanza); sin pedirlo, las notificaciones se
    // descartan en silencio aunque la programación de alarmas funcione
    // bien — no lanza ninguna excepción, como los demás permisos.
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Both reminders for a task derive their id from taskId.hashCode, offset
  /// so the 24h and 1h notifications get distinct ids for the same task.
  static int _idFor(String taskId, int offset) =>
      (taskId.hashCode & 0x7fffffff) + offset;

  static Future<void> scheduleTaskReminder(Task task) async {
    final DateTime now = DateTime.now();
    final DateTime dayBefore =
        task.dueDate.subtract(const Duration(hours: 24));
    final DateTime hourBefore =
        task.dueDate.subtract(const Duration(hours: 1));

    bool anyScheduled = false;

    if (dayBefore.isAfter(now)) {
      await _schedule(
        id: _idFor(task.id, 0),
        title: '⏰ Tarea próxima a vencer',
        body: '${task.title} vence mañana',
        scheduledDate: dayBefore,
      );
      anyScheduled = true;
    } else {
      debugPrint('Notificación omitida — tiempo ya pasado: $dayBefore');
    }

    if (hourBefore.isAfter(now)) {
      await _schedule(
        id: _idFor(task.id, 1),
        title: '🚨 Tarea urgente',
        body: '${task.title} vence en 1 hora',
        scheduledDate: hourBefore,
      );
      anyScheduled = true;
    } else {
      debugPrint('Notificación omitida — tiempo ya pasado: $hourBefore');
    }

    // Ambos recordatorios ya pasaron pero la tarea todavía no vence: avisa
    // de una vez en lugar de dejar la tarea sin ningún recordatorio.
    if (!anyScheduled && task.dueDate.isAfter(now)) {
      await _showImmediate(
        id: _idFor(task.id, 2),
        title: '⚡ Tarea próxima',
        body: '${task.title} vence pronto',
      );
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[NotificationService] schedule error: $e');
    }
  }

  static Future<void> _showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(id, title, body, _notificationDetails);
    } catch (e) {
      debugPrint('[NotificationService] show error: $e');
    }
  }

  static Future<void> cancelTaskReminder(String taskId) async {
    try {
      await _plugin.cancel(_idFor(taskId, 0));
      await _plugin.cancel(_idFor(taskId, 1));
      await _plugin.cancel(_idFor(taskId, 2));
    } catch (e) {
      debugPrint('[NotificationService] cancel error: $e');
    }
  }

  static Future<void> cancelAllReminders() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAll error: $e');
    }
  }
}
