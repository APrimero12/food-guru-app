import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email/password sign-in ─────────────────────────────────────────────────

  Future<void> _signIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
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
      // AuthWrapper handles navigation automatically
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  //
  // FIXED: We now simply call authService.signInWithGoogle() and let the
  // service handle everything. We no longer call GoogleSignIn().signIn()
  // here — that was causing a double sign-in prompt and a broken pre-check.

  Future<void> _signInWithGoogle() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await authService.signInWithGoogle();

      if (userCredential == null) {
        // User cancelled — just clear loading state
        setState(() => _errorMessage = null);
      }
      // On success, AuthWrapper handles navigation automatically

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e.code));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
        'An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Error messages ─────────────────────────────────────────────────────────

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
        return 'This sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'google-sign-in-failed':
        return 'Google Sign-In failed. Please try again.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                  Text('Email',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  SizedBox(height: 16),
                  Text('Password',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
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
                        style: TextStyle(
                            fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/google_logo.png',
                      height: 24.0,
                    ),
                    label: const Text(
                      'Sign In with Google',
                      style:
                      TextStyle(fontSize: 18, color: Colors.black),
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
                      onTap: _isLoading ? null : () {
                        // TODO: implement forgot password
                      },
                      child: Text(
                        'Forgot password?',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 14),
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