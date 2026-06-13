import 'package:connectivity_plus/connectivity_plus.dart';
import 'firestore_service.dart';
import 'hive_service.dart';

class SyncService {
  final FirestoreService _firestore;
  final HiveService _hive;

  SyncService(this._firestore, this._hive);

  Stream<bool> get onConnectivityChanged => Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  Future<bool> isOnline() async {
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> syncPendingTasks(String userId) async {
    final cachedTasks = _hive.getTasks();
    if (cachedTasks.isEmpty) return;
    await _firestore.syncLocalTasks(userId, cachedTasks);
    await _hive.clearTasks();
  }
}
