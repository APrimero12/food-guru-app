import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth specific errors (e.g., network issues, invalid credentials)
      print("Firebase Authentication Error: ${e.message}");
      return null;
    } on Exception catch (e) {
      // Handle other potential errors (e.g., from google_sign_in plugin)
      print("General Error during Google Sign-In: $e");
      return null;
    }
  }

  // Register with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}