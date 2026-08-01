import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_ai/models/task.dart';
import 'package:task_ai/repositories/task_repository.dart';
import 'package:task_ai/services/firestore_service.dart';
import 'package:task_ai/services/hive_service.dart';
import 'package:task_ai/services/sync_service.dart';

class FakeFirestoreService implements FirestoreService {
  final List<Task> _tasks;
  final StreamController<List<Task>> _controller =
      StreamController<List<Task>>.broadcast();

  FakeFirestoreService({List<Task>? tasks})
      : _tasks = List<Task>.from(tasks ?? <Task>[]);

  void dispose() => _controller.close();

  Task? lastAdded;
  Task? lastUpdated;
  String? lastDeletedId;

  @override
  Stream<List<Task>> getTasks(String userId) async* {
    yield List<Task>.from(_tasks);
    yield* _controller.stream;
  }

  @override
  Future<List<Task>> fetchTasksOnce(String userId) async =>
      List<Task>.from(_tasks);

  @override
  Future<void> addTask(Task task) async {
    lastAdded = task;
    _tasks.add(task);
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> updateTask(Task task) async {
    lastUpdated = task;
    final int idx = _tasks.indexWhere((Task t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> deleteTask(String taskId, String userId) async {
    lastDeletedId = taskId;
    _tasks.removeWhere((Task t) => t.id == taskId);
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> syncLocalTasks(String userId, List<Task> localTasks) async {
    for (final Task t in localTasks) {
      _tasks.add(t);
    }
  }
}

class FakeHiveService implements HiveService {
  final List<Task> _cache = [];

  Task? lastSaved;
  String? lastDeletedId;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _cache
      ..clear()
      ..addAll(tasks);
  }

  @override
  List<Task> getTasks() => List<Task>.from(_cache);

  @override
  Future<void> saveTask(Task task) async {
    lastSaved = task;
    _cache.add(task);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    lastDeletedId = taskId;
    _cache.removeWhere((Task t) => t.id == taskId);
  }

  @override
  Future<void> clearTasks() async => _cache.clear();
}

class FakeSyncService implements SyncService {

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => true;

  @override
  Future<void> syncPendingTasks(String userId) async {}
}

Task _task({
  String id = 'task-1',
  String userId = 'user-1',
  bool isCompleted = false,
}) =>
    Task(
      id: id,
      title: 'Tarea $id',
      description: '',
      category: TaskCategory.trabajo,
      priority: TaskPriority.media,
      dueDate: DateTime(2026, 12, 31),
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
      userId: userId,
    );

void main() {
  late FakeFirestoreService fsService;
  late FakeHiveService hiveService;
  late FakeSyncService syncService;
  late TaskRepository repo;

  setUp(() {
    fsService = FakeFirestoreService();
    hiveService = FakeHiveService();
    syncService = FakeSyncService();
    repo = TaskRepository(fsService, hiveService, syncService);
  });

  tearDown(() => fsService.dispose());

  group('watchTasks', () {
    test('emits list of tasks from FirestoreService', () async {
      final task = _task();
      final fs = FakeFirestoreService(tasks: [task]);
      final r = TaskRepository(fs, hiveService, syncService);
      addTearDown(fs.dispose);

      final List<Task> result = await r.watchTasks('user-1').first;

      expect(result, hasLength(1));
      expect(result.first.id, task.id);
    });

    test('falls back to HiveService when Firestore throws', () async {
      final cachedTask = _task(id: 'cached');
      await hiveService.saveTask(cachedTask);

      final errorFs = _ThrowingFirestoreService();
      final r = TaskRepository(errorFs, hiveService, syncService);

      final List<Task> result = await r.watchTasks('user-1').first;

      expect(result, hasLength(1));
      expect(result.first.id, 'cached');
    });

    test('returns stream (not a single value)', () {
      final stream = repo.watchTasks('user-1');
      expect(stream, isA<Stream<List<Task>>>());
    });
  });

  group('addTask', () {
    test('delegates to FirestoreService.addTask with correct task', () async {
      final task = _task(userId: 'user-1');
      await repo.addTask(task);

      expect(fsService.lastAdded?.id, task.id);
      expect(fsService.lastAdded?.userId, 'user-1');
    });

    test('task contains all model fields after addTask', () async {
      final task = _task(id: 'abc-123', userId: 'user-X');
      await repo.addTask(task);

      final added = fsService.lastAdded!;
      expect(added.id, 'abc-123');
      expect(added.title, task.title);
      expect(added.category, task.category);
      expect(added.priority, task.priority);
      expect(added.isCompleted, task.isCompleted);
    });

    test('falls back to Hive and throws TaskRepositoryException on Firestore error', () async {
      final errorFs = _ThrowingFirestoreService();
      final r = TaskRepository(errorFs, hiveService, syncService);
      final task = _task();

      await expectLater(
        r.addTask(task),
        throwsA(isA<TaskRepositoryException>()),
      );

      expect(hiveService.lastSaved?.id, task.id);
    });
  });

  group('updateTask', () {
    test('delegates to FirestoreService.updateTask', () async {
      final task = _task();
      await repo.addTask(task);

      final updated = task.copyWith(isCompleted: true);
      await repo.updateTask(updated);

      expect(fsService.lastUpdated?.isCompleted, isTrue);
      expect(fsService.lastUpdated?.id, task.id);
    });

    test('falls back to Hive on Firestore error', () async {
      final errorFs = _ThrowingFirestoreService();
      final r = TaskRepository(errorFs, hiveService, syncService);
      final task = _task();

      await expectLater(
        r.updateTask(task),
        throwsA(isA<TaskRepositoryException>()),
      );
      expect(hiveService.lastSaved?.id, task.id);
    });
  });

  group('deleteTask', () {
    test('delegates to FirestoreService.deleteTask with correct ids', () async {
      final task = _task(id: 'del-1', userId: 'user-1');
      await repo.addTask(task);
      await repo.deleteTask('del-1', 'user-1');

      expect(fsService.lastDeletedId, 'del-1');
    });

    test('falls back to Hive on Firestore error', () async {
      final cachedTask = _task(id: 'del-2');
      await hiveService.saveTask(cachedTask);

      final errorFs = _ThrowingFirestoreService();
      final r = TaskRepository(errorFs, hiveService, syncService);

      await expectLater(
        r.deleteTask('del-2', 'user-1'),
        throwsA(isA<TaskRepositoryException>()),
      );
      expect(hiveService.lastDeletedId, 'del-2');
    });
  });

  group('fetchTasksOnce', () {
    test('returns tasks from FirestoreService', () async {
      final task = _task();
      final fs = FakeFirestoreService(tasks: [task]);
      final r = TaskRepository(fs, hiveService, syncService);
      addTearDown(fs.dispose);

      final result = await r.fetchTasksOnce('user-1');
      expect(result.first.id, task.id);
    });

    test('falls back to Hive when Firestore throws', () async {
      final cached = _task(id: 'cached-once');
      await hiveService.saveTask(cached);

      final errorFs = _ThrowingFirestoreService();
      final r = TaskRepository(errorFs, hiveService, syncService);

      final result = await r.fetchTasksOnce('user-1');
      expect(result.first.id, 'cached-once');
    });
  });
}

class _ThrowingFirestoreService implements FirestoreService {
  @override
  Stream<List<Task>> getTasks(String userId) =>
      Stream<List<Task>>.error(Exception('Firestore unavailable'));

  @override
  Future<List<Task>> fetchTasksOnce(String userId) =>
      Future<List<Task>>.error(Exception('Firestore unavailable'));

  @override
  Future<void> addTask(Task task) =>
      Future<void>.error(Exception('Firestore unavailable'));

  @override
  Future<void> updateTask(Task task) =>
      Future<void>.error(Exception('Firestore unavailable'));

  @override
  Future<void> deleteTask(String taskId, String userId) =>
      Future<void>.error(Exception('Firestore unavailable'));

  @override
  Future<void> syncLocalTasks(String userId, List<Task> localTasks) async {}
}
