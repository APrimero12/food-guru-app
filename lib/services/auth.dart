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
  // This method now intelligently creates or updates.
  // 'initialName' and 'initialUsername' are only used on FIRST creation.
  Future<void> _saveUserToFirestore(
      User user, {
        String? initialName,
        String? initialUsername,
      }) async {
    DocumentReference userRef = _firestore.collection('users').doc(user.uid);
    DocumentSnapshot doc = await userRef.get();

    if (!doc.exists) {
      // ONLY ON FIRST LOGIN/SIGNUP
      // If the document doesn't exist, this is a new user. Create the initial profile.
      final userModel = UserModel(
        uid: user.uid,
        email: user.email,
        // Use provided name/displayName for initial setup
        name: initialName ?? user.displayName,
        // Use provided username for initial setup
        username: initialUsername,
        avatar: user.photoURL,
        bio: null, // Bio is typically empty on first creation
        createdAt: Timestamp.now(),
        lastActive: Timestamp.now(),
      );
      await userRef.set(userModel.toMap());
      print('New user added to Firestore: ${user.uid}');
      // END ONLY ON FIRST LOGIN/SIGNUP
    } else {
      // ONLY ON SUBSEQUENT LOGINS
      // If the document exists, only update system-managed fields
      // and a 'lastActive' timestamp. Do NOT overwrite user-customized
      // 'name' or 'username' here.
      final existingData = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> updatedData = {
        'email': user.email ?? existingData['email'], // Update email if it changed in Auth
        'lastActive': FieldValue.serverTimestamp(), // Always update last active timestamp
      };

      // Only update 'name' if the existing 'name' in Firestore is null/empty AND
      // a displayName is available from Firebase Auth. This handles cases where
      // name wasn't set initially or was from Google Auth.
      // After first login, users typically set their name in-app.
      if ((existingData['name'] == null || (existingData['name'] as String).isEmpty) && user.displayName != null) {
        updatedData['name'] = user.displayName;
      }

      await userRef.update(updatedData);
      print('Existing user data updated in Firestore: ${user.uid}');
      // END ONLY ON SUBSEQUENT LOGINS
    }
  }

  Future<UserCredential?> linkWithCredential(AuthCredential credential) async {
    if (_auth.currentUser == null) {
      // This should ideally not be reached if called correctly in the linking flow
      throw FirebaseAuthException(code: 'no-current-user', message: 'No user signed in to link credential to.');
    }
    final userCredential = await _auth.currentUser!.linkWithCredential(credential);
    // After linking, ensure Firestore profile is up-to-date
    if (userCredential.user != null) {
      await _saveUserToFirestore(userCredential.user!); // Update Firestore after linking
    }
    return userCredential;
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
      // No initialName/Username needed here, as it's a login, not a creation with custom name/username
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
      linkWithCredential(credential);
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Pass user.displayName and user.photoURL as initial values for new Google sign-ins
        await _saveUserToFirestore(
          userCredential.user!,
          initialName: userCredential.user!.displayName,
          // avatar: userCredential.user!.photoURL, // initial avatar is set during creation
          initialUsername: "guest", // Google does not provide a 'username' typically
        );
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

  // Register with email and password
  // MODIFIED: Added required name and username parameters
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,     // New required parameter
    required String username, // New required parameter
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (userCredential.user != null) {
      final user = userCredential.user!;
      // Update the display name in Firebase Authentication profile
      // This displayName will then be picked up by user.displayName later
      await user.updateDisplayName(name);

      // Save/Update to Firestore, passing the initial name and username
      await _saveUserToFirestore(
          user,
          initialName: name,
          initialUsername: username
      );
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