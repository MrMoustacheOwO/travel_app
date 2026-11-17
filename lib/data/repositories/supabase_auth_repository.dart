import 'dart:async';

import 'package:gotrue/gotrue.dart' show UserAttributes;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../models/user_profile.dart';
import '../../config/supabase_config.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository, AuthStateRepository {
  final supabase.SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<UserProfile?> get authStateChanges => _client.auth.onAuthStateChange
      .map((state) => state.session?.user)
      .map((user) => user == null ? null : _profileFromUser(user));

  @override
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      throw const AuthException('Укажите имя пользователя');
    }
    if (!normalizedEmail.contains('@')) {
      throw const AuthException('Некорректный адрес электронной почты');
    }
    if (password.length < 6) {
      throw const AuthException('Пароль должен содержать минимум 6 символов');
    }

    try {
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': normalizedName},
      ).timeout(SupabaseConfig.requestTimeout);
      final user = response.user;
      if (user == null) {
        throw const AuthException('Supabase не создал пользователя');
      }
      if (response.session == null) {
        throw const AuthException(
          'Аккаунт создан. Подтвердите email по ссылке из письма, затем войдите.',
        );
      }
      return _profileFromUser(user);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Не удалось подключиться к базе данных за 10 секунд. Проверьте интернет и повторите попытку.',
      );
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Введите email и пароль');
    }

    try {
      final response = await _client.auth
          .signInWithPassword(
            email: email.trim().toLowerCase(),
            password: password,
          )
          .timeout(SupabaseConfig.requestTimeout);
      final user = response.user;
      if (user == null) {
        throw const AuthException('Не удалось войти в аккаунт');
      }
      return _profileFromUser(user);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Не удалось подключиться к базе данных за 10 секунд. Проверьте интернет и повторите попытку.',
      );
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> logout() => _client.auth.signOut();

  @override
  Future<void> updateEmail(String email) async {
    try {
      await _client.auth
          .updateUser(UserAttributes(email: email.trim().toLowerCase()))
          .timeout(SupabaseConfig.requestTimeout);
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    } on TimeoutException {
      throw const AuthException(
        'Не удалось подключиться к базе данных за 10 секунд. Проверьте интернет и повторите попытку.',
      );
    }
  }

  @override
  Future<bool> isAuthenticated() async => _client.auth.currentUser != null;

  @override
  Future<UserProfile?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    return user == null ? null : _profileFromUser(user);
  }

  UserProfile _profileFromUser(supabase.User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return UserProfile(
      id: user.id,
      name: (metadata['full_name'] ??
              metadata['name'] ??
              user.email?.split('@').first ??
              '')
          .toString(),
      email: user.email ?? '',
    );
  }
}
