import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthProvider(this._repository);

  UserProfile? _currentUser;
  bool _loading = true;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get loading => _loading;

  Future<void> loadCurrentUser() async {
    _loading = true;
    notifyListeners();

    _currentUser = await _repository.getCurrentUser();
    _loading = false;
    notifyListeners();
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final user = await _repository.login(email: email, password: password);
    _currentUser = user;
    _loading = false;
    notifyListeners();
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
    _currentUser = user;
    _loading = false;
    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }
}
