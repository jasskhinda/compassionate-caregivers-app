import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SuperAdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Super Admin email - only this user can delete admins
  static const String SUPER_ADMIN_EMAIL = 'j.khinda@ccgrhc.com';

  /// Check if current user is the Super Admin
  static Future<bool> isSuperAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check email first for quick validation
      if (currentUser.email?.toLowerCase() != SUPER_ADMIN_EMAIL.toLowerCase()) {
        return false;
      }

      // Double-check with Firestore document
      final userDoc = await _firestore.collection('Users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final email = userData['email']?.toString().toLowerCase();
      final role = userData['role']?.toString();

      return email == SUPER_ADMIN_EMAIL.toLowerCase() && role == 'Admin';
    } catch (e) {
      print('Error checking super admin status: $e');
      return false;
    }
  }

  /// Check if current user is a regular admin (but not super admin)
  static Future<bool> isRegularAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userDoc = await _firestore.collection('Users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role']?.toString();
      final email = userData['email']?.toString().toLowerCase();

      return role == 'Admin' && email != SUPER_ADMIN_EMAIL.toLowerCase();
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Check if a user can be deleted by the current user
  static Future<bool> canDeleteUser(String targetUserId, String targetUserRole) async {
    try {
      final isSuperAdminUser = await isSuperAdmin();
      final isRegularAdminUser = await isRegularAdmin();

      // Super Admin can delete anyone (including other admins)
      if (isSuperAdminUser) {
        return true;
      }

      // Regular Admins can delete Staff and Caregivers but NOT other Admins
      if (isRegularAdminUser && targetUserRole != 'Admin') {
        return true;
      }

      // No one else can delete users
      return false;
    } catch (e) {
      print('Error checking delete permissions: $e');
      return false;
    }
  }

  /// Get all admin users (only accessible by Super Admin)
  static Stream<List<Map<String, dynamic>>> getAdminsStream() {
    return _firestore
        .collection('Users')
        .where('role', isEqualTo: 'Admin')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'uid': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  /// Get all users regardless of role (only accessible by Super Admin)
  static Stream<List<Map<String, dynamic>>> getAllUsersStream() {
    return _firestore
        .collection('Users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'uid': doc.id,
          ...doc.data(),
        };
      }).toList()..sort((a, b) {
        // Sort by role first (Admin, Staff/Nurse, Caregiver), then by name
        final roleOrder = {'Admin': 0, 'Staff': 1, 'Nurse': 1, 'Caregiver': 2};
        final roleA = roleOrder[a['role']] ?? 3;
        final roleB = roleOrder[b['role']] ?? 3;

        if (roleA != roleB) {
          return roleA.compareTo(roleB);
        }

        // If same role, sort by name
        final nameA = a['name']?.toString().toLowerCase() ?? '';
        final nameB = b['name']?.toString().toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      });
    });
  }

  /// Enhanced user deletion with super admin privileges
  static Future<void> deleteUser(String userId, String userRole) async {
    try {
      final canDelete = await canDeleteUser(userId, userRole);
      if (!canDelete) {
        throw Exception('You do not have permission to delete this user');
      }

      // Get target user data before deletion for logging
      final targetUserDoc = await _firestore.collection('Users').doc(userId).get();
      final targetUserData = targetUserDoc.data() as Map<String, dynamic>?;
      final targetUserEmail = targetUserData?['email'] ?? 'Unknown';

      print('Super Admin deletion: User $targetUserEmail (Role: $userRole)');

      // Use existing user service deletion logic but with enhanced permissions
      final functions = FirebaseFunctions.instance;

      try {
        // Try Cloud Function first
        final result = await functions.httpsCallable('deleteUser').call({
          'userId': userId,
          'role': userRole, // Changed from 'userRole' to 'role' to match Cloud Function
        });

        print('✅ User deleted via Cloud Function: ${result.data}');
      } catch (cloudFunctionError) {
        print('❌ Cloud Function deletion failed: $cloudFunctionError');

        // Fallback to direct Firestore deletion (for super admin only)
        if (await isSuperAdmin()) {
          await _firestore.collection('Users').doc(userId).delete();

          // Update user counts
          await _updateUserCounts(userRole, -1);

          print('✅ User deleted via direct Firestore operation (Super Admin override)');
        } else {
          rethrow;
        }
      }

    } catch (e) {
      print('❌ Error in super admin deletion: $e');
      rethrow;
    }
  }

  /// Update user counts after deletion
  static Future<void> _updateUserCounts(String role, int change) async {
    try {
      final countDoc = _firestore.collection('users_count').doc('Ki8jsRs1u9Mk05F0g1UL');

      if (role.toLowerCase() == 'staff' || role.toLowerCase() == 'nurse') {
        await countDoc.update({
          'nurse': FieldValue.increment(change),
        });
      } else if (role.toLowerCase() == 'caregiver') {
        await countDoc.update({
          'caregiver': FieldValue.increment(change),
        });
      }
      // Note: We don't track admin counts in the current system

    } catch (e) {
      print('Error updating user counts: $e');
      // Don't rethrow - this is not critical for deletion
    }
  }

  /// Log super admin operations for audit trail
  static Future<void> logSuperAdminOperation(String operation, String details) async {
    try {
      await _firestore.collection('super_admin_logs').add({
        'operation': operation,
        'details': details,
        'performedBy': _auth.currentUser?.email ?? 'Unknown',
        'performedAt': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });
    } catch (e) {
      print('Error logging super admin operation: $e');
      // Don't rethrow - logging failure shouldn't stop the operation
    }
  }
}