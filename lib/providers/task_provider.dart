import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

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
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      const Map<String, int> priorityOrder = {
        'alta': 0,
        'media': 1,
        'baja': 2,
      };
      final int pa = priorityOrder[a.priority.name] ?? 1;
      final int pb = priorityOrder[b.priority.name] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.dueDate.compareTo(b.dueDate);
    });

    return result;
  }
}

List<Task> _buildSampleTasks() {
  final DateTime now = DateTime.now();
  const Uuid uuid = Uuid();
  return [
    Task(
      id: uuid.v4(),
      title: 'Entregar proyecto final de Flutter',
      description: 'Completar la app TaskAI con todas las pantallas requeridas.',
      category: TaskCategory.estudio,
      priority: TaskPriority.alta,
      dueDate: now.add(const Duration(days: 3)),
      isCompleted: false,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    Task(
      id: uuid.v4(),
      title: 'Preparar presentación de Sistemas',
      description: 'Slides sobre arquitecturas de microservicios.',
      category: TaskCategory.estudio,
      priority: TaskPriority.media,
      dueDate: now.add(const Duration(days: 5)),
      isCompleted: false,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    Task(
      id: uuid.v4(),
      title: 'Ir al gimnasio',
      description: 'Rutina de fuerza: pierna y core.',
      category: TaskCategory.personal,
      priority: TaskPriority.baja,
      dueDate: now.add(const Duration(days: 1)),
      isCompleted: true,
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    Task(
      id: uuid.v4(),
      title: 'Revisar pull request de compañero',
      description: 'PR #42 del repo del equipo de trabajo.',
      category: TaskCategory.trabajo,
      priority: TaskPriority.media,
      dueDate: now.add(const Duration(hours: 8)),
      isCompleted: false,
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    Task(
      id: uuid.v4(),
      title: 'Pagar inscripción semestral',
      description: 'Fecha límite de pago esta semana.',
      category: TaskCategory.urgente,
      priority: TaskPriority.alta,
      dueDate: now.add(const Duration(days: 2)),
      isCompleted: false,
      createdAt: now.subtract(const Duration(hours: 12)),
    ),
  ];
}

class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier()
      : super(
          TaskState(
            tasks: _buildSampleTasks(),
            filter: const TaskFilter(),
          ),
        );

  void addTask(Task task) {
    state = state.copyWith(tasks: [...state.tasks, task]);
  }

  void updateTask(Task updatedTask) {
    state = state.copyWith(
      tasks: state.tasks
          .map((Task t) => t.id == updatedTask.id ? updatedTask : t)
          .toList(),
    );
  }

  void deleteTask(String id) {
    state = state.copyWith(
      tasks: state.tasks.where((Task t) => t.id != id).toList(),
    );
  }

  void toggleComplete(String id) {
    state = state.copyWith(
      tasks: state.tasks
          .map(
            (Task t) =>
                t.id == id ? t.copyWith(isCompleted: !t.isCompleted) : t,
          )
          .toList(),
    );
  }

  void setFilter(TaskFilter filter) {
    state = state.copyWith(filter: filter);
  }

  List<Task> getFilteredTasks() => state.filteredTasks;
}

final StateNotifierProvider<TaskNotifier, TaskState> taskProvider =
    StateNotifierProvider<TaskNotifier, TaskState>((Ref ref) {
  return TaskNotifier();
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(false);

  void toggleTheme() => state = !state;
}

final StateNotifierProvider<ThemeNotifier, bool> themeProvider =
    StateNotifierProvider<ThemeNotifier, bool>((Ref ref) {
  return ThemeNotifier();
});
