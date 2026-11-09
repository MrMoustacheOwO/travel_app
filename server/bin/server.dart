import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

Future<void> main(List<String> args) async {
  final host = _readFlag(args, '--host', '0.0.0.0');
  final port = int.tryParse(_readFlag(args, '--port', '8080')) ?? 8080;

  final dbPath = Platform.script.resolve('../data/travel_expenses_backend.db').toFilePath();
  final dbDir = File(dbPath).parent;
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }

  final db = sqlite3.open(dbPath);
  _initializeDatabase(db);

  final router = Router();
  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'database': dbPath}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.post('/api/auth/register', (Request request) async {
    final payload = await _readJson(request);
    final name = (payload['name'] as String? ?? '').trim();
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final password = (payload['password'] as String? ?? '');

    if (name.isEmpty) {
      return _errorResponse(400, 'Укажите имя пользователя');
    }
    if (!email.contains('@') || email.length < 3) {
      return _errorResponse(400, 'Некорректный email');
    }
    if (password.length < 6) {
      return _errorResponse(400, 'Пароль должен содержать минимум 6 символов');
    }

    final existing = db.select(
      'SELECT id FROM users WHERE LOWER(email) = ? LIMIT 1',
      [email],
    );
    if (existing.isNotEmpty) {
      return _errorResponse(409, 'Пользователь с таким email уже существует');
    }

    final userId = _uuid();
    final salt = _randomSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    db.execute(
      'INSERT INTO users (id, name, email, password_hash, password_salt, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, name, email, passwordHash, salt, now, now],
    );

    final token = _uuid();
    db.execute(
      'INSERT INTO sessions (token, user_id, created_at, updated_at) VALUES (?, ?, ?, ?)',
      [token, userId, now, now],
    );

    return Response.ok(
      jsonEncode({
        'token': token,
        'user': {'id': userId, 'name': name, 'email': email},
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.post('/api/auth/login', (Request request) async {
    final payload = await _readJson(request);
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final password = (payload['password'] as String? ?? '');

    if (email.isEmpty) {
      return _errorResponse(400, 'Введите email');
    }
    if (password.isEmpty) {
      return _errorResponse(400, 'Введите пароль');
    }

    final row = db.select(
      'SELECT * FROM users WHERE LOWER(email) = ? LIMIT 1',
      [email],
    );
    if (row.isEmpty) {
      return _errorResponse(404, 'Пользователь не найден');
    }

    final user = row.first;
    final storedHash = user['password_hash'] as String;
    final salt = user['password_salt'] as String;
    final incomingHash = _hashPassword(password, salt);
    if (incomingHash != storedHash) {
      return _errorResponse(401, 'Неверный пароль');
    }

    final userId = user['id'] as String;
    final now = DateTime.now().toIso8601String();
    final token = _uuid();
    db.execute(
      'DELETE FROM sessions WHERE user_id = ?',
      [userId],
    );
    db.execute(
      'INSERT INTO sessions (token, user_id, created_at, updated_at) VALUES (?, ?, ?, ?)',
      [token, userId, now, now],
    );

    return Response.ok(
      jsonEncode({
        'token': token,
        'user': {
          'id': userId,
          'name': user['name'],
          'email': user['email'],
        },
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/api/auth/me', (Request request) async {
    final token = _tokenFromRequest(request);
    if (token == null || token.isEmpty) {
      return _errorResponse(401, 'Необходима авторизация');
    }

    final session = db.select(
      'SELECT user_id FROM sessions WHERE token = ? LIMIT 1',
      [token],
    );
    if (session.isEmpty) {
      return _errorResponse(401, 'Сессия не найдена');
    }

    final userId = session.first['user_id'] as String;
    final user = db.select(
      'SELECT id, name, email FROM users WHERE id = ? LIMIT 1',
      [userId],
    );
    if (user.isEmpty) {
      return _errorResponse(404, 'Пользователь не найден');
    }

    final current = user.first;
    return Response.ok(
      jsonEncode({
        'user': {
          'id': current['id'],
          'name': current['name'],
          'email': current['email'],
        },
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.post('/api/auth/logout', (Request request) async {
    final token = _tokenFromRequest(request);
    if (token != null && token.isNotEmpty) {
      db.execute('DELETE FROM sessions WHERE token = ?', [token]);
    }
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  final Middleware corsMiddleware = _corsMiddleware();
  final handler = const Pipeline()
      .addMiddleware(corsMiddleware.call)
      .addHandler(router);

  final server = await shelf_io.serve(handler, host, port);
  stdout.writeln('Backend started on ${server.address.host}:${server.port}');
  stdout.writeln('Health: http://${server.address.host}:${server.port}/health');
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: _corsHeaders,
        );
      }

      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };
}

void _initializeDatabase(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
}

String _randomSalt() {
  final bytes = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch.remainder(256));
  return base64UrlEncode(bytes);
}

String _hashPassword(String password, String salt) {
  final bytes = utf8.encode('$password:$salt');
  final digest = sha256.convert(bytes);
  return digest.toString();
}

String _uuid() {
  final bytes = List<int>.generate(16, (i) => DateTime.now().millisecondsSinceEpoch.remainder(256) + i);
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String? _tokenFromRequest(Request request) {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) {
    return null;
  }
  return header.substring('Bearer '.length).trim();
}

Response _errorResponse(int status, String message) {
  return Response(status, body: jsonEncode({'error': message}), headers: {'content-type': 'application/json; charset=utf-8'});
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  try {
    final body = await request.readAsString();
    if (body.trim().isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } on FormatException {
    throw const FormatException('Некорректный JSON');
  }
}

String _readFlag(List<String> args, String flag, String fallback) {
  final index = args.indexOf(flag);
  if (index >= 0 && index + 1 < args.length) {
    return args[index + 1];
  }
  return fallback;
}
