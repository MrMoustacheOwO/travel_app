import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/participant.dart';
import '../widgets/participant_multi_select.dart';
import '../widgets/ticket_form.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final Participant? paidBy;
  final List<Participant> participants;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.paidBy,
    this.participants = const [],
    this.onTap,
    this.onDelete,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final isPending = expense.confirmation == ExpenseConfirmation.pending;
    final isRejected = expense.confirmation == ExpenseConfirmation.rejected;
    final names = participantNames(participants, expense.participantIds);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isRejected ? Colors.grey.shade100 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expense.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${expense.category.label} · ${df.format(expense.date)}'),
                        if (paidBy != null) Text('Оплатил: ${paidBy!.name}'),
                        if (names.isNotEmpty)
                          Text('Участники: $names',
                              style: Theme.of(context).textTheme.bodySmall),
                        if (expense.comment.isNotEmpty)
                          Text(expense.comment,
                              style: Theme.of(context).textTheme.bodySmall),
                        if (expense.isTickets || expense.ticket.hasData)
                          TicketDetailsText(ticket: expense.ticket),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${expense.amount.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
              if (isPending && (onConfirm != null || onReject != null)) ...[
                const Divider(),
                Text(
                  'Ожидает подтверждения от организатора: '
                  '${expense.name}, ${expense.amount.toStringAsFixed(0)} ₽'
                  '${paidBy != null ? ' от ${paidBy!.name}' : ''}',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Отклонить'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onConfirm,
                      child: const Text('Подтвердить'),
                    ),
                  ],
                ),
              ],
              if (isRejected)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Отклонено', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
