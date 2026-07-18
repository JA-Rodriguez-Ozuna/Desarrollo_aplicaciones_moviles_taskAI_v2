import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final bool isLoading;
  final String? errorMessage;

  const TaskState({
    required this.tasks,
    required this.filter,
    this.isLoading = false,
    this.errorMessage,
  });

  TaskState copyWith({
    List<Task>? tasks,
    TaskFilter? filter,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
  Task? _lastDeleted;

  TaskNotifier(this._repository, this._userId)
      : super(TaskState(
          tasks: const [],
          filter: const TaskFilter(),
          isLoading: _userId.isNotEmpty,
        )) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    _subscription = _repository.watchTasks(_userId).listen(
      (tasks) =>
          state = state.copyWith(tasks: tasks, isLoading: false, clearError: true),
      onError: (Object e, StackTrace st) {
        debugPrint('[TaskNotifier] stream error: $e');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No se pudieron cargar las tareas',
        );
      },
    );
  }

  void retry() => _subscribe();

  Future<void> addTask(Task task) =>
      _repository.addTask(task.copyWith(userId: _userId));

  Future<void> updateTask(Task task) {
    final Task withUser =
        task.userId.isEmpty ? task.copyWith(userId: _userId) : task;
    return _repository.updateTask(withUser);
  }

  Future<void> deleteTask(String id) {
    final Iterable<Task> matches = state.tasks.where((Task t) => t.id == id);
    _lastDeleted = matches.isNotEmpty ? matches.first : null;
    return _repository.deleteTask(id, _userId);
  }

  Future<void> undoDelete() async {
    final Task? task = _lastDeleted;
    if (task == null) return;
    _lastDeleted = null;
    await addTask(task);
  }

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

const String _themeModePrefsKey = 'theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_themeModePrefsKey);
    state = ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefsKey, mode.name);
  }
}

final StateNotifierProvider<ThemeNotifier, ThemeMode> themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((_) => ThemeNotifier());
