import 'spending_category.dart';
import 'ticket_info.dart';

/// Статус подтверждения платежа участника организатором поездки.
enum ExpenseConfirmation { confirmed, pending, rejected }

class Expense {
  final String id;
  final String tripId;
  String? activityId;
  SpendingCategory category;
  String name;
  double amount;
  DateTime date;
  String comment;
  String? paidByParticipantId;
  List<String> participantIds;
  TicketInfo ticket;
  ExpenseConfirmation confirmation;
  bool synced;
  String? remoteId;

  Expense({
    required this.id,
    required this.tripId,
    this.activityId,
    required this.category,
    required this.name,
    required this.amount,
    required this.date,
    this.comment = '',
    this.paidByParticipantId,
    List<String>? participantIds,
    TicketInfo? ticket,
    this.confirmation = ExpenseConfirmation.confirmed,
    this.synced = false,
    this.remoteId,
  })  : participantIds = participantIds ?? [],
        ticket = ticket ?? TicketInfo();

  bool get isTickets => category == SpendingCategory.tickets;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'activity_id': activityId,
      'category': category.storageKey,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
      'comment': comment,
      'paid_by_participant_id': paidByParticipantId,
      'confirmation': confirmation.name,
      ...ticket.toMap(),
      'synced': synced ? 1 : 0,
      'remote_id': remoteId,
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      activityId: map['activity_id'] as String?,
      category: SpendingCategory.fromStorageKey(map['category'] as String),
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      comment: map['comment'] as String? ?? '',
      paidByParticipantId: map['paid_by_participant_id'] as String?,
      ticket: TicketInfo.fromMap(map),
      confirmation: ExpenseConfirmation.values.firstWhere(
        (e) => e.name == map['confirmation'],
        orElse: () => ExpenseConfirmation.confirmed,
      ),
      synced: (map['synced'] as int? ?? 0) == 1,
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'activityId': activityId,
        'category': category.storageKey,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String(),
        'comment': comment,
        'paidByParticipantId': paidByParticipantId,
        'participantIds': participantIds,
        'ticket': ticket.toMap(),
        'confirmation': confirmation.name,
      };
}
