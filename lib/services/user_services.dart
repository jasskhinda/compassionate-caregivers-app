import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserServices {
  // Get instance of firestore & auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get nurse stream
  Stream<List<Map<String, dynamic>>> getNursesStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()) // Extract user data
          .where((user) => user['role'] == 'Nurse') // Filter only nurses
          .toList();
    });
  }

  // Get nurse stream
  Stream<List<Map<String, dynamic>>> getCaregiverStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()) // Extract user data
          .where((user) => user['role'] == 'Caregiver') // Filter only nurses
          .toList();
    });
  }

  Future<void> deleteUser(String userId, String role) async {
    try {
      // Step 1: Delete all videos from caregiver_videos/{userId}/videos
      final videosSnapshot = await FirebaseFirestore.instance
          .collection('caregiver_videos')
          .doc(userId)
          .collection('videos')
          .get();

      for (final doc in videosSnapshot.docs) {
        await doc.reference.delete();
      }

      // Step 2: Delete caregiver_videos/{userId} doc
      await FirebaseFirestore.instance
          .collection('caregiver_videos')
          .doc(userId)
          .delete();

      // Step 3: Delete Users/{userId} doc
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .delete();

      // Step 4
      await _firestore
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .update({role.toLowerCase(): FieldValue.increment(-1)});

      print("✅ All user data deleted for $userId");

    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

  Future<void> deleteNurseUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .delete();

      await _firestore
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .update({'nurse': FieldValue.increment(-1)});

      print("✅ All user data deleted for $userId");

    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

}