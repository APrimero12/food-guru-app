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

// 4. Create an AuthWrapper to listen to authentication changes
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key}); // Added const constructor

  @override
  Widget build(BuildContext context) {
    // Access the AuthService instance using Provider
    final authService = Provider.of<AuthService>(context);

    // StreamBuilder listens to authStateChanges from AuthService
    return StreamBuilder<User?>( // 'User?' comes from firebase_auth
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Handle connection states (e.g., waiting for Firebase to check auth status)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If data is available and the user is null, show the login page
        if (snapshot.data == null) {
          return SignInPage(); // Assuming SignInPage is your LoginPage
        } else {
          // If a user is logged in, show the home page
          return MyExplorePage();
        }
      },
    );
  }
}
