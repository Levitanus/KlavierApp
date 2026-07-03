import '../domain/entities/auth_session.dart';

enum AuthStatus { initializing, unauthenticated, submitting, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isInitializing => status == AuthStatus.initializing;
  bool get isSubmitting => status == AuthStatus.submitting;
  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;

  factory AuthState.initializing() {
    return const AuthState(status: AuthStatus.initializing);
  }

  factory AuthState.unauthenticated({String? errorMessage}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.submitting() {
    return const AuthState(status: AuthStatus.submitting);
  }

  factory AuthState.authenticated(AuthSession session) {
    return AuthState(status: AuthStatus.authenticated, session: session);
  }
}
