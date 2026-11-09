enum TransportKind {
  plane('Самолёт'),
  train('Поезд'),
  bus('Автобус'),
  ship('Корабль / паром'),
  taxi('Такси / трансфер'),
  other('Другое');

  final String label;
  const TransportKind(this.label);

  static TransportKind fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return TransportKind.other;
    return TransportKind.values.firstWhere(
      (e) => e.name == key,
      orElse: () => TransportKind.other,
    );
  }
}

/// Данные билета для активности или расхода категории «Билеты».
class TicketInfo {
  TransportKind transportKind;
  String ticketNumber;
  String transportNumber;
  DateTime? departureDate;
  DateTime? arrivalDate;

  TicketInfo({
    this.transportKind = TransportKind.other,
    this.ticketNumber = '',
    this.transportNumber = '',
    this.departureDate,
    this.arrivalDate,
  });

  bool get hasData =>
      ticketNumber.trim().isNotEmpty ||
      transportNumber.trim().isNotEmpty ||
      departureDate != null ||
      arrivalDate != null;

  Map<String, Object?> toMap() {
    return {
      'transport_type': transportKind.name,
      'ticket_number': ticketNumber,
      'transport_number': transportNumber,
      'departure_date': departureDate?.toIso8601String(),
      'arrival_date': arrivalDate?.toIso8601String(),
    };
  }

  factory TicketInfo.fromMap(Map<String, Object?> map) {
    return TicketInfo(
      transportKind: TransportKind.fromStorageKey(map['transport_type'] as String?),
      ticketNumber: map['ticket_number'] as String? ?? '',
      transportNumber: map['transport_number'] as String? ?? '',
      departureDate: _parseDate(map['departure_date']),
      arrivalDate: _parseDate(map['arrival_date']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  TicketInfo copy() {
    return TicketInfo(
      transportKind: transportKind,
      ticketNumber: ticketNumber,
      transportNumber: transportNumber,
      departureDate: departureDate,
      arrivalDate: arrivalDate,
    );
  }
}
