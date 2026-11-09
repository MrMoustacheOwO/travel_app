import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/activity_repository.dart';
import '../models/activity.dart';
import '../models/spending_category.dart';
import '../models/ticket_info.dart';

class ActivitiesProvider extends ChangeNotifier {
  final ActivityRepository _repository;
  final _uuid = const Uuid();

  ActivitiesProvider(this._repository);

  String? _tripId;
  List<TripActivity> _activities = [];
  bool _loading = false;

  List<TripActivity> get activities => List.unmodifiable(_activities);
  bool get loading => _loading;

  Future<void> loadForTrip(String tripId) async {
    _tripId = tripId;
    _loading = true;
    notifyListeners();
    _activities = await _repository.getForTrip(tripId);
    _loading = false;
    notifyListeners();
  }

  Future<TripActivity?> addActivity({
    required String name,
    required SpendingCategory category,
    required DateTime dateTime,
    String location = '',
    String description = '',
    double cost = 0,
    bool isMain = false,
    TicketInfo? ticket,
    List<String> participantIds = const [],
  }) async {
    if (_tripId == null) return null;
    final activity = TripActivity(
      id: _uuid.v4(),
      tripId: _tripId!,
      name: name,
      category: category,
      dateTime: dateTime,
      location: location,
      description: description,
      cost: cost,
      isMain: isMain,
      ticket: ticket,
      participantIds: List.of(participantIds),
    );
    await _repository.create(activity);
    await loadForTrip(_tripId!);
    return activity;
  }

  Future<void> updateActivity(TripActivity activity) async {
    await _repository.update(activity);
    if (_tripId != null) await loadForTrip(_tripId!);
  }

  Future<void> deleteActivity(String id) async {
    await _repository.delete(id);
    if (_tripId != null) await loadForTrip(_tripId!);
  }
}
