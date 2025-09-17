import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AuthDebugService {
  static StreamSubscription<User?>? _authSubscription;
  static Timer? _debugTimer;

  static void startDebugging() {
    if (!kIsWeb) return;
    
    debugPrint('🔍 AuthDebugService: Starting authentication debugging...');
    
    // Monitor auth state changes with detailed logging
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        debugPrint('🔄 AuthDebugService: Auth state changed');
        if (user != null) {
          debugPrint('✅ AuthDebugService: User is signed in');
          debugPrint('📧 Email: ${user.email}');
          debugPrint('🔐 UID: ${user.uid}');
          debugPrint('📧 Email verified: ${user.emailVerified}');
          debugPrint('🏷️ Display name: ${user.displayName ?? 'None'}');
          debugPrint('📱 Phone: ${user.phoneNumber ?? 'None'}');
          debugPrint('🕒 Created: ${user.metadata.creationTime}');
          debugPrint('🕒 Last sign in: ${user.metadata.lastSignInTime}');
        } else {
          debugPrint('❌ AuthDebugService: User is signed out');
        }
      },
      onError: (error) {
        debugPrint('❌ AuthDebugService: Auth state error: $error');
      },
    );

    // Periodic authentication status check
    _debugTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('⏰ AuthDebugService: Periodic check - User: ${user?.email ?? 'None'}');
      
      if (user != null) {
        // Check if token is still valid
        user.getIdToken(false).then((token) {
          debugPrint('🔑 AuthDebugService: Token is valid (length: ${token?.length ?? 0})');
        }).catchError((error) {
          debugPrint('❌ AuthDebugService: Token error: $error');
        });
      }
    });
  }

  static void stopDebugging() {
    debugPrint('🛑 AuthDebugService: Stopping debugging...');
    _authSubscription?.cancel();
    _debugTimer?.cancel();
  }

  static Future<void> testAuthentication() async {
    debugPrint('🧪 AuthDebugService: Running authentication test...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ Test: No user currently signed in');
        return;
      }

      debugPrint('✅ Test: User found: ${user.email}');
      
      // Test token refresh
      final token = await user.getIdToken(true);
      debugPrint('✅ Test: Token refreshed successfully (length: ${token?.length ?? 0})');
      
      // Test persistence
      final persistence = await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      debugPrint('✅ Test: Persistence setting completed');
      
    } catch (e) {
      debugPrint('❌ Test: Authentication test failed: $e');
    }
  }

  static void logCurrentState() {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('📊 AuthDebugService: Current state summary:');
    debugPrint('  - User: ${user?.email ?? 'None'}');
    debugPrint('  - Signed in: ${user != null}');
    debugPrint('  - Email verified: ${user?.emailVerified ?? false}');
    debugPrint('  - Current URL: ${Uri.base.toString()}');
  }
}
