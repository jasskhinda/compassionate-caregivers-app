import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Find and report duplicate users by email
  static Future<Map<String, List<DocumentSnapshot>>> findDuplicateUsers() async {
    try {
      final snapshot = await _firestore.collection('Users').get();
      final Map<String, List<DocumentSnapshot>> duplicates = {};

      // Group users by email
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final email = data['email']?.toString().toLowerCase();

        if (email != null && email.isNotEmpty) {
          if (!duplicates.containsKey(email)) {
            duplicates[email] = [];
          }
          duplicates[email]!.add(doc);
        }
      }

      // Filter to only return emails with duplicates
      duplicates.removeWhere((email, docs) => docs.length <= 1);

      print('Found duplicates for ${duplicates.length} email addresses:');
      for (var entry in duplicates.entries) {
        print('Email: ${entry.key} - ${entry.value.length} documents');
        for (var doc in entry.value) {
          final data = doc.data() as Map<String, dynamic>;
          print('  - ID: ${doc.id}, Name: ${data['name']}, Role: ${data['role']}');
        }
      }

      return duplicates;
    } catch (e) {
      print('Error finding duplicate users: $e');
      return {};
    }
  }

  /// Clean up duplicate users, keeping the best one for each email
  static Future<bool> cleanupDuplicateUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Error: No authenticated user');
        return false;
      }

      // Check if current user is admin
      final userDoc = await _firestore.collection('Users').doc(currentUser.uid).get();
      if (!userDoc.exists || userDoc.data()?['role'] != 'Admin') {
        print('Error: Only admins can perform cleanup operations');
        return false;
      }

      final duplicates = await findDuplicateUsers();
      if (duplicates.isEmpty) {
        print('No duplicate users found');
        return true;
      }

      int totalRemoved = 0;

      for (var entry in duplicates.entries) {
        final email = entry.key;
        final docs = entry.value;

        print('Cleaning up duplicates for: $email');

        // Find the best document to keep
        DocumentSnapshot? bestDoc;
        int bestScore = -1;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          int score = _calculateDocumentScore(data);

          if (score > bestScore) {
            bestScore = score;
            bestDoc = doc;
          }
        }

        if (bestDoc == null) continue;

        print('Keeping document: ${bestDoc.id}');

        // Remove all other documents for this email
        for (var doc in docs) {
          if (doc.id != bestDoc.id) {
            try {
              await doc.reference.delete();
              totalRemoved++;
              print('Removed duplicate document: ${doc.id}');
            } catch (e) {
              print('Error removing document ${doc.id}: $e');
            }
          }
        }
      }

      print('Cleanup completed. Removed $totalRemoved duplicate documents.');
      return true;

    } catch (e) {
      print('Error during cleanup: $e');
      return false;
    }
  }

  /// Calculate a score for document quality (higher is better)
  static int _calculateDocumentScore(Map<String, dynamic> data) {
    int score = 0;

    // Prefer documents with proper names (not "Unknown User")
    final name = data['name']?.toString() ?? '';
    if (name.isNotEmpty && !name.toLowerCase().contains('unknown')) {
      score += 10;
    }

    // Prefer documents with valid roles
    final role = data['role']?.toString() ?? '';
    if (['Admin', 'Nurse', 'Caregiver'].contains(role)) {
      score += 5;
    }

    // Prefer documents with profile images
    if (data['profile_image_url'] != null && data['profile_image_url'].toString().isNotEmpty) {
      score += 2;
    }

    // Prefer documents with phone numbers
    if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
      score += 1;
    }

    // Prefer documents with address
    if (data['address'] != null && data['address'].toString().isNotEmpty) {
      score += 1;
    }

    return score;
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final snapshot = await _firestore.collection('Users').get();
      final Map<String, int> roleCounts = {};
      final Set<String> uniqueEmails = {};
      int totalDocs = snapshot.docs.length;
      int validDocs = 0;
      int duplicateDocs = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final email = data['email']?.toString().toLowerCase();
        final role = data['role']?.toString() ?? 'Unknown';

        // Count roles
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;

        // Check for valid documents
        if (email != null && email.isNotEmpty &&
            data['name'] != null && data['name'].toString().isNotEmpty) {
          validDocs++;
        }

        // Track unique emails
        if (email != null && email.isNotEmpty) {
          if (uniqueEmails.contains(email)) {
            duplicateDocs++;
          } else {
            uniqueEmails.add(email);
          }
        }
      }

      return {
        'totalDocuments': totalDocs,
        'validDocuments': validDocs,
        'uniqueEmails': uniqueEmails.length,
        'duplicateDocuments': duplicateDocs,
        'roleCounts': roleCounts,
      };

    } catch (e) {
      print('Error getting user statistics: $e');
      return {};
    }
  }
}