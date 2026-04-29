import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../services/auth.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Removed: final _authService = AuthService(); // Will be accessed via Provider
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final authService = Provider.of<AuthService>(context, listen: false); // Access AuthService via Provider
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signIn(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // VVVV MODIFIED: _signInWithGoogle method for guaranteed pre-check failure VVVV
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // 1. Trigger the Google authentication flow to get the user's email
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the Google sign-in prompt itself.
        print('SignInPage Debug: User cancelled Google sign-in.');
        if (mounted) {
          setState(() => _errorMessage = 'Google Sign-In cancelled.');
        }
        return; // Exit here as user cancelled
      }

      // VVVV Perform explicit pre-check for existing non-Google accounts VVVV
      print('SignInPage Debug: Performing pre-check for email: ${googleUser.email}');
      final List<String> existingSignInMethods = await authService.fetchSignInMethodsForEmail(googleUser.email);

      // Filter out 'google.com' if it's already there (meaning user previously signed up with Google)
      // or if their account was already linked somehow (though we're avoiding linking now).
      final otherProviders = existingSignInMethods.where((method) => method != 'google.com').toList();

      if (otherProviders.isNotEmpty) {
        // VVVV GUARANTEED FAILURE PATH VVVV
        print('SignInPage Debug: Conflict detected by pre-check. Other providers: $otherProviders');
        if (mounted) {
          setState(() => _errorMessage = 'An account with ${googleUser.email} already exists using the  '
              '${otherProviders.join(', ')} method. Please sign in with your existing method '
              'or use a different email for Google Sign-In.');
        }
        // No further Firebase authentication attempt is made!
        return; // <--- CRUCIAL: Exit here if conflict found
        // ^^^^ END GUARANTEED FAILURE PATH ^^^^
      }
      // ^^^^ END NEW PRE-CHECK ^^^^


      // 2. If pre-check passes, proceed with Firebase authentication
      // The authService.signInWithGoogle method will now handle the rest
      // (getting credential, calling FirebaseAuth.instance.signInWithCredential, saving to Firestore).
      print('SignInPage Debug: Pre-check passed. Calling AuthService.signInWithGoogle...');
      await authService.signInWithGoogle();

      // If we reach here, Google Sign-In with Firebase was successful.
      if (mounted) {
        _showSuccess('Signed in with Google!');
      }

    } on FirebaseAuthException catch (e) {
      print('SignInPage DEBUG: FirebaseAuthException caught in UI: code=${e.code}, message=${e.message}');
      // This catch block will now mostly handle general FirebaseAuth errors,
      // as the 'account-exists-with-different-credential' should be caught by our pre-check.
      // However, it's good to keep it for robustness.
      if (mounted) {
        // Catch our custom error code specifically if it was rethrown (though our pre-check prevents this now)
        if (e.code == 'email-already-in-use-by-other-provider') {
          setState(() => _errorMessage = e.message); // Use the message from AuthService
        } else {
          setState(() => _errorMessage = _friendlyError(e.code));
        }
      }
    } catch (e) {
      print('SignInPage DEBUG: General Exception caught in UI: $e');
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred during Google Sign-In: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'email-already-in-use-by-other-provider': // NEW: Handle our custom error code
        return 'An account with this email already exists with a different provider.';
      default:
        return 'Sign in failed. Please try again. Code: $code';
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepOrangeAccent,
                      child: Icon(
                        Icons.restaurant_menu,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Sign in to FoodGuru to continue sharing recipes',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: '',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  SizedBox(height: 16),
                  Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: '',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.all(15),
                      disabledBackgroundColor: Colors.grey[700],
                    ),
                    child: Center(
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Sign In',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // New Google Sign-In Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/google_logo.png', // You'll need to add this asset
                      height: 24.0,
                    ),
                    label: const Text(
                      'Sign In with Google',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      disabledBackgroundColor: Colors.grey[200],
                    ),
                  ),

                  SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                        // TODO: implement forgot password flow
                      },
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                  SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => Navigator.pushNamed(context, '/signup'),
                      child: Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
