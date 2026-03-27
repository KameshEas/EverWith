import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_result.dart';

/// Centralised Firebase Authentication service for EverWith.
///
/// Provides:
/// - Email / password sign-in and registration
/// - Google Sign-In (OAuth)
/// - Sign-out
/// - Current user stream
///
/// All methods return [AuthResult] (either [AuthSuccess] or [AuthFailure])
/// so callers never need to catch exceptions directly.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Stream ──────────────────────────────────────────────────────────────

  /// Emits [AuthUser] when signed in, or `null` when signed out.
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().map(_mapUser);
  }

  /// The currently signed-in user, or `null`.
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  // ── Email / Password ────────────────────────────────────────────────────

  /// Sign in with [email] and [password].
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthSuccess(_mapUser(credential.user)!);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      return AuthFailure(authErrorMessage('unknown'));
    }
  }

  /// Create a new account with [email] and [password].
  /// Optionally sets [displayName] on the new user.
  Future<AuthResult> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        await credential.user?.reload();
      }
      return AuthSuccess(_mapUser(_auth.currentUser)!);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      return AuthFailure(authErrorMessage('unknown'));
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────

  /// Sign in (or link) a Google account.
  /// Works on Android and iOS. On web, use [signInWithGooglePopup].
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker
        return AuthFailure(authErrorMessage('cancelled'));
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return AuthSuccess(_mapUser(userCredential.user)!);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(authErrorMessage(e.code));
    } catch (e) {
      return AuthFailure(e.toString());
    }
  }

  // ── Password reset ───────────────────────────────────

  /// Send a password-reset email to [email].
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthSuccess(
        const AuthUser(
          uid: '',
          email: null,
          isEmailVerified: false,
        ),
      );
    } on FirebaseAuthException catch (e) {
      return AuthFailure(authErrorMessage(e.code));
    } catch (_) {
      return AuthFailure(authErrorMessage('unknown'));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
    );
  }
}
