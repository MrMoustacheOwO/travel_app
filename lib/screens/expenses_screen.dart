import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/participant.dart';
import '../models/spending_category.dart';
import '../models/trip.dart';
import '../providers/expenses_provider.dart';
import '../providers/participants_provider.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final Trip trip;

  const ExpensesScreen({super.key, required this.trip});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Set<SpendingCategory> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
    });
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      context.read<ExpensesProvider>().loadForTrip(widget.trip.id);
      context.read<ParticipantsProvider>().loadForTrip(widget.trip.id);
    }
  }

  bool _isOrganizer(List<Participant> participants) {
    if (participants.isEmpty) return true;
    return participants.first.role == TripParticipantRole.organizer;
  }

  @override
  Widget build(BuildContext context) {
    final expensesProvider = context.watch<ExpensesProvider>();
    final participantsProvider = context.watch<ParticipantsProvider>();
    final isOrganizer = _isOrganizer(participantsProvider.participants);

    final filteredExpenses = expensesProvider.expenses
        .where((e) =>
            _selectedCategories.isEmpty ||
            _selectedCategories.contains(e.category))
        .toList();
    final confirmedExpenses = filteredExpenses
        .where((e) => e.confirmation != ExpenseConfirmation.pending)
        .toList();
    final pending = filteredExpenses
        .where((e) => e.confirmation == ExpenseConfirmation.pending)
        .toList();

    return Scaffold(
      body: expensesProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              children: [
                _StatsCard(expenses: filteredExpenses),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CategoryFilterButton(
                      selected: _selectedCategories,
                      onChanged: (value) =>
                          setState(() => _selectedCategories = value),
                    ),
                  ),
                ),
                if (pending.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Ожидают подтверждения',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  for (final e in pending)
                    ExpenseTile(
                      expense: e,
                      paidBy: _findParticipant(
                          participantsProvider, e.paidByParticipantId),
                      participants: participantsProvider.participants,
                      onTap: () => _openExpense(e, readOnly: !isOrganizer),
                      onConfirm: isOrganizer
                          ? () => context
                              .read<ExpensesProvider>()
                              .setConfirmation(e.id, ExpenseConfirmation.confirmed)
                          : null,
                      onReject: isOrganizer
                          ? () => context
                              .read<ExpensesProvider>()
                              .setConfirmation(e.id, ExpenseConfirmation.rejected)
                          : null,
                      onDelete: isOrganizer ? () => _deleteExpense(e) : null,
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Все расходы',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (confirmedExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Расходов пока нет')),
                  ),
                for (final e in confirmedExpenses)
                  ExpenseTile(
                    expense: e,
                    paidBy: _findParticipant(
                        participantsProvider, e.paidByParticipantId),
                    participants: participantsProvider.participants,
                    onTap: () => _openExpense(e, readOnly: !isOrganizer),
                    onDelete: isOrganizer ? () => _deleteExpense(e) : null,
                  ),
              ],
            ),
      floatingActionButton: isOrganizer
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(tripId: widget.trip.id),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _openExpense(Expense expense, {bool readOnly = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          tripId: widget.trip.id,
          expense: expense,
          readOnly: readOnly,
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final ok = await confirmDelete(
      context,
      title: 'Удалить расход?',
      content: 'Расход «${expense.name}» будет удалён.',
    );
    if (!ok || !mounted) return;
    await context.read<ExpensesProvider>().deleteExpense(expense.id);
  }

  _findParticipant(ParticipantsProvider p, String? id) {
    if (id == null) return null;
    try {
      return p.participants.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

class _StatsCard extends StatelessWidget {
  final List<Expense> expenses;

  const _StatsCard({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final byCategory = <SpendingCategory, double>{};
    var total = 0.0;
    for (final expense in expenses) {
      if (expense.confirmation == ExpenseConfirmation.rejected) continue;
      total += expense.amount;
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + expense.amount;
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Итого потрачено: ${total.toStringAsFixed(0)} ₽',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (byCategory.isEmpty) const Text('Пока нет данных по категориям'),
            for (final entry in byCategory.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.label),
                    Text('${entry.value.toStringAsFixed(0)} ₽'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
