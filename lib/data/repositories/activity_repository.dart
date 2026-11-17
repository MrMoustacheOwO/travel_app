import '../../models/activity.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

abstract class ActivityRepository {
  Future<List<TripActivity>> getForTrip(String tripId);
  Future<void> create(TripActivity activity);
  Future<void> update(TripActivity activity);
  Future<void> delete(String id);
}

class LocalActivityRepository implements ActivityRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final void Function()? _onChanged;

  LocalActivityRepository({void Function()? onChanged})
      : _onChanged = onChanged;

  @override
  Future<List<TripActivity>> getForTrip(String tripId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('activities',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'date_time ASC');
    final activities = rows.map((e) => TripActivity.fromMap(e)).toList();
    for (final activity in activities) {
      activity.participantIds = await _participantIds(activity.id);
    }
    return activities;
  }

  @override
  Future<void> create(TripActivity activity) async {
    final db = await _dbHelper.database;
    await db.insert('activities', {...activity.toMap(), 'synced': 0});
    await _replaceParticipants(activity.id, activity.participantIds);
    _onChanged?.call();
  }

  @override
  Future<void> update(TripActivity activity) async {
    final db = await _dbHelper.database;
    await db.update('activities', {...activity.toMap(), 'synced': 0},
        where: 'id = ?', whereArgs: [activity.id]);
    await _replaceParticipants(activity.id, activity.participantIds);
    _onChanged?.call();
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final activityRows = await db.query(
      'activities',
      columns: ['trip_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final tripRows = activityRows.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'trips',
            columns: ['user_id'],
            where: 'id = ?',
            whereArgs: [activityRows.first['trip_id']],
            limit: 1,
          );
    final userId = tripRows.isEmpty ? null : tripRows.first['user_id'];
    await db.delete('activity_participants',
        where: 'activity_id = ?', whereArgs: [id]);
    final linkedExpenses = await db.query('expenses',
        columns: ['id'], where: 'activity_id = ?', whereArgs: [id]);
    for (final row in linkedExpenses) {
      await db.insert(
        'pending_deletions',
        {
          'table_name': 'expenses',
          'record_id': row['id'],
          'user_id': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.delete('expense_participants',
          where: 'expense_id = ?', whereArgs: [row['id']]);
    }
    await db.insert(
      'pending_deletions',
      {'table_name': 'activities', 'record_id': id, 'user_id': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete('expenses', where: 'activity_id = ?', whereArgs: [id]);
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
    _onChanged?.call();
  }

  Future<List<String>> _participantIds(String activityId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'activity_participants',
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
    return rows.map((e) => e['participant_id'] as String).toList();
  }

  Future<void> _replaceParticipants(String activityId, List<String> ids) async {
    final db = await _dbHelper.database;
    await db.delete('activity_participants',
        where: 'activity_id = ?', whereArgs: [activityId]);
    for (final participantId in ids) {
      await db.insert('activity_participants', {
        'activity_id': activityId,
        'participant_id': participantId,
      });
    }
  }
}
