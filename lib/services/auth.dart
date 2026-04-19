import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../models/user_model.dart'; // Import your UserModel

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // --- Method to proactively refresh current user state from Firebase backend ---
  Future<void> refreshCurrentUser() async {
    if (_auth.currentUser != null) {
      try {
        await _auth.currentUser!.reload();
        // After reload, the currentUser object itself might be updated.
        // If the user was deleted, reload() will likely throw an exception.
      } on FirebaseAuthException catch (e) {
        print("Error reloading user from Firebase: ${e.code} - ${e.message}");
        // If reload fails (e.g., user-not-found due to deletion),
        // it often means the user is no longer valid server-side.
        // Force a local sign out to clear cached credentials immediately.
        await signOut(); // This will clear local state and trigger authStateChanges to null
      } catch (e) {
        print("General error during user reload: $e");
        await signOut();
      }
    }
  }

  // --- Helper method to save user data to Firestore ---
  Future<void> _saveUserToFirestore(User user) async {
    // We'll use the user's UID as the document ID in the 'users' collection
    DocumentReference userRef = _firestore.collection('users').doc(user.uid);

    // Get the current user data from Firestore if it exists
    DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      // If the document doesn't exist, this is a new user or their first login
      // Create a UserModel from the Firebase User and save it
      final userModel = UserModel.fromFirebaseUser(user);
      await userRef.set(userModel.toMap());
      print('New user added to Firestore: ${user.uid}');
    } else {
      // If the document exists, you might want to update some fields,
      // or simply ensure the data is consistent.
      // For example, update displayName or photoURL if they changed.
      // We also update lastActive field here.
      final existingData = doc.data() as Map<String, dynamic>;
      final updatedData = {
        'email': user.email ?? existingData['email'], // Keep existing if null from auth
        'name': user.displayName ?? existingData['name'], // Update name from Firebase if available
        'avatar': user.photoURL ?? existingData['avatar'], // Update avatar from Firebase if available
        'lastActive': FieldValue.serverTimestamp(), // Update last active timestamp
      };
      await userRef.update(updatedData);
      print('Existing user data updated in Firestore: ${user.uid}');
    }
  }

  // Sign in with email and password
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

  // Sign in with google

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google authentication flow
      // This will open the Google Sign-In prompt on native platforms.
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If the user cancels the sign-in, googleUser will be null.
      if (googleUser == null) {
        return null;
      }

      // 2. Obtain the authentication details from the GoogleSignInAccount
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new Firebase credential using the Google ID token and access token
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the Google credential
      // This completes the authentication process with Firebase.
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Authentication Error: ${e.message}");
      rethrow; // Re-throwing ensures UI catches the error for display
    } on Exception catch (e) {
      print("General Error during Google Sign-In: $e");
      rethrow; // Re-throwing ensures UI catches the error for display
    }
  }

  //TODO: ADD REQUIRED -> NAME and USERNAME
  // Register with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!); // Save/Update to Firestore
    }
    return userCredential;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut(); // Also sign out from Google if signed in via Google
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}