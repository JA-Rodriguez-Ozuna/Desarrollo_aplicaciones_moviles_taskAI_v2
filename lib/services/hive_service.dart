import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';

class HiveService {
  static const String _boxName = 'tasks_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  Box get _box => Hive.box(_boxName);

  Future<void> saveTasks(List<Task> tasks) async {
    await _box.clear();
    final Map<String, Map<String, dynamic>> entries = {
      for (final Task t in tasks) t.id: t.toMap(),
    };
    await _box.putAll(entries);
  }

  List<Task> getTasks() {
    return _box.values
        .map((v) => Task.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> saveTask(Task task) => _box.put(task.id, task.toMap());

  Future<void> deleteTask(String taskId) => _box.delete(taskId);

  Future<void> clearTasks() => _box.clear();
}
