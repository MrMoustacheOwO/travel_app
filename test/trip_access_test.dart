import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses_app/data/repositories/participant_repository.dart';
import 'package:travel_expenses_app/data/repositories/trip_repository.dart';
import 'package:travel_expenses_app/models/participant.dart';
import 'package:travel_expenses_app/models/trip.dart';
import 'package:travel_expenses_app/providers/trips_provider.dart';
import 'package:travel_expenses_app/utils/trip_access.dart';

void main() {
  final trip = Trip(
    id: 'trip-1',
    userId: 'owner-id',
    organizerId: 'owner-id',
    name: 'Test trip',
    startDate: DateTime(2026, 11, 17),
    endDate: DateTime(2026, 11, 20),
    peopleCount: 1,
  );

  test('changing a guest role does not change trip ownership', () {
    final guest = Participant(
      id: 'guest-id',
      tripId: trip.id,
      name: 'Guest',
      role: TripParticipantRole.participant,
    );

    expect(guest.role, TripParticipantRole.participant);
    expect(isTripOrganizer(trip, 'owner-id'), isTrue);
    expect(isTripOrganizer(trip, 'guest-id'), isFalse);
  });

  test('organizer can manage shared legacy records without created-by data',
      () {
    expect(
      canManageTripRecord(
        isOrganizer: true,
        currentUserId: 'owner-id',
        createdBy: null,
        scope: 'shared',
      ),
      isTrue,
    );
    expect(
      canManageTripRecord(
        isOrganizer: false,
        currentUserId: 'member-id',
        createdBy: null,
        scope: 'shared',
      ),
      isFalse,
    );
    expect(
      canManageTripRecord(
        isOrganizer: true,
        currentUserId: 'owner-id',
        createdBy: 'member-id',
        scope: 'shared',
      ),
      isFalse,
    );
  });

  test('members only see records assigned to their participant entry', () {
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: ['member-a'],
        currentParticipantId: 'member-b',
      ),
      isFalse,
    );
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: ['member-a'],
        currentParticipantId: 'member-a',
      ),
      isTrue,
    );
    expect(
      isRecordVisibleToUser(
        isOrganizer: true,
        participantIds: const [],
        currentParticipantId: null,
      ),
      isTrue,
    );
  });

  test(
      'shared records with no assigned participants are not visible to members',
      () {
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: const [],
        currentParticipantId: 'member-a',
        currentUserId: 'member-a-user',
        organizerId: 'owner-id',
        createdBy: 'member-b-user',
        scope: 'shared',
      ),
      isFalse,
    );
  });

  test('shared records with assigned participants remain selective', () {
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: ['member-a'],
        currentParticipantId: 'member-b',
        currentUserId: 'member-b-user',
        createdBy: 'member-a-user',
        scope: 'shared',
      ),
      isFalse,
    );
  });

  test('organizer cannot see a shared record created by a member', () {
    expect(
      isRecordVisibleToUser(
        isOrganizer: true,
        participantIds: ['member-a'],
        currentParticipantId: null,
        currentUserId: 'owner-id',
        organizerId: 'owner-id',
        createdBy: 'member-a-user',
        scope: 'shared',
      ),
      isFalse,
    );
  });

  test('members see organizer shared records read-only and own private records',
      () {
    expect(
      isRecordVisibleToUser(
        isOrganizer: true,
        participantIds: const [],
        currentParticipantId: null,
        currentUserId: 'owner-id',
        organizerId: 'owner-id',
        createdBy: 'member-user',
        scope: 'private',
      ),
      isFalse,
    );
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: ['member-a'],
        currentParticipantId: 'member-a',
        currentUserId: 'member-user',
        organizerId: 'owner-id',
        createdBy: 'owner-id',
        scope: 'shared',
      ),
      isTrue,
    );
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: const [],
        currentParticipantId: 'member-a',
        currentUserId: 'member-user',
        organizerId: 'owner-id',
        createdBy: 'member-user',
        scope: 'private',
      ),
      isTrue,
    );
    expect(
      isRecordVisibleToUser(
        isOrganizer: false,
        participantIds: const [],
        currentParticipantId: 'member-b',
        currentUserId: 'another-user',
        organizerId: 'owner-id',
        createdBy: 'member-user',
        scope: 'private',
      ),
      isFalse,
    );
  });

  test('home count is derived from the organizer and trip members', () async {
    final provider = TripsProvider(
      _TripRepository(trip),
      participantRepository: _ParticipantRepository([
        Participant(id: 'member-a', tripId: trip.id, name: 'A'),
        Participant(id: 'member-b', tripId: trip.id, name: 'B'),
        Participant(
          id: 'member-c',
          tripId: trip.id,
          name: 'C',
          status: ParticipationStatus.declined,
        ),
      ]),
    );

    await provider.loadTrips();

    expect(provider.participantCountFor(trip.id), 3);
  });
}

class _TripRepository implements TripRepository {
  _TripRepository(this.trip);

  final Trip trip;

  @override
  Future<List<Trip>> getAllTrips() async => [trip];

  @override
  Future<Trip?> getTripById(String id) async => id == trip.id ? trip : null;

  @override
  Future<void> createTrip(Trip trip) async {}

  @override
  Future<void> updateTrip(Trip trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}
}

class _ParticipantRepository implements ParticipantRepository {
  _ParticipantRepository(this.participants);

  final List<Participant> participants;

  @override
  Future<List<Participant>> getForTrip(String tripId) async => participants
      .where((participant) => participant.tripId == tripId)
      .toList();

  @override
  Future<void> create(Participant participant) async {}

  @override
  Future<void> update(Participant participant) async {}

  @override
  Future<void> delete(String id) async {}
}
