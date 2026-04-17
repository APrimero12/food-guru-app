import 'package:appdevproject/views/home_navigation.dart';
import 'package:appdevproject/views/login/login_screen.dart';
import 'package:appdevproject/views/login/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import the generated file
import 'package:provider/provider.dart'; // Import the provider package
import 'services/auth.dart'; // Import your AuthService

// Ensure you have these imports available:
// firebase_auth: ^latest_version
// provider: ^latest_version

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    // 1. Provide the AuthService instance at the root of your widget tree
    Provider<AuthService>(
      create: (_) => AuthService(), // Create an instance of your AuthService
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FoodGuru App', // Give your app a title
      theme: ThemeData(
        primarySwatch: Colors.blue, // Optional: Define a primary color
      ),
      // 2. Set the initial route to AuthWrapper to handle authentication state
      home: AuthWrapper(),
      // 3. Keep your routes for navigation to specific pages
      routes: {
        '/signup': (context) => SignUpScreen(),
        // Note: '/home' will primarily be handled by AuthWrapper, but can be useful for explicit navigation if needed.
        // If your LoginPage and SignUpScreen are always shown via AuthWrapper, you might not need '/' as a route here.
        // For now, I'll assume SignInPage is your LoginPage, which AuthWrapper will use.
      },
    );
  }
}

// MODIFIED: AuthWrapper is now a StatefulWidget
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Flag to ensure our initial server-side validation runs only once
  bool _initialCheckPerformed = false;

  @override
  void initState() {
    super.initState();
    // Schedule the initial auth check to run after the first frame is built
    // This ensures `context` is available for `Provider.of`
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialAuthCheck();
    });
  }

  Future<void> _performInitialAuthCheck() async {
    // Prevent multiple executions if hot-reloaded or widget rebuilds quickly
    if (_initialCheckPerformed) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // If Firebase Auth has a cached user, proactively ask Firebase server
    // to confirm if the user is still valid (e.g., not deleted).
    if (authService.currentUser != null) {
      print('AuthWrapper: Cached user found. Performing server-side validation...');
      await authService.refreshCurrentUser(); // This will force a sign-out if user is deleted
    }

    // Mark the check as performed so we don't block the UI unnecessarily on subsequent rebuilds
    if (mounted) { // Check if the widget is still in the tree before calling setState
      setState(() {
        _initialCheckPerformed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the AuthService instance using Provider
    final authService = Provider.of<AuthService>(context);

    // StreamBuilder listens to authStateChanges from AuthService
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while Firebase initializes OR while our initial server check is running
        // The `_initialCheckPerformed` flag ensures we don't jump to the login page prematurely
        if (snapshot.connectionState == ConnectionState.waiting || !_initialCheckPerformed) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If snapshot.data is null, it means no user is logged in (or was just signed out by refreshCurrentUser)
        if (snapshot.data == null) {
          print('AuthWrapper: No user logged in, showing LoginPage.');
          return SignInPage(); // Use const LoginPage() if your LoginPage constructor is const
        } else {
          // If a user is logged in, show the home page
          print('AuthWrapper: User is logged in (${snapshot.data!.uid}), showing HomeNavigation.');
          return const MyExplorePage(); // Assuming MyExplorePage is HomeNavigation
        }
      },
    );
  }
}
