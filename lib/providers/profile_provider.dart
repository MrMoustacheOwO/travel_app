import 'package:flutter/foundation.dart';

import '../data/repositories/profile_repository.dart';
import '../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  ProfileProvider(this._repository);

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  Future<void> load() async {
    _profile = await _repository.getProfile();
    notifyListeners();
  }

  Future<void> save({String? name, String? email, String? photoPath}) async {
    final current = _profile ?? await _repository.getProfile();
    final updated = UserProfile(
      id: current.id,
      name: name ?? current.name,
      email: email ?? current.email,
      photoPath: photoPath ?? current.photoPath,
    );
    await _repository.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }
}
