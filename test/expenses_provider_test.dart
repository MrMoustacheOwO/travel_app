import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses_app/data/repositories/expense_repository.dart';
import 'package:travel_expenses_app/models/activity.dart';
import 'package:travel_expenses_app/models/expense.dart';
import 'package:travel_expenses_app/models/spending_category.dart';
import 'package:travel_expenses_app/providers/expenses_provider.dart';

void main() {
  test('activity cost creates and updates an expense until cost is zero',
      () async {
    final repository = _MemoryExpenseRepository();
    final provider = ExpensesProvider(repository);
    await provider.loadForTrip('trip-1');
    final activity = TripActivity(
      id: 'activity-1',
      tripId: 'trip-1',
      name: 'Museum',
      category: SpendingCategory.entertainment,
      dateTime: DateTime(2026),
      cost: 25,
    );

    await provider.syncExpenseForActivity(activity);

    expect(provider.expenses, hasLength(1));
    expect(provider.expenses.single.activityId, activity.id);
    expect(provider.expenses.single.amount, 25);

    activity.cost = 40;
    await provider.syncExpenseForActivity(activity);

    expect(provider.expenses, hasLength(1));
    expect(provider.expenses.single.amount, 40);

    activity.cost = 0;
    await provider.syncExpenseForActivity(activity);

    expect(provider.expenses, isEmpty);
    provider.dispose();
  });
}

class _MemoryExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<List<Expense>> getForTrip(String tripId) async =>
      _expenses.where((expense) => expense.tripId == tripId).toList();

  @override
  Future<void> create(Expense expense) async => _expenses.add(expense);

  @override
  Future<void> update(Expense expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index >= 0) _expenses[index] = expense;
  }

  @override
  Future<void> delete(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
  }
}
