import '../../models/participant.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

abstract class ParticipantRepository {
  Future<List<Participant>> getForTrip(String tripId);
  Future<void> create(Participant participant);
  Future<void> update(Participant participant);
  Future<void> delete(String id);
}

class LocalParticipantRepository implements ParticipantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final void Function()? _onChanged;

  LocalParticipantRepository({void Function()? onChanged})
      : _onChanged = onChanged;

  @override
  Future<List<Participant>> getForTrip(String tripId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('participants',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'name ASC');
    return rows.map((e) => Participant.fromMap(e)).toList();
  }

  @override
  Future<void> create(Participant participant) async {
    final db = await _dbHelper.database;
    await db.insert('participants', {...participant.toMap(), 'synced': 0});
    _onChanged?.call();
  }

  @override
  Future<void> update(Participant participant) async {
    final db = await _dbHelper.database;
    await db.update('participants', {...participant.toMap(), 'synced': 0},
        where: 'id = ?', whereArgs: [participant.id]);
    _onChanged?.call();
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final participantRows = await db.query(
      'participants',
      columns: ['trip_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final tripRows = participantRows.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'trips',
            columns: ['user_id'],
            where: 'id = ?',
            whereArgs: [participantRows.first['trip_id']],
            limit: 1,
          );
    await db.insert(
      'pending_deletions',
      {
        'table_name': 'participants',
        'record_id': id,
        'user_id': tripRows.isEmpty ? null : tripRows.first['user_id'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete('participants', where: 'id = ?', whereArgs: [id]);
    _onChanged?.call();
  }
}
