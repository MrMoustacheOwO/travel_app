class UserProfile {
  final String id;
  String name;
  String email;
  String? photoPath;

  UserProfile({
    required this.id,
    this.name = '',
    this.email = '',
    this.photoPath,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photo_path': photoPath,
    };
  }

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoPath: map['photo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}
