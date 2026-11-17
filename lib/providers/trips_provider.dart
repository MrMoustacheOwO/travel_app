import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/trip_repository.dart';
import '../data/repositories/participant_repository.dart';
import '../models/trip.dart';

class TripsProvider extends ChangeNotifier {
  final TripRepository _repository;
  final _uuid = const Uuid();

  TripsProvider(this._repository,
      {ParticipantRepository? participantRepository})
      : _participantRepository = participantRepository;

  List<Trip> _trips = [];
  final ParticipantRepository? _participantRepository;
  final Map<String, int> _participantCounts = {};
  bool _loading = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get loading => _loading;

  Future<void> loadTrips() async {
    _loading = true;
    notifyListeners();
    _trips = await _repository.getAllTrips();
    _participantCounts.clear();
    final participantRepository = _participantRepository;
    if (participantRepository != null) {
      final counts = await Future.wait(_trips.map((trip) async {
        final participants = await participantRepository.getForTrip(trip.id);
        final guestCount = participants
            .where((participant) => participant.userId != trip.organizerId)
            .length;
        return guestCount + 1;
      }));
      for (var index = 0; index < _trips.length; index++) {
        _participantCounts[_trips[index].id] = counts[index];
      }
    }
    _loading = false;
    notifyListeners();
  }

  Trip? tripById(String id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  int participantCountFor(String tripId) => _participantCounts[tripId] ?? 1;

  Future<Trip> addTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int peopleCount,
  }) async {
    final trip = Trip(
      id: _uuid.v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      peopleCount: peopleCount,
    );
    await _repository.createTrip(trip);
    await loadTrips();
    return trip;
  }

  Future<void> updateTrip(Trip trip) async {
    await _repository.updateTrip(trip);
    await loadTrips();
  }

  Future<void> deleteTrip(String id) async {
    await _repository.deleteTrip(id);
    await loadTrips();
  }
}
