// lib/main.dart
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/views/home_navigation.dart';
import 'package:appdevproject/views/login/login_screen.dart';
import 'package:appdevproject/views/login/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'services/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
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
      title: 'FoodGuru App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
      routes: {
        '/signup': (context) => SignUpScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialCheckPerformed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialAuthCheck();
    });
  }

  Future<void> _performInitialAuthCheck() async {
    if (_initialCheckPerformed) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    if (authService.currentUser != null) {
      await authService.refreshCurrentUser();
    }

    if (mounted) {
      setState(() => _initialCheckPerformed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Still initialising or running the initial server check
        if (snapshot.connectionState == ConnectionState.waiting ||
            !_initialCheckPerformed) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == null) {
          // User signed out — clear any cached Firestore data
          userProvider.clearUser();
          return SignInPage();
        }

        // User is signed in — load their Firestore document if we don't have
        // it yet (or if it belongs to a different uid, e.g. after account switch)
        final uid = snapshot.data!.uid;
        if (userProvider.currentUser == null ||
            userProvider.currentUser!.uid != uid) {
          // Kick off the load; the Consumer in MyExplorePage will react
          userProvider.loadUser(uid);
        }

        return const MyExplorePage();
      },
    );
  }
}