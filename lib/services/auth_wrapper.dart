import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/presentation/auth/login/login_screen.dart';
import 'package:caregiver/presentation/main/main_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Wait for Firebase Auth to initialize
      await FirebaseAuth.instance.authStateChanges().first;
      
      // Set persistence for web
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      
      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Connection state check
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error handling
        if (snapshot.hasError) {
          debugPrint('Auth stream error: ${snapshot.error}');
          return const LoginScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
