import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../services/auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // Removed: final _authService = AuthService(); // Will be accessed via Provider
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /**
   * This function handles the signup for a new user
   */
  Future<void> _signUp() async {
    final authService = Provider.of<AuthService>(context, listen: false); // Access AuthService via Provider

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (fullName.isEmpty || username.isEmpty || email.isEmpty
        || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signUp(email: email, password: password);
      // Removed: if (mounted) Navigator.pushReplacementNamed(context, '/home');
      // AuthWrapper in main.dart will handle navigation based on auth state change.
      // After successful email/password signup, you might want to automatically
      // navigate back to the login page, or directly to home if Firebase logs them in immediately.
      // For now, I'll pop to the previous screen (likely Login).
      if (mounted) Navigator.pop(context); // Go back to login after successful signup
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // New method for Google Sign-Up/Sign-In
  Future<void> _signUpWithGoogle() async {
    final authService = Provider.of<AuthService>(context, listen: false); // Access AuthService via Provider
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await authService.signInWithGoogle();
      if (userCredential == null) {
        // User cancelled the sign-in flow
        setState(() => _errorMessage = 'Google Sign-Up/In cancelled.');
      }
      // No explicit navigation here either; AuthWrapper handles it.
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } catch (e) {
      // General error, e.g., from google_sign_in plugin itself
      setState(() => _errorMessage = 'An unexpected error occurred during Google Sign-Up/In.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials. Please sign in with the associated method.';
      case 'cancelled-by-user': // Specific to Google Sign-In often
        return 'Sign-in cancelled by user.';
      default:
      // You can add more specific error codes here if needed,
      // especially for Google Sign-In specific FirebaseAuthException codes.
        return 'Sign up failed. Please try again. Code: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
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
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.deepOrangeAccent,
                        child: Icon(
                          Icons.soup_kitchen,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Join FoodGuru and start sharing recipes',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 24),
                    // User sign up full name inputs
                    Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                      keyboardType: TextInputType.name,
                      enabled: !_isLoading,
                    ),
                    // user username inputs
                    Text('Username', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                      keyboardType: TextInputType.name,
                      enabled: !_isLoading,
                    ),
                    // user email inputs
                    Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                    ),
                    SizedBox(height: 16),
                    // user password inputs
                    Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      enabled: !_isLoading,
                    ),
                    SizedBox(height: 16),
                    // user confirm password inputs
                    Text('Confirm Password',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(() =>
                          _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible),
                        ),
                      ),
                      obscureText: !_isConfirmPasswordVisible,
                      enabled: !_isLoading,
                      onSubmitted: (_) => _signUp(),
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
                      onPressed: _isLoading ? null : _signUp,
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
                          'Create Account',
                          style:
                          TextStyle(fontSize: 18, color: Colors.white),

                        ),
                      ),
                    ),

                    SizedBox(height: 10), // Added spacing for new button

                    // New Google Sign-Up Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signUpWithGoogle,
                      icon: Image.asset(
                        'assets/google_logo.png', // Ensure this asset is available
                        height: 24.0,
                      ),
                      label: const Text(
                        'Sign Up with Google',
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

                    SizedBox(height: 28),
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'Already have an account? Sign in',
                          style: TextStyle(color: Colors.orange, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
