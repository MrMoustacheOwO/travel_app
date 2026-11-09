class TripChatMessage {
  final String id;
  final String tripId;
  final String author;
  final String text;
  final DateTime createdAt;

  TripChatMessage({
    required this.id,
    required this.tripId,
    required this.author,
    required this.text,
    required this.createdAt,
  });
}

class TripChatStore {
  static final Map<String, List<TripChatMessage>> _messages = {};

  static List<TripChatMessage> messagesFor(String tripId) {
    final existing = _messages[tripId];
    if (existing != null && existing.isNotEmpty) {
      return List.unmodifiable(existing);
    }

    final seed = [
      TripChatMessage(
        id: 'welcome-${tripId.substring(0, 8)}',
        tripId: tripId,
        author: 'Организатор',
        text: 'Добро пожаловать в поездку! Здесь можно обсуждать план и статус расходов.',
        createdAt: DateTime.now(),
      ),
    ];

    _messages[tripId] = seed;
    return List.unmodifiable(seed);
  }

  static void sendMessage(String tripId, {required String author, required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final bucket = _messages.putIfAbsent(tripId, () => []);
    bucket.add(
      TripChatMessage(
        id: '${tripId}_${DateTime.now().microsecondsSinceEpoch}',
        tripId: tripId,
        author: author,
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );
  }
}
