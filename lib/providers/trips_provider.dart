import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/trip_repository.dart';
import '../models/trip.dart';

class TripsProvider extends ChangeNotifier {
  final TripRepository _repository;
  final _uuid = const Uuid();

  TripsProvider(this._repository);

  List<Trip> _trips = [];
  bool _loading = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get loading => _loading;

  Future<void> loadTrips() async {
    _loading = true;
    notifyListeners();
    _trips = await _repository.getAllTrips();
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
