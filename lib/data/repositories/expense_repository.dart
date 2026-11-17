import '../../models/expense.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getForTrip(String tripId);
  Future<void> create(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(String id);
}

class LocalExpenseRepository implements ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final void Function()? _onChanged;

  LocalExpenseRepository({void Function()? onChanged}) : _onChanged = onChanged;

  @override
  Future<List<Expense>> getForTrip(String tripId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('expenses',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'date DESC');
    final expenses = rows.map((e) => Expense.fromMap(e)).toList();
    for (final expense in expenses) {
      expense.participantIds = await _participantIds(expense.id);
    }
    return expenses;
  }

  @override
  Future<void> create(Expense expense) async {
    final db = await _dbHelper.database;
    await db.insert('expenses', {...expense.toMap(), 'synced': 0});
    await _replaceParticipants(expense.id, expense.participantIds);
    _onChanged?.call();
  }

  @override
  Future<void> update(Expense expense) async {
    final db = await _dbHelper.database;
    await db.update('expenses', {...expense.toMap(), 'synced': 0},
        where: 'id = ?', whereArgs: [expense.id]);
    await _replaceParticipants(expense.id, expense.participantIds);
    _onChanged?.call();
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final expenseRows = await db.query(
      'expenses',
      columns: ['trip_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final tripRows = expenseRows.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'trips',
            columns: ['user_id'],
            where: 'id = ?',
            whereArgs: [expenseRows.first['trip_id']],
            limit: 1,
          );
    await db.insert(
      'pending_deletions',
      {
        'table_name': 'expenses',
        'record_id': id,
        'user_id': tripRows.isEmpty ? null : tripRows.first['user_id'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete('expense_participants',
        where: 'expense_id = ?', whereArgs: [id]);
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    _onChanged?.call();
  }

  Future<List<String>> _participantIds(String expenseId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'expense_participants',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return rows.map((e) => e['participant_id'] as String).toList();
  }

  Future<void> _replaceParticipants(String expenseId, List<String> ids) async {
    final db = await _dbHelper.database;
    await db.delete('expense_participants',
        where: 'expense_id = ?', whereArgs: [expenseId]);
    for (final participantId in ids) {
      await db.insert('expense_participants', {
        'expense_id': expenseId,
        'participant_id': participantId,
      });
    }
  }
}
