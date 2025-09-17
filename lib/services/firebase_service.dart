import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize Firestore settings for web
  static Future<void> initializeFirestore() async {
    try {
      debugPrint('🔄 FirebaseService: Initializing Firestore...');
      if (kIsWeb) {
        debugPrint('🌐 FirebaseService: Web platform detected');
        
        // Enable network for web
        await _firestore.enableNetwork();
        debugPrint('✅ FirebaseService: Network enabled');
        
        // Set cache size for better performance
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ FirebaseService: Cache settings applied');
      }
      debugPrint('✅ FirebaseService: Firestore initialized successfully');
    } catch (e) {
      debugPrint('❌ FirebaseService: Error initializing Firestore: $e');
      debugPrint('❌ FirebaseService: Error type: ${e.runtimeType}');
    }
  }

  // Test Firestore connection
  static Future<bool> testConnection() async {
    try {
      // Try to read a simple document to test connection
      await _firestore.collection('test').doc('connection').get();
      debugPrint('Firestore connection test successful');
      return true;
    } catch (e) {
      debugPrint('Firestore connection test failed: $e');
      return false;
    }
  }

  // Get user document with error handling
  static Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) {
        debugPrint('User document retrieved successfully');
        return doc;
      } else {
        debugPrint('User document does not exist');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user document: $e');
      return null;
    }
  }

  // Get users count with error handling
  static Future<Map<String, dynamic>?> getUsersCount() async {
    try {
      final doc = await _firestore.collection('users_count').doc('Ki8jsRs1u9Mk05F0g1UL').get();
      if (doc.exists) {
        debugPrint('Users count retrieved successfully');
        return doc.data() as Map<String, dynamic>?;
      } else {
        debugPrint('Users count document does not exist');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting users count: $e');
      return null;
    }
  }

  // Check if user is properly authenticated
  static bool isUserAuthenticated() {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint('✅ FirebaseService: User is authenticated: ${user.email}');
      debugPrint('🔐 FirebaseService: User UID: ${user.uid}');
      debugPrint('📧 FirebaseService: Email verified: ${user.emailVerified}');
      return true;
    } else {
      debugPrint('❌ FirebaseService: User is not authenticated');
      return false;
    }
  }

  // Retry operation with exponential backoff
  static Future<T?> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        debugPrint('Operation failed (attempt ${i + 1}): $e');
        if (i == maxRetries - 1) {
          debugPrint('Max retries reached, operation failed');
          return null;
        }
        await Future.delayed(initialDelay * (i + 1));
      }
    }
    return null;
  }
}
