/// Represents a user in the app with role information.
class AppUser {
  final String uid;
  final String email;
  final String role; // "student" or "admin"
  final String displayName;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName = '',
  });

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      displayName: data['displayName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role,
      'displayName': displayName,
    };
  }
}
