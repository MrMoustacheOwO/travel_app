import 'spending_category.dart';
import 'ticket_info.dart';

class TripActivity {
  final String id;
  final String tripId;
  String name;
  SpendingCategory category;
  DateTime dateTime;
  String location;
  String description;
  double cost;
  bool isMain;
  bool isCompleted;
  TicketInfo ticket;
  List<String> participantIds;
  bool synced;
  String? remoteId;

  TripActivity({
    required this.id,
    required this.tripId,
    required this.name,
    required this.category,
    required this.dateTime,
    this.location = '',
    this.description = '',
    this.cost = 0,
    this.isMain = false,
    this.isCompleted = false,
    TicketInfo? ticket,
    List<String>? participantIds,
    this.synced = false,
    this.remoteId,
  })  : ticket = ticket ?? TicketInfo(),
        participantIds = participantIds ?? [];

  bool get isPaid => cost > 0;
  bool get isTickets => category == SpendingCategory.tickets;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'category': category.storageKey,
      'date_time': dateTime.toIso8601String(),
      'location': location,
      'description': description,
      'cost': cost,
      'is_main': isMain ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      ...ticket.toMap(),
      'synced': synced ? 1 : 0,
      'remote_id': remoteId,
    };
  }

  factory TripActivity.fromMap(Map<String, Object?> map) {
    return TripActivity(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      name: map['name'] as String,
      category: SpendingCategory.fromStorageKey(map['category'] as String),
      dateTime: DateTime.parse(map['date_time'] as String),
      location: map['location'] as String? ?? '',
      description: map['description'] as String? ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      isMain: (map['is_main'] as int? ?? 0) == 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      ticket: TicketInfo.fromMap(map),
      synced: (map['synced'] as int? ?? 0) == 1,
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'name': name,
        'category': category.storageKey,
        'dateTime': dateTime.toIso8601String(),
        'location': location,
        'description': description,
        'cost': cost,
        'isMain': isMain,
        'isCompleted': isCompleted,
        'ticket': ticket.toMap(),
        'participantIds': participantIds,
      };
}
