import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserDocumentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a user document for an authenticated user if it doesn't exist
  static Future<bool> ensureUserDocumentExists({
    String? customRole,
    String? customName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ UserDocumentService: No authenticated user found');
        return false;
      }

      debugPrint('🔍 UserDocumentService: Checking user document for ${user.email}');
      
      // Check if document already exists
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      
      if (userDoc.exists) {
        debugPrint('✅ UserDocumentService: User document already exists');
        return true;
      }

      debugPrint('📝 UserDocumentService: Creating missing user document...');
      
      // Extract name from email if not provided
      final defaultName = customName ?? user.email?.split('@')[0] ?? 'User';
      
      // Create the user document with default values
      await _firestore.collection('Users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': defaultName,
        'role': customRole ?? 'Caregiver', // Default role
        'assigned_video': 0,
        'completed_video': 0,
        'mobile_number': '',
        'dob': '',
        'profile_image_url': '',
        'created_at': FieldValue.serverTimestamp(),
        'fcmtoken': '',
      });

      debugPrint('✅ UserDocumentService: User document created successfully');
      debugPrint('📊 UserDocumentService: Document details:');
      debugPrint('   - UID: ${user.uid}');
      debugPrint('   - Email: ${user.email}');
      debugPrint('   - Name: $defaultName');
      debugPrint('   - Role: ${customRole ?? 'Caregiver'}');
      
      return true;
    } catch (e) {
      debugPrint('❌ UserDocumentService: Error creating user document: $e');
      return false;
    }
  }

  /// Creates user documents for all existing authenticated users
  static Future<void> createDocumentsForExistingUsers() async {
    try {
      debugPrint('🔄 UserDocumentService: Creating documents for existing users...');
      
      // This is a manual process - you would need to provide the user details
      // For your specific case, let's create the document for j.khinda@ccgrhc.com
      
      final user = _auth.currentUser;
      if (user != null && user.email == 'j.khinda@ccgrhc.com') {
        await ensureUserDocumentExists(
          customRole: 'Admin', // Assuming you're an admin
          customName: 'Jass Khinda',
        );
      }
      
    } catch (e) {
      debugPrint('❌ UserDocumentService: Error in batch creation: $e');
    }
  }

  /// Validates that a user document exists and has required fields
  static Future<bool> validateUserDocument() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('❌ UserDocumentService: User document does not exist');
        return false;
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('❌ UserDocumentService: User document data is null');
        return false;
      }

      // Check required fields
      final requiredFields = ['uid', 'email', 'name', 'role'];
      for (final field in requiredFields) {
        if (!data.containsKey(field) || data[field] == null || data[field] == '') {
          debugPrint('❌ UserDocumentService: Missing required field: $field');
          return false;
        }
      }

      debugPrint('✅ UserDocumentService: User document is valid');
      return true;
    } catch (e) {
      debugPrint('❌ UserDocumentService: Error validating user document: $e');
      return false;
    }
  }
}
