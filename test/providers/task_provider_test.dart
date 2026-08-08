import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_ai/models/task.dart';
import 'package:task_ai/providers/auth_provider.dart';
import 'package:task_ai/providers/task_provider.dart';
import 'package:task_ai/repositories/task_repository.dart';

class FakeTaskRepository implements TaskRepository {
  final List<Task> _tasks;
  final StreamController<List<Task>> _controller =
      StreamController<List<Task>>.broadcast();

  FakeTaskRepository({List<Task>? initialTasks})
      : _tasks = List<Task>.from(initialTasks ?? <Task>[]);

  void dispose() => _controller.close();

  @override
  Stream<List<Task>> watchTasks(String userId) async* {
    yield List<Task>.from(_tasks);
    yield* _controller.stream;
  }

  @override
  Future<List<Task>> fetchTasksOnce(String userId) async =>
      List<Task>.from(_tasks);

  @override
  Future<void> addTask(Task task) async {
    _tasks.add(task);
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> updateTask(Task task) async {
    final int idx = _tasks.indexWhere((Task t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> deleteTask(String taskId, String userId) async {
    _tasks.removeWhere((Task t) => t.id == taskId);
    _controller.add(List<Task>.from(_tasks));
  }

  @override
  Future<void> syncOnReconnect(String userId) async {}
}

Task _makeTask({
  String id = 't1',
  String title = 'Tarea de prueba',
  bool isCompleted = false,
  TaskCategory category = TaskCategory.trabajo,
  TaskPriority priority = TaskPriority.media,
}) =>
    Task(
      id: id,
      title: title,
      description: '',
      category: category,
      priority: priority,
      dueDate: DateTime(2026, 12, 31),
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
      userId: 'u1',
    );

void main() {
  late FakeTaskRepository fakeRepo;
  late TaskNotifier notifier;

  setUp(() {
    fakeRepo = FakeTaskRepository();
    notifier = TaskNotifier(fakeRepo, 'u1');
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  group('Estado inicial', () {
    test('tasks is empty before stream emits', () {
      expect(notifier.state.tasks, isEmpty);
    });

    test('isLoading starts as true with non-empty userId (checked before microtasks)', () {
      final freshRepo = FakeTaskRepository();
      final freshNotifier = TaskNotifier(freshRepo, 'u1');
      addTearDown(freshRepo.dispose);
      // Checked synchronously in the same frame — stream has not emitted yet
      expect(freshNotifier.state.isLoading, isTrue);
    });

    test('isLoading becomes false after stream emits', () async {
      await pumpEventQueue();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.tasks, isEmpty);
    });

    test('isLoading is false when userId is empty', () {
      final emptyRepo = FakeTaskRepository();
      final emptyNotifier = TaskNotifier(emptyRepo, '');
      addTearDown(emptyRepo.dispose);
      expect(emptyNotifier.state.isLoading, isFalse);
    });
  });

  group('addTask', () {
    test('adds task to state via stream re-emission', () async {
      await pumpEventQueue();
      final task = _makeTask();

      await notifier.addTask(task);
      await pumpEventQueue();

      expect(notifier.state.tasks, hasLength(1));
      expect(notifier.state.tasks.first.id, task.id);
    });

    test('task userId is stamped with notifier userId', () async {
      await pumpEventQueue();
      final task = _makeTask().copyWith(userId: '');

      await notifier.addTask(task);
      await pumpEventQueue();

      expect(notifier.state.tasks.first.userId, 'u1');
    });
  });

  group('deleteTask', () {
    test('removes task from state', () async {
      final task = _makeTask();
      final repo = FakeTaskRepository(initialTasks: [task]);
      final n = TaskNotifier(repo, 'u1');
      addTearDown(repo.dispose);

      await pumpEventQueue();
      expect(n.state.tasks, hasLength(1));

      await n.deleteTask(task.id);
      await pumpEventQueue();

      expect(n.state.tasks, isEmpty);
    });
  });

  group('toggleComplete', () {
    test('changes isCompleted from false to true', () async {
      final task = _makeTask(isCompleted: false);
      final repo = FakeTaskRepository(initialTasks: [task]);
      final n = TaskNotifier(repo, 'u1');
      addTearDown(repo.dispose);

      await pumpEventQueue();
      await n.toggleComplete(task.id);
      await pumpEventQueue();

      expect(n.state.tasks.first.isCompleted, isTrue);
    });

    test('changes isCompleted from true to false', () async {
      final task = _makeTask(isCompleted: true);
      final repo = FakeTaskRepository(initialTasks: [task]);
      final n = TaskNotifier(repo, 'u1');
      addTearDown(repo.dispose);

      await pumpEventQueue();
      await n.toggleComplete(task.id);
      await pumpEventQueue();

      expect(n.state.tasks.first.isCompleted, isFalse);
    });
  });

  group('undoDelete', () {
    test('restores the last deleted task', () async {
      final task = _makeTask();
      final repo = FakeTaskRepository(initialTasks: [task]);
      final n = TaskNotifier(repo, 'u1');
      addTearDown(repo.dispose);

      await pumpEventQueue();

      await n.deleteTask(task.id);
      await pumpEventQueue();
      expect(n.state.tasks, isEmpty);

      await n.undoDelete();
      await pumpEventQueue();

      expect(n.state.tasks, hasLength(1));
      expect(n.state.tasks.first.id, task.id);
    });

    test('does nothing when no task was deleted', () async {
      await pumpEventQueue();
      await notifier.undoDelete();
      await pumpEventQueue();
      expect(notifier.state.tasks, isEmpty);
    });
  });

  group('getFilteredTasks', () {
    late FakeTaskRepository multiRepo;
    late TaskNotifier multiNotifier;

    setUp(() async {
      final tasks = [
        _makeTask(id: 'p1', isCompleted: false, category: TaskCategory.trabajo),
        _makeTask(id: 'p2', isCompleted: true, category: TaskCategory.personal),
        _makeTask(id: 'p3', isCompleted: false, category: TaskCategory.estudio),
      ];
      multiRepo = FakeTaskRepository(initialTasks: tasks);
      multiNotifier = TaskNotifier(multiRepo, 'u1');
      await pumpEventQueue();
    });

    tearDown(() => multiRepo.dispose());

    test('all filter returns all tasks', () {
      multiNotifier.setFilter(const TaskFilter(status: StatusFilter.all));
      expect(multiNotifier.getFilteredTasks(), hasLength(3));
    });

    test('completed filter returns only completed tasks', () {
      multiNotifier.setFilter(const TaskFilter(status: StatusFilter.completed));
      final result = multiNotifier.getFilteredTasks();
      expect(result, hasLength(1));
      expect(result.first.isCompleted, isTrue);
    });

    test('categoria trabajo returns only trabajo tasks', () {
      multiNotifier.setFilter(
        const TaskFilter(category: CategoryFilter.trabajo),
      );
      final result = multiNotifier.getFilteredTasks();
      expect(result, hasLength(1));
      expect(result.first.category, TaskCategory.trabajo);
    });
  });

  group('ProviderContainer con overrides', () {
    test('taskProvider uses injected fake repository', () {
      final repo = FakeTaskRepository();
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((_) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);

      final state = container.read(taskProvider);
      expect(state.tasks, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('setFilter updates filter state via provider', () {
      final repo = FakeTaskRepository();
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((_) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);

      container
          .read(taskProvider.notifier)
          .setFilter(const TaskFilter(status: StatusFilter.completed));

      final filter = container.read(taskProvider).filter;
      expect(filter.status, StatusFilter.completed);
    });
  });
}
