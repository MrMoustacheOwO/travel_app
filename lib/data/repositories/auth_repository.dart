import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_profile.dart';
import '../../config/backend_config.dart';
import '../db/database_helper.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  });

  Future<UserProfile> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<bool> isAuthenticated();

  Future<UserProfile?> getCurrentUser();
}

class ApiAuthRepository implements AuthRepository {
  final String? _configuredBaseUrl;
  final http.Client _client;

  ApiAuthRepository({
    String? backendBaseUrl,
    http.Client? client,
  })  : _configuredBaseUrl = backendBaseUrl,
        _client = client ?? http.Client();

  String get backendBaseUrl => _configuredBaseUrl ?? BackendConfig.baseUrl;

  static const String _tokenKey = 'travel_app_auth_token';
  static const Duration _requestTimeout = Duration(seconds: 12);

  @override
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _sendRequest(
      () => _client.post(
        Uri.parse('$backendBaseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        }),
      ),
      fallbackMessage: 'Ошибка регистрации',
    );

    final body = _decodeBody(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(_extractMessage(body, 'Ошибка регистрации'));
    }

    final token = body['token'] as String?;
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }

    final data = body['user'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: data['id'] as String? ?? 'guest',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final response = await _sendRequest(
      () => _client.post(
        Uri.parse('$backendBaseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      ),
      fallbackMessage: 'Ошибка входа',
    );

    final body = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw AuthException(_extractMessage(body, 'Ошибка входа'));
    }

    final token = body['token'] as String?;
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }

    final data = body['user'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: data['id'] as String? ?? 'guest',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      try {
        await _sendRequest(
          () => _client.post(
            Uri.parse('$backendBaseUrl/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
          ),
          fallbackMessage: 'Ошибка выхода',
        );
      } on AuthException {
        // Игнорируем ошибку сервера при выходе: локальная сессия в приложении всё равно должна сброситься.
      }
    }
    await prefs.remove(_tokenKey);
  }

  @override
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _sendRequest(
        () => _client.get(
          Uri.parse('$backendBaseUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        fallbackMessage: 'Ошибка получения профиля',
      );

      if (response.statusCode != 200) {
        await prefs.remove(_tokenKey);
        return null;
      }

      final body = _decodeBody(response.body);
      final user = body['user'] as Map<String, dynamic>? ?? {};
      return UserProfile(
        id: user['id'] as String? ?? 'guest',
        name: user['name'] as String? ?? '',
        email: user['email'] as String? ?? '',
      );
    } on AuthException {
      await prefs.remove(_tokenKey);
      return null;
    }
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthException(
        'Не удалось подключиться к серверу за $_requestTimeout. Проверьте URL сервера и что backend запущен на локальной сети.',
      );
    } on SocketException {
      throw AuthException(
        'Не удалось подключиться к серверу. Проверьте URL: ${BackendConfig.baseUrl} и доступность backend.',
      );
    } on http.ClientException {
      throw AuthException(
        'Сервер недоступен. Проверьте URL: ${BackendConfig.baseUrl}',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'message': decoded.toString()};
    } on FormatException {
      throw const AuthException(
        'Сервер ответил некорректным JSON. Проверьте запускаемый backend.',
      );
    }
  }

  String _extractMessage(dynamic body, String fallback) {
    if (body is Map<String, dynamic>) {
      final message = body['error'] ?? body['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}

class LocalAuthRepository implements AuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Pbkdf2 _kdf = Pbkdf2.hmacSha256(iterations: 200000, bits: 256);
  final Uuid _uuid = const Uuid();
  final Random _random = Random.secure();

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
    if (!normalizedEmail.contains('@') || normalizedEmail.length < 3) {
      throw const AuthException('Некорректный адрес электронной почты');
    }
    if (password.length < 6) {
      throw const AuthException('Пароль должен содержать минимум 6 символов');
    }

    final db = await _dbHelper.database;
    final existingUsers = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
    );
    if (existingUsers.isNotEmpty) {
      throw const AuthException('Пользователь с таким email уже зарегистрирован');
    }

    final salt = _generateSalt();
    final hash = await _hashPassword(password, salt);
    final userId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': userId,
      'name': normalizedName,
      'email': normalizedEmail,
      'password_hash': hash,
      'password_salt': _bytesToHex(salt),
      'created_at': now,
      'updated_at': now,
    });

    await _setActiveSession(db, userId);

    await db.insert(
      'profile',
      {
        'id': userId,
        'user_id': userId,
        'name': normalizedName,
        'email': normalizedEmail,
        'photo_path': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return UserProfile(id: userId, name: normalizedName, email: normalizedEmail);
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AuthException('Введите электронную почту');
    }
    if (password.isEmpty) {
      throw const AuthException('Введите пароль');
    }

    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalizedEmail],
    );

    if (rows.isEmpty) {
      throw const AuthException('Пользователь с таким email не найден');
    }

    final row = rows.first;
    final salt = _hexToBytes(row['password_salt'] as String);
    final storedHash = row['password_hash'] as String;
    final candidateHash = await _hashPassword(password, salt);

    if (candidateHash != storedHash) {
      throw const AuthException('Неверный пароль');
    }

    final userId = row['id'] as String;
    await _setActiveSession(db, userId);

    return UserProfile(
      id: userId,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
    );
  }

  @override
  Future<void> logout() async {
    final db = await _dbHelper.database;
    await db.update(
      'user_sessions',
      {'is_active': 0},
      where: 'is_active = 1',
    );
  }

  @override
  Future<bool> isAuthenticated() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'user_sessions',
      where: 'is_active = 1',
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT u.id, u.name, u.email
      FROM user_sessions s
      INNER JOIN users u ON u.id = s.user_id
      WHERE s.is_active = 1
      ORDER BY s.created_at DESC
      LIMIT 1
    ''');

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return UserProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
    );
  }

  List<int> _generateSalt() {
    return List<int>.generate(16, (_) => _random.nextInt(256));
  }

  Future<String> _hashPassword(String password, List<int> salt) async {
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return _bytesToHex(bytes);
  }

  Future<void> _setActiveSession(Database db, String userId) async {
    await db.update(
      'user_sessions',
      {'is_active': 0},
      where: 'is_active = 1',
    );

    await db.insert(
      'user_sessions',
      {
        'id': _uuid.v4(),
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'\s+'), '');
    final result = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      final chunk = cleanHex.substring(i, i + 2);
      result.add(int.parse(chunk, radix: 16));
    }
    return result;
  }
}
