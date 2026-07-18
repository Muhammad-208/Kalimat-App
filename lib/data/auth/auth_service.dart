import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps FirebaseAuth. When [ready] is false (Firebase not configured), every
/// method is a safe no-op / throws a friendly error, so the app still runs.
class AuthService {
  AuthService(this.ready);
  final bool ready;

  Stream<User?> authStateChanges() =>
      ready ? FirebaseAuth.instance.authStateChanges() : Stream.value(null);

  User? get currentUser => ready ? FirebaseAuth.instance.currentUser : null;

  void _need() {
    if (!ready) {
      throw StateError('المزامنة غير مُهيّأة بعد. راجع SYNC_SETUP.md');
    }
  }

  Future<void> signInWithGoogle() async {
    _need();
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signInWithEmail(String email, String password) async {
    _need();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> registerWithEmail(String email, String password) async {
    _need();
    await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    if (!ready) return;
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
