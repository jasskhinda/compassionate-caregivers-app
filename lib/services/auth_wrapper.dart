import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/presentation/auth/login/login_screen.dart';
import 'package:caregiver/presentation/main/main_screen.dart';
import 'package:caregiver/services/user_document_service.dart';
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
      debugPrint('🔄 AuthWrapper: Starting authentication initialization...');
      debugPrint('🌐 AuthWrapper: Current URL: ${Uri.base.toString()}');
      
      // Wait for Firebase Auth to initialize
      await FirebaseAuth.instance.authStateChanges().first;
      debugPrint('✅ AuthWrapper: Firebase Auth state received');
      
      // Set persistence for web
      if (kIsWeb) {
        debugPrint('🌐 AuthWrapper: Setting web persistence to LOCAL...');
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        debugPrint('✅ AuthWrapper: Web persistence set successfully');
        
        // Additional debugging for web
        debugPrint('🔍 AuthWrapper: Checking localStorage availability...');
        
        // Additional web-specific checks
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint('👤 AuthWrapper: Current user found: ${currentUser.email}');
          debugPrint('📧 AuthWrapper: User email verified: ${currentUser.emailVerified}');
          debugPrint('🔐 AuthWrapper: User UID: ${currentUser.uid}');
          debugPrint('🕒 AuthWrapper: User created: ${currentUser.metadata.creationTime}');
          debugPrint('🕒 AuthWrapper: Last sign in: ${currentUser.metadata.lastSignInTime}');
        } else {
          debugPrint('❌ AuthWrapper: No current user found');
        }
      }
      
      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _isInitialized = true;
      });
      debugPrint('🎉 AuthWrapper: Initialization completed successfully');
    } catch (e) {
      debugPrint('❌ AuthWrapper: Error initializing auth: $e');
      debugPrint('❌ AuthWrapper: Error type: ${e.runtimeType}');
      
      // Check for specific error types
      if (e.toString().contains('auth/unauthorized-domain')) {
        debugPrint('🚨 DOMAIN ERROR: ccapp.compassionatecaregivershc.com needs to be added to Firebase Auth authorized domains');
      } else if (e.toString().contains('network')) {
        debugPrint('🌐 NETWORK ERROR: Check internet connection and Firebase configuration');
      } else if (e.toString().contains('persistence')) {
        debugPrint('💾 PERSISTENCE ERROR: Local storage may be disabled or unavailable');
      }
      
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
        debugPrint('🔄 AuthWrapper StreamBuilder: Connection state: ${snapshot.connectionState}');
        debugPrint('🔄 AuthWrapper StreamBuilder: Has data: ${snapshot.hasData}');
        debugPrint('🔄 AuthWrapper StreamBuilder: Data: ${snapshot.data?.email ?? 'null'}');
        
        // Connection state check
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ AuthWrapper: Waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Error handling
        if (snapshot.hasError) {
          debugPrint('❌ AuthWrapper: Auth stream error: ${snapshot.error}');
          debugPrint('❌ AuthWrapper: Error type: ${snapshot.error.runtimeType}');
          return const LoginScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          debugPrint('✅ AuthWrapper: User authenticated - checking user document...');
          debugPrint('👤 AuthWrapper: User email: ${user.email}');
          debugPrint('🔐 AuthWrapper: User UID: ${user.uid}');
          
          // Ensure user document exists before proceeding to MainScreen
          return FutureBuilder<bool>(
            future: UserDocumentService.ensureUserDocumentExists(
              customRole: user.email == 'j.khinda@ccgrhc.com' ? 'Admin' : 'Caregiver',
              customName: user.email == 'j.khinda@ccgrhc.com' ? 'Jass Khinda' : null,
            ),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Setting up your account...'),
                      ],
                    ),
                  ),
                );
              }
              
              if (docSnapshot.hasError) {
                debugPrint('❌ AuthWrapper: Error setting up user document: ${docSnapshot.error}');
                return const LoginScreen();
              }
              
              final documentCreated = docSnapshot.data ?? false;
              if (documentCreated) {
                debugPrint('✅ AuthWrapper: User document ready - redirecting to MainScreen');
                return const MainScreen();
              } else {
                debugPrint('❌ AuthWrapper: Failed to create user document - redirecting to LoginScreen');
                return const LoginScreen();
              }
            },
          );
        }

        // User is not logged in
        debugPrint('🔓 AuthWrapper: No user authenticated - redirecting to LoginScreen');
        return const LoginScreen();
      },
    );
  }
}
