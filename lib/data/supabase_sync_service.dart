import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'db/database_helper.dart';

class SupabaseSyncService extends ChangeNotifier {
  SupabaseSyncService({
    required SupabaseClient client,
    DatabaseHelper? databaseHelper,
  })  : _client = client,
        _databaseHelper = databaseHelper ?? DatabaseHelper.instance {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  final SupabaseClient _client;
  final DatabaseHelper _databaseHelper;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _syncing = false;
  bool _syncRequestedAgain = false;
  String? _error;

  bool get syncing => _syncing;
  String? get error => _error;

  void requestSync() {
    if (_syncing) {
      _syncRequestedAgain = true;
      return;
    }
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_client.auth.currentUser == null) return;
    if (_syncing) {
      _syncRequestedAgain = true;
      return;
    }

    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      await _syncData();
    } catch (error) {
      try {
        await _forceSyncFromServer();
      } catch (recoveryError) {
        _error = '${_formatSyncError(error)} '
            'Повторная загрузка с сервера также не удалась: '
            '${_formatSyncError(recoveryError)}';
      }
    } finally {
      _syncing = false;
      notifyListeners();
      if (_syncRequestedAgain) {
        _syncRequestedAgain = false;
        requestSync();
      }
    }
  }

  Future<void> inviteTripMember({
    required String tripId,
    required String email,
    required String displayName,
    String notes = '',
  }) async {
    await _client.rpc('invite_trip_member', params: {
      'p_trip_id': tripId,
      'p_email': email.trim().toLowerCase(),
      'p_display_name': displayName.trim(),
      'p_notes': notes.trim(),
    }).timeout(SupabaseConfig.requestTimeout);
    await syncNow();
  }

  Future<void> respondToTripInvitation({
    required String tripId,
    required String membershipId,
    required bool accept,
  }) async {
    await _client.rpc('respond_to_trip_invitation', params: {
      'p_membership_id': membershipId,
      'p_accept': accept,
    }).timeout(SupabaseConfig.requestTimeout);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final db = await _databaseHelper.database;
    await db.update(
      'trips',
      {'membership_status': accept ? 'confirmed' : 'declined'},
      where: 'id = ? AND user_id = ?',
      whereArgs: [tripId, userId],
    );
    if (accept) await syncNow();
  }

  Future<void> _syncData({bool pullOnly = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final db = await _databaseHelper.database;
    if (!pullOnly) await _claimLegacyCache(db, user);
    await _syncProfile(db, user, pullOnly: pullOnly);
    if (!pullOnly) await _syncPendingDeletions(db);

    if (!pullOnly) await _pushTrips(db, user);
    final remoteTrips = await _client
        .from('trips')
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .timeout(SupabaseConfig.requestTimeout);
    final tripIds = <String>{};
    for (final remote in remoteTrips) {
      final tripId = remote['id'] as String;
      tripIds.add(tripId);
      await _cacheTrip(db, remote, user.id);
    }

    final localTrips = await db.query(
      'trips',
      where: 'user_id = ?',
      whereArgs: [user.id],
    );
    tripIds.addAll(localTrips.map((row) => row['id'] as String));
    for (final tripId in tripIds) {
      await _syncParticipants(db, tripId, pushLocal: !pullOnly);
      await _syncActivities(db, tripId, pushLocal: !pullOnly);
      await _syncExpenses(db, tripId, user.id, pushLocal: !pullOnly);
    }
  }

  Future<void> _forceSyncFromServer() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final db = await _databaseHelper.database;
    final tripRows = await db.query(
      'trips',
      where: 'user_id = ?',
      whereArgs: [user.id],
    );
    final tripIds = tripRows.map((row) => row['id'] as String).toList();
    final snapshot = await _captureLocalCache(db, user.id, tripIds);

    try {
      await db.transaction((transaction) async {
        await _clearLocalTripCache(transaction, tripIds);
        await transaction.delete(
          'pending_deletions',
          where: 'user_id = ?',
          whereArgs: [user.id],
        );
        await transaction.update(
          'profile',
          {'synced': 1},
          where: 'user_id = ?',
          whereArgs: [user.id],
        );
      });
      await _syncData(pullOnly: true);
    } catch (_) {
      await _restoreLocalCache(db, user.id, snapshot);
      rethrow;
    }
  }

  Future<Map<String, List<Map<String, Object?>>>> _captureLocalCache(
    Database db,
    String userId,
    List<String> tripIds,
  ) async {
    final snapshot = <String, List<Map<String, Object?>>>{};
    snapshot['trips'] = await db.query(
      'trips',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    snapshot['pending_deletions'] = await db.query(
      'pending_deletions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    snapshot['profile'] = await db.query(
      'profile',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (tripIds.isEmpty) return snapshot;

    final placeholders = List.filled(tripIds.length, '?').join(', ');
    for (final table in ['participants', 'activities', 'expenses']) {
      snapshot[table] = await db.query(
        table,
        where: 'trip_id IN ($placeholders)',
        whereArgs: tripIds,
      );
    }
    final activityIds =
        snapshot['activities']!.map((row) => row['id'] as String).toList();
    final expenseIds =
        snapshot['expenses']!.map((row) => row['id'] as String).toList();
    snapshot['activity_participants'] = activityIds.isEmpty
        ? []
        : await db.query(
            'activity_participants',
            where:
                'activity_id IN (${List.filled(activityIds.length, '?').join(', ')})',
            whereArgs: activityIds,
          );
    snapshot['expense_participants'] = expenseIds.isEmpty
        ? []
        : await db.query(
            'expense_participants',
            where:
                'expense_id IN (${List.filled(expenseIds.length, '?').join(', ')})',
            whereArgs: expenseIds,
          );
    return snapshot;
  }

  Future<void> _clearLocalTripCache(
    Transaction transaction,
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return;
    final placeholders = List.filled(tripIds.length, '?').join(', ');
    await transaction.delete(
      'activity_participants',
      where: 'activity_id IN '
          '(SELECT id FROM activities WHERE trip_id IN ($placeholders))',
      whereArgs: tripIds,
    );
    await transaction.delete(
      'expense_participants',
      where: 'expense_id IN '
          '(SELECT id FROM expenses WHERE trip_id IN ($placeholders))',
      whereArgs: tripIds,
    );
    for (final table in ['expenses', 'activities', 'participants']) {
      await transaction.delete(
        table,
        where: 'trip_id IN ($placeholders)',
        whereArgs: tripIds,
      );
    }
    await transaction.delete(
      'trips',
      where: 'id IN ($placeholders)',
      whereArgs: tripIds,
    );
  }

  Future<void> _restoreLocalCache(
    Database db,
    String userId,
    Map<String, List<Map<String, Object?>>> snapshot,
  ) async {
    await db.transaction((transaction) async {
      final currentTrips = await transaction.query(
        'trips',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await _clearLocalTripCache(
        transaction,
        currentTrips.map((row) => row['id'] as String).toList(),
      );
      await transaction.delete(
        'pending_deletions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await transaction.delete(
        'profile',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final table in [
        'trips',
        'participants',
        'activities',
        'expenses',
        'activity_participants',
        'expense_participants',
        'pending_deletions',
        'profile',
      ]) {
        for (final row in snapshot[table] ?? const <Map<String, Object?>>[]) {
          await transaction.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  String _formatSyncError(Object error) {
    if (error is TimeoutException) {
      return 'Не удалось подключиться к базе данных за 10 секунд.';
    }
    if (error is AuthException) {
      return 'Ошибка авторизации Supabase: ${error.message}';
    }
    if (error is PostgrestException) {
      return 'Ошибка базы данных: ${error.message}';
    }
    if (error is SocketException) {
      return 'Нет подключения к интернету. Данные сохранены на устройстве.';
    }
    return 'Не удалось синхронизировать данные: $error';
  }

  Future<void> _syncProfile(
    Database db,
    User user, {
    bool pullOnly = false,
  }) async {
    final rows = await db.query(
      'profile',
      where: 'user_id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final cachedName = rows.isEmpty ? null : rows.first['name'] as String?;
    var displayName = (cachedName?.trim().isNotEmpty ?? false)
        ? cachedName!
        : (metadata['full_name'] ??
                metadata['name'] ??
                user.email?.split('@').first ??
                'Путешественник')
            .toString();

    final remote = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(SupabaseConfig.requestTimeout);
    final localProfileNeedsUpload = !pullOnly &&
        rows.isNotEmpty &&
        (rows.first['synced'] as int? ?? 0) == 0;
    if (remote == null) {
      throw StateError(
        'Профиль Supabase не найден. Проверьте триггер on_auth_user_created.',
      );
    }
    if (localProfileNeedsUpload && remote['display_name'] != displayName) {
      await _client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('id', user.id)
          .timeout(SupabaseConfig.requestTimeout);
    } else if (!localProfileNeedsUpload) {
      displayName = remote['display_name'] as String? ?? displayName;
    }

    await _putLocal(db, 'profile', {
      'id': user.id,
      'user_id': user.id,
      'name': displayName,
      'email': user.email ?? '',
      'photo_path': rows.isEmpty ? null : rows.first['photo_path'],
      'synced': 1,
    });
  }

  Future<void> _claimLegacyCache(Database db, User user) async {
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;
    final legacyUsers = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(email) = ?',
      whereArgs: [email],
    );
    for (final row in legacyUsers) {
      final legacyId = row['id'] as String;
      if (legacyId == user.id) continue;
      final legacyTrips = await db.query(
        'trips',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [legacyId],
      );
      final tripIds = legacyTrips.map((row) => row['id'] as String).toList();
      await db.update(
        'trips',
        {'user_id': user.id, 'synced': 0},
        where: 'user_id = ?',
        whereArgs: [legacyId],
      );
      await _markTripDataUnsynced(db, tripIds);
      final currentProfile = await db.query(
        'profile',
        where: 'user_id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (currentProfile.isEmpty) {
        await db.update(
          'profile',
          {'id': user.id, 'user_id': user.id, 'email': email},
          where: 'user_id = ?',
          whereArgs: [legacyId],
        );
      }
    }
    final unownedTrips = await db.query(
      'trips',
      columns: ['id'],
      where: 'user_id IS NULL',
    );
    final unownedTripIds =
        unownedTrips.map((row) => row['id'] as String).toList();
    await db.update(
      'trips',
      {'user_id': user.id, 'synced': 0},
      where: 'user_id IS NULL',
    );
    await _markTripDataUnsynced(db, unownedTripIds);
  }

  Future<void> _markTripDataUnsynced(
    Database db,
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return;
    final placeholders = List.filled(tripIds.length, '?').join(', ');
    for (final table in ['participants', 'activities', 'expenses']) {
      await db.rawUpdate(
        'UPDATE $table SET synced = 0 '
        'WHERE trip_id IN ($placeholders)',
        tripIds,
      );
    }
  }

  Future<void> _pushTrips(Database db, User user) async {
    final rows = await db.query(
      'trips',
      where: 'synced = 0 AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [user.id],
    );
    for (final row in rows) {
      await _client.from('trips').upsert({
        'id': row['id'],
        'organizer_id': user.id,
        'title': row['name'],
        'start_date': _dateOnly(row['start_date'] as String?),
        'end_date': _dateOnly(row['end_date'] as String?),
        'app_data': {
          'people_count': row['people_count'],
          'created_at': row['created_at'],
          'start_date_iso': row['start_date'],
          'end_date_iso': row['end_date'],
        },
      }, onConflict: 'id').timeout(SupabaseConfig.requestTimeout);
      await db.update(
        'trips',
        {'synced': 1, 'user_id': user.id},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _cacheTrip(
    Database db,
    Map<String, dynamic> remote,
    String userId,
  ) async {
    final id = remote['id'] as String;
    final existing = await _localRow(db, 'trips', id);
    if (existing != null && (existing['synced'] as int? ?? 0) == 0) return;
    final membership = remote['organizer_id'] == userId
        ? null
        : await _client
            .from('trip_members')
            .select('id, status')
            .eq('trip_id', id)
            .eq('user_id', userId)
            .maybeSingle()
            .timeout(SupabaseConfig.requestTimeout);
    final data = _appData(remote['app_data']);
    await _putLocal(db, 'trips', {
      'id': id,
      'user_id': userId,
      'organizer_id': remote['organizer_id'] as String?,
      'name': remote['title'] as String? ?? '',
      'start_date': data['start_date_iso'] as String? ??
          (remote['start_date'] as String? ?? DateTime.now().toIso8601String()),
      'end_date': data['end_date_iso'] as String? ??
          (remote['end_date'] as String? ?? DateTime.now().toIso8601String()),
      'people_count': (data['people_count'] as num?)?.toInt() ?? 1,
      'created_at': data['created_at'] as String? ??
          remote['created_at'] as String? ??
          DateTime.now().toIso8601String(),
      'synced': 1,
      'remote_id': id,
      'membership_id': membership?['id'] as String?,
      'membership_status': membership?['status'] as String?,
    });
  }

  Future<void> _syncParticipants(
    Database db,
    String tripId, {
    bool pushLocal = true,
  }) async {
    final localRows = pushLocal
        ? await db.query(
            'participants',
            where: 'trip_id = ? AND synced = 0',
            whereArgs: [tripId],
          )
        : <Map<String, Object?>>[];
    for (final row in localRows) {
      await _client.from('trip_members').upsert({
        'id': row['id'],
        'trip_id': tripId,
        if (row['user_id'] != null) 'user_id': row['user_id'],
        'display_name': row['name'],
        'role': row['role'] == 'organizer' ? 'organizer' : 'member',
        'status': row['status'],
        'app_data': {
          'contact': row['contact'],
          'notes': row['notes'],
          'local_role': row['role'],
        },
      }, onConflict: 'id').timeout(SupabaseConfig.requestTimeout);
      await db.update(
        'participants',
        {'synced': 1, 'remote_id': row['id']},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    final remoteRows = await _client
        .from('trip_members')
        .select()
        .eq('trip_id', tripId)
        .timeout(SupabaseConfig.requestTimeout);
    final currentUserId = _client.auth.currentUser?.id;
    for (final remote in remoteRows) {
      if (remote['user_id'] == currentUserId && remote['role'] == 'organizer') {
        continue;
      }
      final id = remote['id'] as String;
      final existing = await _localRow(db, 'participants', id);
      if (existing != null && (existing['synced'] as int? ?? 0) == 0) continue;
      final data = _appData(remote['app_data']);
      await _putLocal(db, 'participants', {
        'id': id,
        'trip_id': tripId,
        'user_id': remote['user_id'] as String?,
        'name': remote['display_name'] as String? ?? '',
        'contact': data['contact'] as String? ?? '',
        'notes': data['notes'] as String? ?? '',
        'status': remote['status'] as String? ?? 'confirmed',
        'role': data['local_role'] as String? ??
            (remote['role'] == 'organizer' ? 'organizer' : 'participant'),
        'synced': 1,
        'remote_id': id,
      });
    }
  }

  Future<void> _syncActivities(
    Database db,
    String tripId, {
    bool pushLocal = true,
  }) async {
    final localRows = pushLocal
        ? await db.query(
            'activities',
            where: 'trip_id = ? AND synced = 0',
            whereArgs: [tripId],
          )
        : <Map<String, Object?>>[];
    for (final row in localRows) {
      final ownerId =
          row['created_by'] as String? ?? _client.auth.currentUser?.id;
      final scope = await _scopeForUpload(db, tripId, row, ownerId);
      final participantRows = await db.query(
        'activity_participants',
        where: 'activity_id = ?',
        whereArgs: [row['id']],
      );
      final appData = {
        'category': row['category'],
        'cost': row['cost'],
        'is_main': row['is_main'],
        'is_completed': row['is_completed'],
        'ticket': {
          'transport_type': row['transport_type'],
          'ticket_number': row['ticket_number'],
          'transport_number': row['transport_number'],
          'departure_date': row['departure_date'],
          'arrival_date': row['arrival_date'],
        },
        'participant_ids':
            participantRows.map((e) => e['participant_id']).toList(),
        'date_time_iso': row['date_time'],
      };
      await _client.from('itinerary_items').upsert({
        'id': row['id'],
        'trip_id': tripId,
        'title': row['name'],
        'starts_at': row['date_time'],
        'location': row['location'],
        'notes': row['description'],
        'created_by': ownerId,
        'scope': scope,
        'app_data': appData,
      }, onConflict: 'id').timeout(SupabaseConfig.requestTimeout);
      await db.update(
        'activities',
        {
          'synced': 1,
          'remote_id': row['id'],
          'created_by': ownerId,
          'scope': scope,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    final remoteRows = await _client
        .from('itinerary_items')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .timeout(SupabaseConfig.requestTimeout);
    for (final remote in remoteRows) {
      final id = remote['id'] as String;
      final existing = await _localRow(db, 'activities', id);
      if (existing != null && (existing['synced'] as int? ?? 0) == 0) continue;
      final data = _appData(remote['app_data']);
      final ticket = _appData(data['ticket']);
      await _putLocal(db, 'activities', {
        'id': id,
        'trip_id': tripId,
        'name': remote['title'] as String? ?? '',
        'category': data['category'] as String? ?? 'other',
        'date_time': data['date_time_iso'] as String? ??
            remote['starts_at'] as String? ??
            DateTime.now().toIso8601String(),
        'location': remote['location'] as String? ?? '',
        'description': remote['notes'] as String? ?? '',
        'cost': data['cost'] as num? ?? 0,
        'is_main': data['is_main'] as int? ?? 0,
        'is_completed': data['is_completed'] as int? ?? 0,
        'transport_type': ticket['transport_type'] as String?,
        'ticket_number': ticket['ticket_number'] as String?,
        'transport_number': ticket['transport_number'] as String?,
        'departure_date': ticket['departure_date'] as String?,
        'arrival_date': ticket['arrival_date'] as String?,
        'synced': 1,
        'remote_id': id,
        'created_by': remote['created_by'] as String?,
        'scope': remote['scope'] as String? ?? 'shared',
      });
      await _replaceLinks(
        db,
        'activity_participants',
        'activity_id',
        id,
        (data['participant_ids'] as List<dynamic>? ?? []).cast<String>(),
        'participant_id',
      );
    }
  }

  Future<void> _syncExpenses(
    Database db,
    String tripId,
    String userId, {
    bool pushLocal = true,
  }) async {
    final localRows = pushLocal
        ? await db.query(
            'expenses',
            where: 'trip_id = ? AND synced = 0',
            whereArgs: [tripId],
          )
        : <Map<String, Object?>>[];
    for (final row in localRows) {
      final ownerId = row['created_by'] as String? ?? userId;
      final scope = await _scopeForUpload(db, tripId, row, ownerId);
      var paidBy = row['paid_by_participant_id'] as String?;
      if (paidBy == null) {
        final participants = await db.query(
          'participants',
          columns: ['id'],
          where: 'trip_id = ?',
          whereArgs: [tripId],
          orderBy: "CASE WHEN role = 'organizer' THEN 0 ELSE 1 END",
          limit: 1,
        );
        if (participants.isNotEmpty) {
          paidBy = participants.first['id'] as String;
        } else {
          final ownerMembership = await _client
              .from('trip_members')
              .select('id')
              .eq('trip_id', tripId)
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle()
              .timeout(SupabaseConfig.requestTimeout);
          paidBy = ownerMembership?['id'] as String?;
        }
      }
      if (paidBy == null) {
        throw StateError(
          'Нельзя синхронизировать расход ${row['id']}: в поездке нет участника-плательщика.',
        );
      }

      final shareRows = await db.query(
        'expense_participants',
        where: 'expense_id = ?',
        whereArgs: [row['id']],
      );
      final appData = {
        'activity_id': row['activity_id'],
        'category': row['category'],
        'name': row['name'],
        'comment': row['comment'],
        'confirmation': row['confirmation'],
        'ticket': {
          'transport_type': row['transport_type'],
          'ticket_number': row['ticket_number'],
          'transport_number': row['transport_number'],
          'departure_date': row['departure_date'],
          'arrival_date': row['arrival_date'],
        },
        'participant_ids': shareRows.map((e) => e['participant_id']).toList(),
      };
      await _client.from('expenses').upsert({
        'id': row['id'],
        'trip_id': tripId,
        'paid_by': paidBy,
        'amount': row['amount'],
        'scope': scope,
        'created_by': ownerId,
        'description': row['comment'],
        'spent_at': row['date'],
        'app_data': appData,
      }, onConflict: 'id').timeout(SupabaseConfig.requestTimeout);
      await db.update(
        'expenses',
        {
          'synced': 1,
          'remote_id': row['id'],
          'created_by': ownerId,
          'scope': scope,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    final remoteRows = await _client
        .from('expenses')
        .select()
        .eq('trip_id', tripId)
        .isFilter('deleted_at', null)
        .timeout(SupabaseConfig.requestTimeout);
    for (final remote in remoteRows) {
      final id = remote['id'] as String;
      final existing = await _localRow(db, 'expenses', id);
      if (existing != null && (existing['synced'] as int? ?? 0) == 0) continue;
      final data = _appData(remote['app_data']);
      final ticket = _appData(data['ticket']);
      await _putLocal(db, 'expenses', {
        'id': id,
        'trip_id': tripId,
        'activity_id': data['activity_id'] as String?,
        'category': data['category'] as String? ?? 'other',
        'name':
            data['name'] as String? ?? remote['description'] as String? ?? '',
        'amount': remote['amount'] as num? ?? 0,
        'date':
            remote['spent_at'] as String? ?? DateTime.now().toIso8601String(),
        'comment': data['comment'] as String? ?? '',
        'paid_by_participant_id': remote['paid_by'] as String?,
        'confirmation': data['confirmation'] as String? ?? 'confirmed',
        'transport_type': ticket['transport_type'] as String?,
        'ticket_number': ticket['ticket_number'] as String?,
        'transport_number': ticket['transport_number'] as String?,
        'departure_date': ticket['departure_date'] as String?,
        'arrival_date': ticket['arrival_date'] as String?,
        'synced': 1,
        'remote_id': id,
        'created_by': remote['created_by'] as String?,
        'scope': remote['scope']?.toString() ?? 'shared',
      });
      await _replaceLinks(
        db,
        'expense_participants',
        'expense_id',
        id,
        (data['participant_ids'] as List<dynamic>? ?? []).cast<String>(),
        'participant_id',
      );
    }
  }

  Future<void> _syncPendingDeletions(Database db) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final pending = await db.query(
      'pending_deletions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final order = {
      'activities': 0,
      'expenses': 1,
      'participants': 2,
      'trips': 3
    };
    pending.sort((a, b) =>
        (order[a['table_name']] ?? 4).compareTo(order[b['table_name']] ?? 4));
    for (final row in pending) {
      final table = row['table_name'] as String;
      final id = row['record_id'] as String;
      final remoteTable = switch (table) {
        'participants' => 'trip_members',
        'activities' => 'itinerary_items',
        _ => table,
      };
      await _client
          .from(remoteTable)
          .delete()
          .eq('id', id)
          .timeout(SupabaseConfig.requestTimeout);
      await db.delete(
        'pending_deletions',
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [table, id],
      );
    }
  }

  Future<void> _replaceLinks(
    Database db,
    String table,
    String ownerColumn,
    String ownerId,
    List<String> relatedIds,
    String relatedColumn,
  ) async {
    await db.delete(table, where: '$ownerColumn = ?', whereArgs: [ownerId]);
    for (final relatedId in relatedIds) {
      await db.insert(table, {
        ownerColumn: ownerId,
        relatedColumn: relatedId,
      });
    }
  }

  Future<String> _scopeForUpload(
    Database db,
    String tripId,
    Map<String, Object?> row,
    String? ownerId,
  ) async {
    if (row['created_by'] != null) {
      return row['scope'] as String? ?? 'shared';
    }
    final trip = await _localRow(db, 'trips', tripId);
    final organizerId =
        trip?['organizer_id'] as String? ?? trip?['user_id'] as String?;
    return ownerId != null && ownerId == organizerId ? 'shared' : 'private';
  }

  Future<Map<String, Object?>?> _localRow(
    Database db,
    String table,
    String id,
  ) async {
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _putLocal(
    Database db,
    String table,
    Map<String, Object?> values,
  ) async {
    final existing = await _localRow(db, table, values['id'] as String);
    if (existing == null) {
      await db.insert(table, values);
    } else {
      await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [values['id']],
      );
    }
  }

  Map<String, dynamic> _appData(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  String? _dateOnly(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.split('T').first;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      requestSync();
    }
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }
}
