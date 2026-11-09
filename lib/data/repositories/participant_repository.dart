import '../../models/participant.dart';
import '../db/database_helper.dart';

abstract class ParticipantRepository {
  Future<List<Participant>> getForTrip(String tripId);
  Future<void> create(Participant participant);
  Future<void> update(Participant participant);
  Future<void> delete(String id);
}

class LocalParticipantRepository implements ParticipantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
    await db.insert('participants', participant.toMap());
  }

  @override
  Future<void> update(Participant participant) async {
    final db = await _dbHelper.database;
    await db.update('participants', participant.toMap(),
        where: 'id = ?', whereArgs: [participant.id]);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('participants', where: 'id = ?', whereArgs: [id]);
  }
}
