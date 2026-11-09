enum ParticipationStatus { invited, confirmed, declined }

enum TripParticipantRole { organizer, participant }

extension ParticipationStatusLabel on ParticipationStatus {
  String get label {
    switch (this) {
      case ParticipationStatus.invited:
        return 'Приглашён';
      case ParticipationStatus.confirmed:
        return 'Подтвердил участие';
      case ParticipationStatus.declined:
        return 'Отказался';
    }
  }
}

extension TripParticipantRoleLabel on TripParticipantRole {
  String get label {
    switch (this) {
      case TripParticipantRole.organizer:
        return 'Организатор';
      case TripParticipantRole.participant:
        return 'Участник';
    }
  }
}

class Participant {
  final String id;
  final String tripId;
  String name;
  String contact;
  String notes;
  ParticipationStatus status;
  TripParticipantRole role;
  bool synced;
  String? remoteId;

  Participant({
    required this.id,
    required this.tripId,
    required this.name,
    this.contact = '',
    this.notes = '',
    this.status = ParticipationStatus.confirmed,
    this.role = TripParticipantRole.participant,
    this.synced = false,
    this.remoteId,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'name': name,
      'contact': contact,
      'notes': notes,
      'status': status.name,
      'role': role.name,
      'synced': synced ? 1 : 0,
      'remote_id': remoteId,
    };
  }

  factory Participant.fromMap(Map<String, Object?> map) {
    return Participant(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      name: map['name'] as String,
      contact: map['contact'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: ParticipationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ParticipationStatus.confirmed,
      ),
      role: TripParticipantRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => TripParticipantRole.participant,
      ),
      synced: (map['synced'] as int? ?? 0) == 1,
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'name': name,
        'contact': contact,
        'notes': notes,
        'status': status.name,
      };
}
