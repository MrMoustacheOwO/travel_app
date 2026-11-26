class TripChatMessage {
  final String id;
  final String tripId;
  final String authorId;
  final String text;
  final DateTime createdAt;

  TripChatMessage({
    required this.id,
    required this.tripId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });
}
