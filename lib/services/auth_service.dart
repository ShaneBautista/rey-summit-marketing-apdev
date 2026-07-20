import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Wraps all Firebase Authentication + Firestore calls for the app.
/// Keeping this separate from the UI means the screens only call
/// simple methods like `login(...)` and never touch Firebase directly.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Logs a user (customer or employee) in with email + password.
  /// Throws a [FirebaseAuthException] on failure so the UI can show
  /// e.g. e.message in a SnackBar.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Creates a Firebase Auth account AND a matching document in the
  /// `users` Firestore collection using the UID as the document ID.
  /// Pass [role] to decide which extra fields get saved.
  Future<UserCredential> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required UserRole role,
    String? address, // customer
    String? employeeId, // employee
    String? branchId, // employee — which branch they're assigned to
  }) async {
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = AppUserModel(
      uid: credential.user!.uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      role: role,
      address: address?.trim(),
      employeeId: employeeId?.trim(),
      branchId: branchId?.trim(),
    );

    try {
      await _firestore
          .collection("users")
          .doc(credential.user!.uid)
          .set({
        ...user.toMap(),
        // Server-generated so it reflects Firestore's clock, not the
        // device's — accurate even if the phone's date/time is wrong.
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // The Auth account was created, but the Firestore profile write failed.
      // Log clearly so this doesn't look like a silent no-op in the console.
      // ignore: avoid_print
      print("AuthService.register: Firestore write failed for "
          "uid=${credential.user!.uid}: $e");
      rethrow;
    }

    return credential;
  }

  /// Fetches the current user's profile document (to check their role
  /// after login, for example — this is how the app decides whether to
  /// route someone into the customer app or the admin/employee app).
  Future<AppUserModel?> fetchCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists) return null;

    return AppUserModel.fromMap(uid, doc.data()!);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sends Firebase's built-in verification link to the currently signed-in
  /// user's email address. Call this right after register() succeeds.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  /// Reloads the current user from Firebase and reports whether they've
  /// clicked the verification link yet. `emailVerified` on the cached
  /// user object goes stale, so reload() is required before checking it.
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();
}
