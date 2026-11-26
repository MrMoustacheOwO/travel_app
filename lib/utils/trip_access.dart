import '../models/participant.dart';
import '../models/trip.dart';

bool isTripOrganizer(Trip? trip, String? userId) {
  if (trip == null || userId == null) return false;
  return (trip.organizerId ?? trip.userId) == userId;
}

bool canManageTripRecord({
  required bool isOrganizer,
  required String? currentUserId,
  required String? createdBy,
  required String scope,
}) {
  return (currentUserId != null && createdBy == currentUserId) ||
      (isOrganizer && createdBy == null && scope == 'shared');
}

Participant? participantForUser(
  List<Participant> participants, {
  required String? userId,
  required String? email,
}) {
  if (userId != null) {
    for (final participant in participants) {
      if (participant.userId == userId) return participant;
    }
  }

  final normalizedEmail = email?.trim().toLowerCase();
  if (normalizedEmail == null || normalizedEmail.isEmpty) return null;
  for (final participant in participants) {
    if (participant.contact.trim().toLowerCase() == normalizedEmail) {
      return participant;
    }
  }
  return null;
}

bool isRecordVisibleToUser({
  required bool isOrganizer,
  required List<String> participantIds,
  required String? currentParticipantId,
  String? currentUserId,
  String? organizerId,
  String? createdBy,
  String scope = 'shared',
}) {
  if (scope == 'private') {
    return currentUserId != null && createdBy == currentUserId;
  }
  if (currentUserId != null && createdBy == currentUserId) return true;
  if (isOrganizer) return createdBy == null;
  return currentParticipantId != null &&
      participantIds.contains(currentParticipantId);
}
