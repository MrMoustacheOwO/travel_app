enum TripStatus { planned, active, completed }

extension TripStatusLabel on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.planned:
        return 'Запланирована';
      case TripStatus.active:
        return 'Активна';
      case TripStatus.completed:
        return 'Завершена';
    }
  }
}

/// Модель поездки.
///
/// Поле [synced] и [remoteId] заранее подготовлены для будущей
/// синхронизации с сервером/БД: локальная запись создаётся с
/// уникальным [id] (uuid), а [remoteId] будет заполнен после того,
/// как объект будет создан на сервере.
class Trip {
  final String id;
  final String? userId;
  String name;
  DateTime startDate;
  DateTime endDate;
  int peopleCount;
  final DateTime createdAt;
  bool synced;
  String? remoteId;

  Trip({
    required this.id,
    this.userId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.peopleCount,
    DateTime? createdAt,
    this.synced = false,
    this.remoteId,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Статус вычисляется автоматически по датам поездки и текущей дате.
  TripStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (today.isBefore(start)) return TripStatus.planned;
    if (today.isAfter(end)) return TripStatus.completed;
    return TripStatus.active;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'people_count': peopleCount,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'remote_id': remoteId,
    };
  }

  factory Trip.fromMap(Map<String, Object?> map) {
    return Trip(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      peopleCount: map['people_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int? ?? 0) == 1,
      remoteId: map['remote_id'] as String?,
    );
  }

  /// Готово для отправки на будущий REST API.
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'peopleCount': peopleCount,
      };
}
