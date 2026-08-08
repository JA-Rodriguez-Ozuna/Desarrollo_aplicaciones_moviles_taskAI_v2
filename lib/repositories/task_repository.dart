import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

class TaskRepository {
  final FirestoreService _firestore;
  final HiveService _hive;
  final SyncService _sync;

  TaskRepository(this._firestore, this._hive, this._sync);

  Stream<List<Task>> watchTasks(String userId) =>
      _firestore.getTasks(userId);

  Future<void> addTask(Task task) async {
    try {
      await _firestore.addTask(task);
    } catch (_) {
      await _hive.saveTask(task);
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _firestore.updateTask(task);
    } catch (_) {
      await _hive.saveTask(task);
    }
  }

  Future<void> deleteTask(String taskId, String userId) async {
    try {
      await _firestore.deleteTask(taskId, userId);
    } catch (_) {
      await _hive.deleteTask(taskId);
    }
  }

  Future<void> syncOnReconnect(String userId) =>
      _sync.syncPendingTasks(userId);
}

final _firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

final _hiveServiceProvider = Provider<HiveService>(
  (_) => HiveService(),
);

final _syncServiceProvider = Provider<SyncService>((ref) => SyncService(
      ref.read(_firestoreServiceProvider),
      ref.read(_hiveServiceProvider),
    ));

final taskRepositoryProvider = Provider<TaskRepository>((ref) => TaskRepository(
      ref.read(_firestoreServiceProvider),
      ref.read(_hiveServiceProvider),
      ref.read(_syncServiceProvider),
    ));
