import 'package:flutter_test/flutter_test.dart';
import 'package:task_ai/models/task.dart';

void main() {
  final dueDate = DateTime(2026, 6, 30, 12, 0);
  final createdAt = DateTime(2026, 1, 10, 8, 0);

  final baseTask = Task(
    id: 'task-001',
    title: 'Entregar informe',
    description: 'Informe final del semestre',
    category: TaskCategory.estudio,
    priority: TaskPriority.alta,
    dueDate: dueDate,
    isCompleted: false,
    createdAt: createdAt,
    userId: 'user-42',
  );

  group('Task.copyWith', () {
    test('updates only specified fields and preserves the rest', () {
      final updated = baseTask.copyWith(title: 'Nuevo título');

      expect(updated.title, 'Nuevo título');
      expect(updated.id, baseTask.id);
      expect(updated.description, baseTask.description);
      expect(updated.category, baseTask.category);
      expect(updated.priority, baseTask.priority);
      expect(updated.dueDate, baseTask.dueDate);
      expect(updated.createdAt, baseTask.createdAt);
    });

    test('preserves userId when not specified', () {
      final updated = baseTask.copyWith(title: 'Otro título');
      expect(updated.userId, 'user-42');
    });

    test('updates isCompleted to true', () {
      final completed = baseTask.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
    });

    test('updates category independently', () {
      final updated = baseTask.copyWith(category: TaskCategory.urgente);
      expect(updated.category, TaskCategory.urgente);
      expect(updated.priority, baseTask.priority);
    });

    test('updates userId', () {
      final updated = baseTask.copyWith(userId: 'new-user');
      expect(updated.userId, 'new-user');
    });
  });

  group('Task.toMap', () {
    test('generates Map with all required fields', () {
      final map = baseTask.toMap();

      expect(map['id'], 'task-001');
      expect(map['title'], 'Entregar informe');
      expect(map['description'], 'Informe final del semestre');
      expect(map['category'], 'estudio');
      expect(map['priority'], 'alta');
      expect(map['dueDate'], dueDate.toIso8601String());
      expect(map['isCompleted'], false);
      expect(map['createdAt'], createdAt.toIso8601String());
      expect(map['userId'], 'user-42');
    });

    test('serializes category as enum name string', () {
      final map = Task(
        id: 'x',
        title: 'x',
        description: '',
        category: TaskCategory.personal,
        priority: TaskPriority.baja,
        dueDate: dueDate,
        isCompleted: false,
        createdAt: createdAt,
        userId: '',
      ).toMap();

      expect(map['category'], 'personal');
      expect(map['priority'], 'baja');
    });
  });

  group('Task.fromMap', () {
    test('reconstructs a Task from its own toMap output', () {
      final map = baseTask.toMap();
      final restored = Task.fromMap(map);

      expect(restored.id, baseTask.id);
      expect(restored.title, baseTask.title);
      expect(restored.description, baseTask.description);
      expect(restored.category, baseTask.category);
      expect(restored.priority, baseTask.priority);
      expect(restored.isCompleted, baseTask.isCompleted);
      expect(restored.userId, baseTask.userId);
    });

    test('preserves DateTime values through round-trip', () {
      final map = baseTask.toMap();
      final restored = Task.fromMap(map);

      expect(restored.dueDate, dueDate);
      expect(restored.createdAt, createdAt);
    });

    test('defaults userId to empty string when absent in map', () {
      final map = baseTask.toMap()..remove('userId');
      final restored = Task.fromMap(map);
      expect(restored.userId, '');
    });
  });

  group('TaskCategory enum', () {
    test('contains all four expected values', () {
      final names = TaskCategory.values.map((e) => e.name).toList();
      expect(names, containsAll(['trabajo', 'personal', 'estudio', 'urgente']));
    });

    test('has exactly 4 values', () {
      expect(TaskCategory.values, hasLength(4));
    });
  });

  group('TaskPriority enum', () {
    test('contains alta media baja', () {
      final names = TaskPriority.values.map((e) => e.name).toList();
      expect(names, containsAll(['alta', 'media', 'baja']));
    });

    test('has exactly 3 values', () {
      expect(TaskPriority.values, hasLength(3));
    });
  });

  group('Task.create', () {
    test('new task has isCompleted = false by default', () {
      final task = Task.create(
        title: 'Nueva tarea',
        description: '',
        category: TaskCategory.trabajo,
        priority: TaskPriority.media,
        dueDate: DateTime(2026, 12, 31),
      );

      expect(task.isCompleted, isFalse);
    });

    test('generates a non-empty UUID id', () {
      final task = Task.create(
        title: 'Test',
        description: '',
        category: TaskCategory.personal,
        priority: TaskPriority.baja,
        dueDate: DateTime(2026, 12, 31),
      );

      expect(task.id, isNotEmpty);
      expect(task.id.length, greaterThan(10));
    });

    test('sets userId when provided', () {
      final task = Task.create(
        title: 'Test',
        description: '',
        category: TaskCategory.urgente,
        priority: TaskPriority.alta,
        dueDate: DateTime(2026, 12, 31),
        userId: 'uid-99',
      );

      expect(task.userId, 'uid-99');
    });
  });
}
