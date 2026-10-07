/// A locally registered account.
///
/// The password is never stored in this model. Only the salted SHA-256 digest
/// produced by `AuthRepository` is persisted, so nothing in the app has to
/// handle a plaintext secret.
class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  String get initials {
    final List<String> parts = username.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Deterministic accent index for the generated avatar.
  int get avatarSeed => email.hashCode;

  /// Strips the password digest before handing the user to the UI layer.
  User withoutSecret() => User(
        id: id,
        username: username,
        email: email,
        passwordHash: '',
        createdAt: createdAt,
      );

  User copyWith({String? username, String? email, String? passwordHash}) =>
      User(
        id: id,
        username: username ?? this.username,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? 'Listener',
        email: json['email'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  bool operator ==(Object other) => other is User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
