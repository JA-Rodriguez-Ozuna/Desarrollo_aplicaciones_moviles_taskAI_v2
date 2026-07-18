import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

/// Thrown when a write falls back to the local Hive cache because
/// Firestore could not be reached, so the UI can surface it explicitly
/// instead of failing silently.
class TaskRepositoryException implements Exception {
  final String message;
  const TaskRepositoryException(this.message);

  @override
  String toString() => message;
}

class TaskRepository {
  final FirestoreService _firestore;
  final HiveService _hive;
  final SyncService _sync;

  TaskRepository(this._firestore, this._hive, this._sync);

  /// Streams tasks from Firestore. If Firestore errors out (offline,
  /// permission hiccup, etc.) it falls back to the last cache saved in
  /// Hive so previously-visible/offline-saved tasks don't just disappear.
  Stream<List<Task>> watchTasks(String userId) async* {
    try {
      await for (final List<Task> tasks in _firestore.getTasks(userId)) {
        yield tasks;
      }
    } catch (e) {
      debugPrint('[TaskRepository] watchTasks falling back to Hive cache: $e');
      yield _hive.getTasks();
    }
  }

  Future<void> addTask(Task task) async {
    try {
      await _firestore.addTask(task);
    } catch (_) {
      await _hive.saveTask(task);
      throw const TaskRepositoryException(
        'No se pudo sincronizar con la nube. La tarea se guardó localmente.',
      );
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _firestore.updateTask(task);
    } catch (_) {
      await _hive.saveTask(task);
      throw const TaskRepositoryException(
        'No se pudo sincronizar el cambio con la nube. Se guardó localmente.',
      );
    }
  }

  Future<void> deleteTask(String taskId, String userId) async {
    try {
      await _firestore.deleteTask(taskId, userId);
    } catch (_) {
      await _hive.deleteTask(taskId);
      throw const TaskRepositoryException(
        'No se pudo eliminar en la nube. Se eliminó localmente.',
      );
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
