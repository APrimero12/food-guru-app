import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1035741614587-jrmdtnfmhemuftds0qnko3qtjsqlej1s.apps.googleusercontent.com',
  );

  // ── Auth state ─────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> refreshCurrentUser() async {
    if (_auth.currentUser != null) {
      try {
        await _auth.currentUser!.reload();
      } on FirebaseAuthException catch (e) {
        print("Error reloading user: ${e.code} - ${e.message}");
        await signOut();
      } catch (e) {
        print("General error during user reload: $e");
        await signOut();
      }
    }
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  Future<void> _saveUserToFirestore(
      User user, {
        String? initialName,
        String? initialUsername,
      }) async {
    final DocumentReference userRef =
    _firestore.collection('users').doc(user.uid);
    final DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email,
        name: initialName ?? user.displayName,
        username: initialUsername,
        avatar: user.photoURL,
        bio: null,
        createdAt: Timestamp.now(),
        lastActive: Timestamp.now(),
      );
      await userRef.set(userModel.toMap());

      // Wait until document is confirmed readable before AuthWrapper
      // tries to load it — prevents infinite loading on first sign-up
      await _waitForDocument(userRef);
    } else {
      final existingData = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> updatedData = {
        'email': user.email ?? existingData['email'],
        'lastActive': FieldValue.serverTimestamp(),
      };
      if ((existingData['name'] == null ||
          (existingData['name'] as String).isEmpty) &&
          user.displayName != null) {
        updatedData['name'] = user.displayName;
      }
      await userRef.update(updatedData);
    }
  }

  /// Retries reading the document until it exists (max 5 attempts, ~4.5s total).
  /// Handles Firestore propagation delay on first write.
  Future<void> _waitForDocument(DocumentReference ref,
      {int maxAttempts = 5}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
      final snap = await ref.get();
      if (snap.exists) return;
    }
  }

  // ── Sign in with email/password ────────────────────────────────────────────

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!);
    }
    return userCredential;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: 'Google Sign-In failed to return an ID token.',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _saveUserToFirestore(
          userCredential.user!,
          initialName: userCredential.user!.displayName,
          initialUsername: 'guest',
        );
      }

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // ── Sign up with email/password ────────────────────────────────────────────

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (userCredential.user != null) {
      final user = userCredential.user!;
      await user.updateDisplayName(name);
      await _saveUserToFirestore(
        user,
        initialName: name,
        initialUsername: username,
      );
    }
    return userCredential;
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}