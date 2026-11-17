import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final void Function()? _onAuthenticated;

  AuthProvider(this._repository, {void Function()? onAuthenticated})
      : _onAuthenticated = onAuthenticated {
    final repository = _repository;
    if (repository is AuthStateRepository) {
      _authSubscription = (repository as AuthStateRepository)
          .authStateChanges
          .where((user) => user != null)
          .listen(_applyAuthState);
    }
  }

  UserProfile? _currentUser;
  bool _loading = true;
  String? _loadError;
  StreamSubscription<UserProfile?>? _authSubscription;
  int _authRevision = 0;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get loading => _loading;
  String? get loadError => _loadError;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _applyAuthState(UserProfile? user) {
    final changed = _currentUser?.id != user?.id;
    final wasLoading = _loading;
    _authRevision++;
    _currentUser = user;
    _loading = false;
    _loadError = null;
    if (changed || wasLoading) notifyListeners();
    if (changed && user != null) _onAuthenticated?.call();
  }

  Future<void> loadCurrentUser() async {
    final revision = _authRevision;
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final user = await _repository.getCurrentUser();
      if (revision == _authRevision) _applyAuthState(user);
    } catch (error) {
      if (revision == _authRevision) _loadError = error.toString();
    } finally {
      if (revision == _authRevision) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final user = await _repository.login(email: email, password: password);
    _applyAuthState(user);
    return user;
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    _applyAuthState(user);
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    _applyAuthState(null);
  }
}
