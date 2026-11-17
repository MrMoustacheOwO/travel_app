import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses_app/data/repositories/auth_repository.dart';
import 'package:travel_expenses_app/models/user_profile.dart';
import 'package:travel_expenses_app/providers/auth_provider.dart';

void main() {
  test('auth state event immediately updates authenticated state', () async {
    final repository = _AuthStateRepository();
    final provider = AuthProvider(repository);
    var notifications = 0;
    provider.addListener(() => notifications++);

    repository.controller.add(
      UserProfile(id: 'user-1', name: 'Test', email: 'test@example.com'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(provider.isAuthenticated, isTrue);
    expect(provider.currentUser?.id, 'user-1');
    expect(provider.loading, isFalse);
    expect(notifications, 1);

    provider.dispose();
    await repository.controller.close();
  });

  test('late initial session lookup cannot undo a successful sign-in', () async {
    final repository = _DelayedAuthStateRepository();
    final provider = AuthProvider(repository);
    final initialLoad = provider.loadCurrentUser();

    repository.controller.add(
      UserProfile(id: 'user-1', name: 'Test', email: 'test@example.com'),
    );
    await Future<void>.delayed(Duration.zero);
    repository.currentUser.complete(null);
    await initialLoad;

    expect(provider.isAuthenticated, isTrue);
    expect(provider.currentUser?.id, 'user-1');
    expect(provider.loading, isFalse);

    provider.dispose();
    await repository.controller.close();
  });

  test('null auth stream event cannot undo the active sign-in', () async {
    final repository = _AuthStateRepository();
    final provider = AuthProvider(repository);

    await provider.login(email: 'test@example.com', password: 'secret');
    repository.controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.isAuthenticated, isTrue);
    expect(provider.currentUser?.id, 'user-1');

    provider.dispose();
    await repository.controller.close();
  });
}

class _AuthStateRepository implements AuthRepository, AuthStateRepository {
  final StreamController<UserProfile?> controller =
      StreamController<UserProfile?>.broadcast();

  @override
  Stream<UserProfile?> get authStateChanges => controller.stream;

  @override
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async =>
      UserProfile(id: 'user-1', name: name, email: email);

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async =>
      UserProfile(id: 'user-1', email: email);

  @override
  Future<void> logout() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<UserProfile?> getCurrentUser() async => null;
}

class _DelayedAuthStateRepository extends _AuthStateRepository {
  final Completer<UserProfile?> currentUser = Completer<UserProfile?>();

  @override
  Future<UserProfile?> getCurrentUser() => currentUser.future;
}
