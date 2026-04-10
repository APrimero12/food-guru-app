import 'package:appdevproject/views/explore/explore_page.dart';
import 'package:appdevproject/views/login/login_screen.dart';
import 'package:appdevproject/views/login/signup_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/' : (context) => SignInPage(),
        '/signup' : (context) => SignUpScreen(),
        '/home' : (context) => MyExplorePage()
      },
    );
  }
}
