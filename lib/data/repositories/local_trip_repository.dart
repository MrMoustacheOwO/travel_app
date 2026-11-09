import '../../models/trip.dart';
import '../db/database_helper.dart';
import 'auth_repository.dart';
import 'trip_repository.dart';

class LocalTripRepository implements TripRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalAuthRepository _authRepository = LocalAuthRepository();

  @override
  Future<List<Trip>> getAllTrips() async {
    final user = await _authRepository.getCurrentUser();
    if (user == null) return <Trip>[];

    final db = await _dbHelper.database;
    final rows = await db.query(
      'trips',
      where: 'user_id IS NULL OR user_id = ?',
      whereArgs: [user.id],
      orderBy: 'start_date DESC',
    );
    return rows.map((e) => Trip.fromMap(e)).toList();
  }

  @override
  Future<Trip?> getTripById(String id) async {
    final user = await _authRepository.getCurrentUser();
    if (user == null) return null;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'trips',
      where: 'id = ? AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [id, user.id],
    );
    if (rows.isEmpty) return null;
    return Trip.fromMap(rows.first);
  }

  @override
  Future<void> createTrip(Trip trip) async {
    final user = await _authRepository.getCurrentUser();
    if (user == null) return;

    final db = await _dbHelper.database;
    await db.insert('trips', {
      ...trip.toMap(),
      'user_id': user.id,
    });
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    final user = await _authRepository.getCurrentUser();
    if (user == null) return;

    final db = await _dbHelper.database;
    await db.update(
      'trips',
      {
        ...trip.toMap(),
        'user_id': user.id,
      },
      where: 'id = ? AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [trip.id, user.id],
    );
  }

  @override
  Future<void> deleteTrip(String id) async {
    final user = await _authRepository.getCurrentUser();
    if (user == null) return;

    final db = await _dbHelper.database;
    final activityRows = await db.query(
      'activities',
      columns: ['id'],
      where: 'trip_id = ?',
      whereArgs: [id],
    );
    for (final row in activityRows) {
      await db.delete('activity_participants', where: 'activity_id = ?', whereArgs: [row['id']]);
    }
    final expenseRows = await db.query(
      'expenses',
      columns: ['id'],
      where: 'trip_id = ?',
      whereArgs: [id],
    );
    for (final row in expenseRows) {
      await db.delete('expense_participants', where: 'expense_id = ?', whereArgs: [row['id']]);
    }
    await db.delete('expenses', where: 'trip_id = ?', whereArgs: [id]);
    await db.delete('activities', where: 'trip_id = ?', whereArgs: [id]);
    await db.delete('participants', where: 'trip_id = ?', whereArgs: [id]);
    await db.delete(
      'trips',
      where: 'id = ? AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [id, user.id],
    );
  }
}
