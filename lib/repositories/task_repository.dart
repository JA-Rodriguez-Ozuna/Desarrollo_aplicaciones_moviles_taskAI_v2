import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

class TaskRepository {
  final FirestoreService _firestore;
  final HiveService _hive;
  final SyncService _sync;

  TaskRepository({
    required FirestoreService firestore,
    required HiveService hive,
    required SyncService sync,
  })  : _firestore = firestore,
        _hive = hive,
        _sync = sync;

  Stream<List<Task>> watchTasks(String userId) =>
      _firestore.getTasks(userId);

  Future<void> addTask(Task task) async {
    if (await _sync.isOnline()) {
      await _firestore.addTask(task);
    } else {
      await _hive.saveTask(task);
    }
  }

  Future<void> updateTask(Task task) async {
    if (await _sync.isOnline()) {
      await _firestore.updateTask(task);
    } else {
      await _hive.saveTask(task);
    }
  }

  Future<void> deleteTask(String taskId, String userId) async {
    if (await _sync.isOnline()) {
      await _firestore.deleteTask(taskId, userId);
    } else {
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
      firestore: ref.read(_firestoreServiceProvider),
      hive: ref.read(_hiveServiceProvider),
      sync: ref.read(_syncServiceProvider),
    ));
