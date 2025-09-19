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
        // Sort by role first (Admin, Staff, Caregiver), then by name
        final roleOrder = {'Admin': 0, 'Staff': 1, 'Caregiver': 2};
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

      if (role.toLowerCase() == 'staff') {
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

  /// One-time migration to convert all "Nurse" roles to "Staff"
  /// Only Super Admin can run this migration
  static Future<void> migrateNurseRolesToStaff() async {
    if (!await isSuperAdmin()) {
      throw Exception('Unauthorized: Only Super Admin can run role migrations');
    }

    try {
      print('🔄 Super Admin starting migration: Converting Nurse roles to Staff...');

      // Log this operation
      await logSuperAdminOperation('ROLE_MIGRATION', 'Started Nurse to Staff migration');

      // Get all users with "Nurse" role
      QuerySnapshot nursesQuery = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      if (nursesQuery.docs.isEmpty) {
        print('✅ No Nurse roles found. Migration not needed.');
        await logSuperAdminOperation('ROLE_MIGRATION', 'No Nurse roles found - migration skipped');
        return;
      }

      print('📊 Found ${nursesQuery.docs.length} users with Nurse role to migrate');

      int successCount = 0;
      int errorCount = 0;
      List<String> updatedUsers = [];

      // Update each nurse to staff role
      for (QueryDocumentSnapshot doc in nursesQuery.docs) {
        try {
          await doc.reference.update({'role': 'Staff'});

          final userData = doc.data() as Map<String, dynamic>;
          final userName = userData['name'] ?? 'Unknown';
          final userEmail = userData['email'] ?? 'No email';

          print('✅ Updated user: $userName ($userEmail) from Nurse to Staff');
          updatedUsers.add('$userName ($userEmail)');
          successCount++;

        } catch (e) {
          print('❌ Failed to update user ${doc.id}: $e');
          errorCount++;
        }
      }

      print('🎉 Migration completed!');
      print('✅ Successfully updated: $successCount users');
      if (errorCount > 0) {
        print('❌ Failed to update: $errorCount users');
      }

      // Log the results
      final migrationResults = 'Successfully updated $successCount users. Failed: $errorCount users. Updated users: ${updatedUsers.join(', ')}';
      await logSuperAdminOperation('ROLE_MIGRATION', migrationResults);

      // Update user counts after migration
      await _updateUserCountsAfterMigration();

    } catch (e) {
      print('❌ Migration failed with error: $e');
      await logSuperAdminOperation('ROLE_MIGRATION_ERROR', 'Migration failed: $e');
      rethrow;
    }
  }

  /// Update user counts after role migration
  static Future<void> _updateUserCountsAfterMigration() async {
    try {
      print('🔄 Updating user counts after migration...');

      // Count all users by role
      QuerySnapshot allUsers = await _firestore.collection('Users').get();

      int staffCount = 0;
      int caregiverCount = 0;
      int adminCount = 0;

      for (QueryDocumentSnapshot doc in allUsers.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final role = userData['role']?.toString().toLowerCase() ?? '';

        switch (role) {
          case 'staff':
            staffCount++;
            break;
          case 'caregiver':
            caregiverCount++;
            break;
          case 'admin':
            adminCount++;
            break;
        }
      }

      // Update the counts document
      await _firestore
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .update({
        'nurse': staffCount, // Keep the field name for backward compatibility
        'caregiver': caregiverCount,
      });

      print('✅ User counts updated: Staff: $staffCount, Caregivers: $caregiverCount, Admins: $adminCount');

    } catch (e) {
      print('❌ Failed to update user counts: $e');
    }
  }

  /// Verify migration was successful
  static Future<Map<String, dynamic>> verifyRoleMigration() async {
    if (!await isSuperAdmin()) {
      throw Exception('Unauthorized: Only Super Admin can verify migrations');
    }

    try {
      print('🔍 Verifying role migration...');

      // Check for any remaining Nurse roles
      QuerySnapshot remainingNurses = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      // Count all Staff roles
      QuerySnapshot staffQuery = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Staff')
          .get();

      final result = {
        'remaining_nurses': remainingNurses.docs.length,
        'current_staff_count': staffQuery.docs.length,
        'migration_successful': remainingNurses.docs.isEmpty,
        'remaining_nurse_users': remainingNurses.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return '${data['name']} (${data['email']})';
        }).toList(),
      };

      if (result['migration_successful'] == true) {
        print('✅ Migration verification successful: No Nurse roles remaining');
      } else {
        print('⚠️ Migration incomplete: ${result['remaining_nurses']} Nurse roles still exist');
      }

      print('📊 Current Staff count: ${result['current_staff_count']}');

      return result;

    } catch (e) {
      print('❌ Migration verification failed: $e');
      rethrow;
    }
  }
}