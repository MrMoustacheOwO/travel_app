import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses_app/data/db/database_helper.dart';
import 'package:travel_expenses_app/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.close();
    await DatabaseHelper.resetDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await DatabaseHelper.resetDatabase();
  });

  group('LocalAuthRepository', () {
    test('register creates a user and active session', () async {
      final repository = LocalAuthRepository();

      final user = await repository.register(
        name: 'Test User',
        email: 'test@example.com',
        password: 'StrongPass123',
      );

      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(await repository.isAuthenticated(), isTrue);
      expect(await repository.getCurrentUser(), isNotNull);
    });

    test('login validates stored password and returns current user', () async {
      final repository = LocalAuthRepository();

      await repository.register(
        name: 'Alice',
        email: 'alice@example.com',
        password: 'StrongPass123',
      );

      final loggedInUser = await repository.login(
        email: 'alice@example.com',
        password: 'StrongPass123',
      );

      expect(loggedInUser.email, 'alice@example.com');
      expect(loggedInUser.name, 'Alice');
    });

    test('login rejects wrong password', () async {
      final repository = LocalAuthRepository();

      await repository.register(
        name: 'Bob',
        email: 'bob@example.com',
        password: 'StrongPass123',
      );

      expect(
        () => repository.login(
          email: 'bob@example.com',
          password: 'WrongPass',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('api auth surfaces connection errors as AuthException', () async {
      final repository = ApiAuthRepository(
        backendBaseUrl: 'http://127.0.0.1:1',
        client: _FailingHttpClient(),
      );

      expect(
        () => repository.register(
          name: 'N',
          email: 'n@example.com',
          password: 'StrongPass123',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  test('local database includes a user-scoped offline deletion queue',
      () async {
    final db = await DatabaseHelper.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(pending_deletions)');

    expect(columns.map((row) => row['name']), contains('table_name'));
    expect(columns.map((row) => row['name']), contains('record_id'));
    expect(columns.map((row) => row['name']), contains('user_id'));

    final profileColumns = await db.rawQuery('PRAGMA table_info(profile)');
    expect(profileColumns.map((row) => row['name']), contains('synced'));

    final tripColumns = await db.rawQuery('PRAGMA table_info(trips)');
    expect(tripColumns.map((row) => row['name']), contains('organizer_id'));

    final participantColumns =
        await db.rawQuery('PRAGMA table_info(participants)');
    expect(participantColumns.map((row) => row['name']), contains('user_id'));
  });
}

class _FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw http.ClientException('Backend unavailable');
  }
}
