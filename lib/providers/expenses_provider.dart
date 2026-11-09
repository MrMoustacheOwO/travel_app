import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/expense_repository.dart';
import '../models/activity.dart';
import '../models/expense.dart';
import '../models/spending_category.dart';
import '../models/ticket_info.dart';

class ExpensesProvider extends ChangeNotifier {
  final ExpenseRepository _repository;
  final _uuid = const Uuid();

  ExpensesProvider(this._repository);

  String? _tripId;
  List<Expense> _expenses = [];
  bool _loading = false;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Expense> get pendingConfirmations =>
      _expenses.where((e) => e.confirmation == ExpenseConfirmation.pending).toList();
  bool get loading => _loading;

  double get total => _expenses
      .where((e) => e.confirmation != ExpenseConfirmation.rejected)
      .fold(0.0, (sum, e) => sum + e.amount);

  Map<SpendingCategory, double> get totalByCategory {
    final map = <SpendingCategory, double>{};
    for (final e in _expenses) {
      if (e.confirmation == ExpenseConfirmation.rejected) continue;
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  double totalPaidByParticipant(String participantId) {
    return _expenses
        .where((e) =>
            e.paidByParticipantId == participantId &&
            e.confirmation == ExpenseConfirmation.confirmed)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> loadForTrip(String tripId) async {
    _tripId = tripId;
    _loading = true;
    notifyListeners();
    _expenses = await _repository.getForTrip(tripId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addExpense({
    String? activityId,
    required SpendingCategory category,
    required String name,
    required double amount,
    required DateTime date,
    String comment = '',
    String? paidByParticipantId,
    List<String> participantIds = const [],
    TicketInfo? ticket,
    ExpenseConfirmation confirmation = ExpenseConfirmation.confirmed,
  }) async {
    if (_tripId == null) return;
    final expense = Expense(
      id: _uuid.v4(),
      tripId: _tripId!,
      activityId: activityId,
      category: category,
      name: name,
      amount: amount,
      date: date,
      comment: comment,
      paidByParticipantId: paidByParticipantId,
      participantIds: List.of(participantIds),
      ticket: ticket,
      confirmation: confirmation,
    );
    await _repository.create(expense);
    await loadForTrip(_tripId!);
  }

  Future<void> updateExpense(Expense expense) async {
    await _repository.update(expense);
    if (_tripId != null) await loadForTrip(_tripId!);
  }

  Future<void> syncExpenseForActivity(TripActivity activity) async {
    if (_tripId != activity.tripId) {
      await loadForTrip(activity.tripId);
    } else if (_tripId != null && _expenses.isEmpty) {
      await loadForTrip(_tripId!);
    }

    Expense? existing;
    for (final e in _expenses) {
      if (e.activityId == activity.id) {
        existing = e;
        break;
      }
    }

    if (!activity.isCompleted || !activity.isPaid) {
      if (existing != null) await deleteExpense(existing.id);
      return;
    }

    final ticket = activity.isTickets ? activity.ticket.copy() : TicketInfo();
    if (existing == null) {
      await addExpense(
        activityId: activity.id,
        category: activity.category,
        name: activity.name,
        amount: activity.cost,
        date: activity.dateTime,
        participantIds: activity.participantIds,
        ticket: ticket,
        confirmation: ExpenseConfirmation.confirmed,
      );
    } else {
      existing
        ..name = activity.name
        ..amount = activity.cost
        ..category = activity.category
        ..date = activity.dateTime
        ..participantIds = List.of(activity.participantIds)
        ..ticket = ticket;
      await updateExpense(existing);
    }
  }

  Future<void> setConfirmation(String expenseId, ExpenseConfirmation status) async {
    final expense = _expenses.firstWhere((e) => e.id == expenseId);
    expense.confirmation = status;
    await _repository.update(expense);
    if (_tripId != null) await loadForTrip(_tripId!);
  }

  Future<void> deleteExpense(String id) async {
    await _repository.delete(id);
    if (_tripId != null) await loadForTrip(_tripId!);
  }
}
