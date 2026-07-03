import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.initializing()) {
    Future<void>.microtask(restoreSession);
  }

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    state = AuthState.initializing();

    try {
      final session = await _repository.restoreSession();
      if (session == null) {
        state = AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(session);
    } catch (error) {
      state = AuthState.unauthenticated(errorMessage: _message(error));
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = AuthState.submitting();

    try {
      final session = await _repository.login(username: username, password: password);
      state = AuthState.authenticated(session);
    } catch (error) {
      state = AuthState.unauthenticated(errorMessage: _message(error));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState.unauthenticated();
  }

  String _message(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Unexpected error. Please try again.';
  }
}
