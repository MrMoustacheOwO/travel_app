import 'package:sqflite/sqflite.dart';

import '../../models/user_profile.dart';
import '../db/database_helper.dart';
import 'auth_repository.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile();
  Future<void> saveProfile(UserProfile profile);
}

class LocalProfileRepository implements ProfileRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AuthRepository _authRepository;
  final void Function()? _onChanged;

  LocalProfileRepository({
    AuthRepository? authRepository,
    void Function()? onChanged,
  })  : _authRepository = authRepository ?? LocalAuthRepository(),
        _onChanged = onChanged;

  @override
  Future<UserProfile> getProfile() async {
    final currentUser = await _authRepository.getCurrentUser();
    if (currentUser == null) {
      return UserProfile(id: 'guest', name: 'Гость', email: '');
    }

    final db = await _dbHelper.database;
    final rows = await db.query(
      'profile',
      where: 'user_id = ?',
      whereArgs: [currentUser.id],
    );

    if (rows.isEmpty) {
      final profile = UserProfile(
        id: currentUser.id,
        name: currentUser.name,
        email: currentUser.email,
      );
      await db.insert(
        'profile',
        {
          'id': currentUser.id,
          'user_id': currentUser.id,
          'name': currentUser.name,
          'email': currentUser.email,
          'photo_path': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return profile;
    }

    return UserProfile.fromMap(rows.first);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final currentUser = await _authRepository.getCurrentUser();
    if (currentUser == null) return;

    final normalizedEmail = profile.email.trim().toLowerCase();
    if (normalizedEmail != currentUser.email.toLowerCase()) {
      await _authRepository.updateEmail(normalizedEmail);
    }

    final db = await _dbHelper.database;
    await db.insert(
      'profile',
      {
        'id': profile.id,
        'user_id': currentUser.id,
        'name': profile.name,
        'email': profile.email,
        'photo_path': profile.photoPath,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.update(
      'users',
      {
        'name': profile.name,
        'email': profile.email,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [currentUser.id],
    );
    _onChanged?.call();
  }
}
