import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/participant_repository.dart';
import '../models/participant.dart';


class ParticipantsProvider extends ChangeNotifier {
  final ParticipantRepository _repository;
  final _uuid = const Uuid();

  ParticipantsProvider(this._repository);

  String? _tripId;
  List<Participant> _participants = [];
  bool _loading = false;

  List<Participant> get participants => List.unmodifiable(_participants);
  bool get loading => _loading;

  Future<void> loadForTrip(String tripId) async {
    _tripId = tripId;
    _loading = true;
    notifyListeners();
    _participants = await _repository.getForTrip(tripId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addParticipant({
    required String name,
    String contact = '',
    String notes = '',
    ParticipationStatus status = ParticipationStatus.confirmed,
    TripParticipantRole role = TripParticipantRole.participant,
  }) async {
    if (_tripId == null) return;
    final finalRole = _participants.isEmpty
        ? TripParticipantRole.organizer
        : role;
    final participant = Participant(
      id: _uuid.v4(),
      tripId: _tripId!,
      name: name,
      contact: contact,
      notes: notes,
      status: status,
      role: finalRole,
    );
    await _repository.create(participant);
    await loadForTrip(_tripId!);
  }

  Future<void> updateParticipant(Participant participant) async {
    await _repository.update(participant);
    if (_tripId != null) await loadForTrip(_tripId!);
  }

  Future<void> deleteParticipant(String id) async {
    await _repository.delete(id);
    if (_tripId != null) await loadForTrip(_tripId!);
  }
}
