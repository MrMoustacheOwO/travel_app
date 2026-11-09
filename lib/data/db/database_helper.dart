import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Обёртка над локальной SQLite базой данных.
///
/// Вся работа с данными в приложении идёт через репозитории
/// (см. lib/data/repositories), а не напрямую через этот класс —
/// это позволяет в будущем заменить локальную реализацию репозитория
/// на реализацию, которая обращается к серверному REST API / БД,
/// не меняя код экранов и провайдеров.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'travel_expenses.db';
  static const _dbVersion = 5;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    instance._database = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        people_count INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE participants (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        contact TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'confirmed',        role TEXT NOT NULL DEFAULT 'participant',        synced INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        date_time TEXT NOT NULL,
        location TEXT,
        description TEXT,
        cost REAL NOT NULL DEFAULT 0,
        is_main INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        transport_type TEXT,
        ticket_number TEXT,
        transport_number TEXT,
        departure_date TEXT,
        arrival_date TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        activity_id TEXT,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        comment TEXT,
        paid_by_participant_id TEXT,
        confirmation TEXT NOT NULL DEFAULT 'confirmed',
        transport_type TEXT,
        ticket_number TEXT,
        transport_number TEXT,
        departure_date TEXT,
        arrival_date TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE SET NULL,
        FOREIGN KEY (paid_by_participant_id) REFERENCES participants (id) ON DELETE SET NULL
      )
    ''');

    await _createLinkTables(db);

    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        user_id TEXT UNIQUE,
        name TEXT,
        email TEXT,
        photo_path TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE activities ADD COLUMN transport_type TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN ticket_number TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN transport_number TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN departure_date TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN arrival_date TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN transport_type TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN ticket_number TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN transport_number TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN departure_date TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN arrival_date TEXT');
      await _createLinkTables(db);
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE activities ADD COLUMN is_main INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE activities ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        UPDATE activities
        SET is_completed = 1
        WHERE id IN (
          SELECT activity_id FROM expenses WHERE activity_id IS NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
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
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_sessions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('ALTER TABLE trips ADD COLUMN user_id TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS profile (
          id TEXT PRIMARY KEY,
          user_id TEXT UNIQUE,
          name TEXT,
          email TEXT,
          photo_path TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE participants ADD COLUMN role TEXT NOT NULL DEFAULT 'participant'",
      );
    }
  }

  Future<void> _createLinkTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_participants (
        activity_id TEXT NOT NULL,
        participant_id TEXT NOT NULL,
        PRIMARY KEY (activity_id, participant_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_participants (
        expense_id TEXT NOT NULL,
        participant_id TEXT NOT NULL,
        PRIMARY KEY (expense_id, participant_id)
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
