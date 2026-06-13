import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'auth_provider.dart';

enum StatusFilter { all, pending, completed }

enum CategoryFilter { all, trabajo, personal, estudio, urgente }

class TaskFilter {
  final StatusFilter status;
  final CategoryFilter category;

  const TaskFilter({
    this.status = StatusFilter.all,
    this.category = CategoryFilter.all,
  });

  TaskFilter copyWith({StatusFilter? status, CategoryFilter? category}) {
    return TaskFilter(
      status: status ?? this.status,
      category: category ?? this.category,
    );
  }
}

class TaskState {
  final List<Task> tasks;
  final TaskFilter filter;

  const TaskState({required this.tasks, required this.filter});

  TaskState copyWith({List<Task>? tasks, TaskFilter? filter}) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
    );
  }

  List<Task> get filteredTasks {
    List<Task> result = List<Task>.from(tasks);

    if (filter.status == StatusFilter.pending) {
      result = result.where((t) => !t.isCompleted).toList();
    } else if (filter.status == StatusFilter.completed) {
      result = result.where((t) => t.isCompleted).toList();
    }

    if (filter.category != CategoryFilter.all) {
      result = result
          .where((t) => t.category.name == filter.category.name)
          .toList();
    }

    result.sort((Task a, Task b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      const Map<String, int> order = {'alta': 0, 'media': 1, 'baja': 2};
      final int pa = order[a.priority.name] ?? 1;
      final int pb = order[b.priority.name] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.dueDate.compareTo(b.dueDate);
    });

    return result;
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  final TaskRepository _repository;
  final String _userId;
  StreamSubscription<List<Task>>? _subscription;

  TaskNotifier(this._repository, this._userId)
      : super(const TaskState(tasks: [], filter: TaskFilter())) {
    if (_userId.isNotEmpty) {
      _subscription = _repository.watchTasks(_userId).listen(
        (tasks) => state = state.copyWith(tasks: tasks),
      );
    }
  }

  Future<void> addTask(Task task) =>
      _repository.addTask(task.copyWith(userId: _userId));

  Future<void> updateTask(Task task) {
    final Task withUser =
        task.userId.isEmpty ? task.copyWith(userId: _userId) : task;
    return _repository.updateTask(withUser);
  }

  Future<void> deleteTask(String id) =>
      _repository.deleteTask(id, _userId);

  Future<void> toggleComplete(String id) {
    final Task task = state.tasks.firstWhere((t) => t.id == id);
    return _repository.updateTask(
      task.copyWith(isCompleted: !task.isCompleted),
    );
  }

  void setFilter(TaskFilter filter) => state = state.copyWith(filter: filter);

  List<Task> getFilteredTasks() => state.filteredTasks;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<TaskNotifier, TaskState> taskProvider =
    StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final authState = ref.watch(authStateProvider);
  final String userId = authState.valueOrNull?.uid ?? '';
  return TaskNotifier(ref.read(taskRepositoryProvider), userId);
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(false);
  void toggleTheme() => state = !state;
}

final StateNotifierProvider<ThemeNotifier, bool> themeProvider =
    StateNotifierProvider<ThemeNotifier, bool>((_) => ThemeNotifier());
