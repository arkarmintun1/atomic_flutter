/// User model
class User {
  final int id;
  final String email;
  final String name;
  final String? profilePicture;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profilePicture,
    this.isVerified = false,
  });

  /// Create a copy with updated fields
  User copyWith({
    int? id,
    String? email,
    String? name,
    String? profilePicture,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profilePicture: profilePicture ?? this.profilePicture,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          profilePicture == other.profilePicture &&
          isVerified == other.isVerified;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      name.hashCode ^
      profilePicture.hashCode ^
      isVerified.hashCode;

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
