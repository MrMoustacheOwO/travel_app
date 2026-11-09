import '../../models/expense.dart';
import '../db/database_helper.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getForTrip(String tripId);
  Future<void> create(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(String id);
}

class LocalExpenseRepository implements ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
    await db.insert('expenses', expense.toMap());
    await _replaceParticipants(expense.id, expense.participantIds);
  }

  @override
  Future<void> update(Expense expense) async {
    final db = await _dbHelper.database;
    await db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
    await _replaceParticipants(expense.id, expense.participantIds);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('expense_participants',
        where: 'expense_id = ?', whereArgs: [id]);
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
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
