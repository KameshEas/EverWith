/// Typed auth result returned by [AuthService].
///
/// Use pattern matching:
/// ```dart
/// final result = await AuthService.instance.signInWithEmail(...);
/// switch (result) {
///   case AuthSuccess(:final user): ...
///   case AuthFailure(:final message): ...
/// }
/// ```
sealed class AuthResult {}

final class AuthSuccess extends AuthResult {
  AuthSuccess(this.user);
  final AuthUser user;
}

final class AuthFailure extends AuthResult {
  AuthFailure(this.message, {this.code});
  final String message;
  /// The raw Firebase error code (e.g. 'user-not-found', 'wrong-password').
  /// Use this for programmatic routing decisions rather than parsing [message].
  final String? code;
}

/// Lightweight user value object used across the app.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.isEmailVerified,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
}

/// Maps Firebase Auth error codes to human-readable, elderly-friendly messages.
String authErrorMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'We could not find an account with that email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'weak-password':
      return 'Password is too weak. Use at least 8 characters.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network.';
    case 'popup-closed-by-user':
    case 'cancelled':
      return 'Sign in was cancelled.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
