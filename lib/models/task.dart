import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum TaskCategory { trabajo, personal, estudio, urgente }

enum TaskPriority { alta, media, baja }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final String userId;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.dueDate,
    required this.isCompleted,
    required this.createdAt,
    this.userId = '',
  });

  factory Task.create({
    required String title,
    required String description,
    required TaskCategory category,
    required TaskPriority priority,
    required DateTime dueDate,
    String userId = '',
  }) {
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      category: category,
      priority: priority,
      dueDate: dueDate,
      isCompleted: false,
      createdAt: DateTime.now(),
      userId: userId,
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority.name,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: TaskCategory.values.firstWhere(
        (e) => e.name == map['category'],
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
      ),
      dueDate: DateTime.parse(map['dueDate'] as String),
      isCompleted: map['isCompleted'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
      userId: map['userId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;
    return Task(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String,
      category: TaskCategory.values.firstWhere(
        (e) => e.name == data['category'],
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
      ),
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : (data['createdAt'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] as String? ?? '',
    );
  }
}
