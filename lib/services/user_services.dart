import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UserServices {
  // Get instance of firestore, auth & functions
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get staff stream (formerly nurse stream) - includes both Staff and Nurse roles
  Stream<List<Map<String, dynamic>>> getStaffStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()) // Extract user data
          .where((user) => user['role'] == 'Staff' || user['role'] == 'Nurse') // Filter both staff and nurse
          .toList();
    });
  }

  // Keep for backward compatibility - will be deprecated
  Stream<List<Map<String, dynamic>>> getNursesStream() {
    return getStaffStream();
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
      // Call Cloud Function to delete user properly from both Auth and Firestore
      final HttpsCallable callable = _functions.httpsCallable('deleteUser');
      final result = await callable.call({
        'userId': userId,
        'role': role,
      });

      print("✅ User deleted via Cloud Function: ${result.data['message']}");

    } catch (e) {
      print('❌ Error calling Cloud Function to delete user: $e');

      // Fallback to client-side deletion if Cloud Function fails
      try {
        await _deleteUserClientSide(userId, role);
      } catch (fallbackError) {
        print('❌ Fallback deletion also failed: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> _deleteUserClientSide(String userId, String role) async {
    try {
      // Fallback method - delete from Firestore only
      print("⚠️ Using fallback client-side deletion for $userId");

      // Delete all videos from caregiver_videos/{userId}/videos
      if (role.toLowerCase() == 'caregiver') {
        final videosSnapshot = await FirebaseFirestore.instance
            .collection('caregiver_videos')
            .doc(userId)
            .collection('videos')
            .get();

        for (final doc in videosSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete caregiver_videos/{userId} doc
        await FirebaseFirestore.instance
            .collection('caregiver_videos')
            .doc(userId)
            .delete();
      }

      // Delete Users/{userId} doc
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .delete();

      // Update user count
      await _firestore
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .update({role.toLowerCase(): FieldValue.increment(-1)});

      print("✅ User data deleted from Firestore for $userId (Auth deletion skipped)");

    } catch (e) {
      print('❌ Error in client-side deletion: $e');
      rethrow;
    }
  }

  Future<void> deleteNurseUser(String userId) async {
    try {
      // Call Cloud Function to delete nurse user
      await deleteUser(userId, 'Nurse');

    } catch (e) {
      print('❌ Error deleting nurse user: $e');
      rethrow;
    }
  }

  // Helper method to delete user from Firebase Authentication
  Future<void> _deleteUserFromAuth(String userId) async {
    try {
      // Store current user before creating secondary app
      User? originalUser = FirebaseAuth.instance.currentUser;

      // Get user data to find email for authentication
      DocumentSnapshot userDoc = await _firestore.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String userEmail = userData['email'];
        String? userPassword = userData['password']; // Only available for Admin users

        try {
          // Create secondary Firebase app for user deletion
          FirebaseApp secondaryApp = await Firebase.initializeApp(
            name: 'DeleteUser_${DateTime.now().millisecondsSinceEpoch}',
            options: Firebase.app().options,
          );

          FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

          // For users with stored passwords (Admin), try to sign in and delete
          if (userPassword != null) {
            UserCredential userCredential = await secondaryAuth.signInWithEmailAndPassword(
              email: userEmail,
              password: userPassword,
            );

            await userCredential.user!.delete();
          } else {
            // For users without stored passwords, we need to use Admin SDK
            // Since we can't use Admin SDK directly in client, we'll log this
            print("⚠️ Cannot delete user $userId from Auth - no stored password. Admin SDK required.");
          }

          // Clean up secondary app
          await secondaryAuth.signOut();
          await secondaryApp.delete();

        } catch (authError) {
          print("⚠️ Could not delete user from Firebase Auth: $authError");
          // Continue with Firestore deletion even if Auth deletion fails
        }
      }
    } catch (e) {
      print("⚠️ Error in _deleteUserFromAuth: $e");
      // Don't rethrow - continue with Firestore deletion
    }
  }

  // Method to fix user count discrepancies
  Future<void> syncUserCounts() async {
    try {
      // Try to use Cloud Function for syncing
      final HttpsCallable callable = _functions.httpsCallable('syncUserCounts');
      final result = await callable.call();

      print("✅ User counts synced via Cloud Function: ${result.data['message']}");
      print("Nurses: ${result.data['nurseCount']}, Caregivers: ${result.data['caregiverCount']}");

    } catch (e) {
      print('❌ Error calling Cloud Function for sync, using fallback: $e');

      // Fallback to client-side sync
      await _syncUserCountsClientSide();
    }
  }

  Future<void> _syncUserCountsClientSide() async {
    try {
      // Get all users from Firestore
      QuerySnapshot usersSnapshot = await _firestore.collection('Users').get();

      int nurseCount = 0;
      int caregiverCount = 0;

      // Count actual users by role
      for (QueryDocumentSnapshot doc in usersSnapshot.docs) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? '';

        switch (role.toLowerCase()) {
          case 'nurse':
            nurseCount++;
            break;
          case 'caregiver':
            caregiverCount++;
            break;
        }
      }

      // Update the count document with actual counts
      await _firestore
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .update({
        'nurse': nurseCount,
        'caregiver': caregiverCount,
      });

      print("✅ User counts synced (fallback): Nurses: $nurseCount, Caregivers: $caregiverCount");
    } catch (e) {
      print('❌ Error syncing user counts: $e');
      rethrow;
    }
  }

  // Method to get orphaned Firebase Auth users (users in Auth but not in Firestore)
  Future<List<String>> getOrphanedAuthUsers() async {
    try {
      List<String> orphanedUsers = [];

      // Get all users from Firestore
      QuerySnapshot firestoreUsers = await _firestore.collection('Users').get();
      Set<String> firestoreUids = firestoreUsers.docs.map((doc) => doc.id).toSet();

      // Note: We cannot list Firebase Auth users directly from client-side code
      // This would require Firebase Admin SDK running on a server
      print("⚠️ Cannot list Firebase Auth users from client-side. Admin SDK required.");

      return orphanedUsers;
    } catch (e) {
      print('❌ Error getting orphaned users: $e');
      return [];
    }
  }

}