import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String userId) =>
      _db.collection('users').doc(userId).collection('tasks');

  Stream<List<Task>> getTasks(String userId) {
    return _tasksRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Task.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addTask(Task task) =>
      _tasksRef(task.userId).doc(task.id).set(task.toFirestore());

  Future<void> updateTask(Task task) =>
      _tasksRef(task.userId).doc(task.id).update(task.toFirestore());

  Future<void> deleteTask(String taskId, String userId) =>
      _tasksRef(userId).doc(taskId).delete();

  Future<void> syncLocalTasks(String userId, List<Task> localTasks) async {
    final WriteBatch batch = _db.batch();
    for (final Task task in localTasks) {
      final Task withUser = task.copyWith(userId: userId);
      batch.set(_tasksRef(userId).doc(task.id), withUser.toFirestore());
    }
    await batch.commit();
  }
}
