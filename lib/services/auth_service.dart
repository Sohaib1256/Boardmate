import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Handles all authentication and role-based access logic.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get the current user's Firebase ID token for backend API calls.
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Sign up a new user with email/password and assign a role.
  /// [role] should be "student" or "admin".
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    String role = 'student',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    // Store user profile + role in Firestore
    final appUser = AppUser(
      uid: user.uid,
      email: email,
      role: role,
      displayName: displayName,
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(appUser.toFirestore());

    return appUser;
  }

  /// Sign in an existing user.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await getAppUser(credential.user!.uid);
  }

  /// Get the AppUser profile from Firestore.
  Future<AppUser> getAppUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found in Firestore');
    }
    return AppUser.fromFirestore(doc.data()!, uid);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

