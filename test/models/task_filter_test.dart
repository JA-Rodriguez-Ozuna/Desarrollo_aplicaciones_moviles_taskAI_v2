import 'package:flutter_test/flutter_test.dart';
import 'package:task_ai/models/task.dart';
import 'package:task_ai/providers/task_provider.dart';

Task _task({
  required String id,
  TaskCategory category = TaskCategory.trabajo,
  bool isCompleted = false,
  TaskPriority priority = TaskPriority.media,
}) =>
    Task(
      id: id,
      title: 'Tarea $id',
      description: '',
      category: category,
      priority: priority,
      dueDate: DateTime(2026, 12, 31),
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
      userId: 'u1',
    );

TaskState _stateWith(List<Task> tasks, {TaskFilter? filter}) => TaskState(
      tasks: tasks,
      filter: filter ?? const TaskFilter(),
    );

void main() {
  final trabajo1 = _task(id: 'w1', category: TaskCategory.trabajo);
  final trabajo2 = _task(id: 'w2', category: TaskCategory.trabajo, isCompleted: true);
  final personal = _task(id: 'p1', category: TaskCategory.personal);
  final estudio = _task(id: 'e1', category: TaskCategory.estudio);
  final urgente = _task(id: 'u1', category: TaskCategory.urgente, isCompleted: true);

  final allTasks = [trabajo1, trabajo2, personal, estudio, urgente];

  group('StatusFilter.all', () {
    test('returns all tasks', () {
      final state = _stateWith(allTasks);
      expect(state.filteredTasks, hasLength(allTasks.length));
    });

    test('returns empty list when tasks is empty', () {
      final state = _stateWith([]);
      expect(state.filteredTasks, isEmpty);
    });
  });

  group('StatusFilter.completed', () {
    test('returns only completed tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(status: StatusFilter.completed),
      );
      final result = state.filteredTasks;
      expect(result, everyElement(predicate<Task>((t) => t.isCompleted)));
      expect(result, hasLength(2));
    });

    test('returns empty list when no tasks are completed', () {
      final state = _stateWith(
        [trabajo1, personal, estudio],
        filter: const TaskFilter(status: StatusFilter.completed),
      );
      expect(state.filteredTasks, isEmpty);
    });
  });

  group('StatusFilter.pending', () {
    test('returns only pending tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(status: StatusFilter.pending),
      );
      final result = state.filteredTasks;
      expect(result, everyElement(predicate<Task>((t) => !t.isCompleted)));
    });
  });

  group('CategoryFilter', () {
    test('trabajo filter returns only trabajo tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(category: CategoryFilter.trabajo),
      );
      final result = state.filteredTasks;
      expect(result, everyElement(predicate<Task>((t) => t.category == TaskCategory.trabajo)));
      expect(result, hasLength(2));
    });

    test('personal filter returns only personal tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(category: CategoryFilter.personal),
      );
      final result = state.filteredTasks;
      expect(result.single.id, 'p1');
    });

    test('estudio filter returns only estudio tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(category: CategoryFilter.estudio),
      );
      expect(state.filteredTasks.single.id, 'e1');
    });

    test('urgente filter returns only urgente tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(category: CategoryFilter.urgente),
      );
      expect(state.filteredTasks.single.id, 'u1');
    });

    test('category.all returns all tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(category: CategoryFilter.all),
      );
      expect(state.filteredTasks, hasLength(allTasks.length));
    });
  });

  group('Combined filters', () {
    test('trabajo + completed returns only completed trabajo tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(
          status: StatusFilter.completed,
          category: CategoryFilter.trabajo,
        ),
      );
      final result = state.filteredTasks;
      expect(result, hasLength(1));
      expect(result.single.id, 'w2');
    });

    test('estudio + pending returns only pending estudio tasks', () {
      final state = _stateWith(
        allTasks,
        filter: const TaskFilter(
          status: StatusFilter.pending,
          category: CategoryFilter.estudio,
        ),
      );
      expect(state.filteredTasks.single.id, 'e1');
    });

    test('combined filter on empty list returns empty', () {
      final state = _stateWith(
        [],
        filter: const TaskFilter(
          status: StatusFilter.completed,
          category: CategoryFilter.trabajo,
        ),
      );
      expect(state.filteredTasks, isEmpty);
    });
  });

  group('TaskFilter.copyWith', () {
    test('updates only specified field', () {
      const original = TaskFilter(status: StatusFilter.all, category: CategoryFilter.all);
      final updated = original.copyWith(status: StatusFilter.completed);
      expect(updated.status, StatusFilter.completed);
      expect(updated.category, CategoryFilter.all);
    });
  });

  group('Sorting', () {
    test('pending tasks appear before completed tasks', () {
      final pending = _task(id: 'pending', isCompleted: false, priority: TaskPriority.baja);
      final completed = _task(id: 'done', isCompleted: true, priority: TaskPriority.alta);
      final state = _stateWith([completed, pending]);
      final result = state.filteredTasks;
      expect(result.first.isCompleted, isFalse);
    });

    test('higher priority tasks appear before lower priority within same completion state', () {
      final alta = _task(id: 'high', priority: TaskPriority.alta);
      final baja = _task(id: 'low', priority: TaskPriority.baja);
      final state = _stateWith([baja, alta]);
      final result = state.filteredTasks;
      expect(result.first.id, 'high');
    });
  });
}
