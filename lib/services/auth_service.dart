import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toUserModel(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  Future<UserModel> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toUserModel(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  UserModel _toUserModel(User user) => UserModel(
        uid: user.uid,
        email: user.email ?? '',
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciales inválidas.';
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Error de autenticación. Intenta de nuevo.';
    }
  }
}
