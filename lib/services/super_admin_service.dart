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
      // First map all documents
      List<Map<String, dynamic>> allUsers = snapshot.docs.map((doc) {
        return {
          'uid': doc.id,
          ...doc.data(),
        };
      }).toList();

      // Deduplicate users by email (keep the most recently created document)
      Map<String, Map<String, dynamic>> uniqueUsers = {};
      for (var user in allUsers) {
        final email = user['email']?.toString().toLowerCase();
        if (email != null && email.isNotEmpty) {
          // If this email exists, keep the one with more recent creation or longer uid
          if (!uniqueUsers.containsKey(email) ||
              (user['uid']?.toString().length ?? 0) > (uniqueUsers[email]?['uid']?.toString().length ?? 0)) {
            uniqueUsers[email] = user;
          }
        }
      }

      return uniqueUsers.values.toList()..sort((a, b) {
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

  /// Identify and report duplicate user documents
  /// Only Super Admin can run this operation
  static Future<Map<String, dynamic>> identifyDuplicateUsers() async {
    if (!await isSuperAdmin()) {
      throw Exception('Unauthorized: Only Super Admin can identify duplicates');
    }

    try {
      print('🔍 Identifying duplicate user documents...');

      QuerySnapshot allUsers = await _firestore.collection('Users').get();

      Map<String, List<Map<String, dynamic>>> emailGroups = {};

      // Group users by email
      for (QueryDocumentSnapshot doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final email = data['email']?.toString().toLowerCase();

        if (email != null && email.isNotEmpty) {
          if (!emailGroups.containsKey(email)) {
            emailGroups[email] = [];
          }
          emailGroups[email]!.add({
            'uid': doc.id,
            'name': data['name'],
            'email': data['email'],
            'role': data['role'],
          });
        }
      }

      // Find duplicates
      Map<String, List<Map<String, dynamic>>> duplicates = {};
      int totalDuplicates = 0;

      for (String email in emailGroups.keys) {
        if (emailGroups[email]!.length > 1) {
          duplicates[email] = emailGroups[email]!;
          totalDuplicates += emailGroups[email]!.length - 1; // -1 because one is original
        }
      }

      final result = {
        'total_users': allUsers.docs.length,
        'unique_emails': emailGroups.keys.length,
        'duplicate_emails': duplicates.keys.length,
        'extra_documents': totalDuplicates,
        'duplicates': duplicates,
      };

      if (duplicates.isEmpty) {
        print('✅ No duplicate user documents found');
      } else {
        print('⚠️ Found ${duplicates.keys.length} emails with duplicate documents');
        print('📊 Total extra documents: $totalDuplicates');

        for (String email in duplicates.keys) {
          print('  📧 $email has ${duplicates[email]!.length} documents');
        }
      }

      await logSuperAdminOperation('DUPLICATE_CHECK', 'Checked for duplicate users - found ${duplicates.keys.length} duplicate emails');

      return result;

    } catch (e) {
      print('❌ Duplicate identification failed: $e');
      rethrow;
    }
  }

  /// Clean up duplicate user documents (keeps the one with longest UID)
  /// Only Super Admin can run this operation
  static Future<void> cleanupDuplicateUsers() async {
    if (!await isSuperAdmin()) {
      throw Exception('Unauthorized: Only Super Admin can cleanup duplicates');
    }

    try {
      print('🧹 Starting duplicate user cleanup...');

      // First identify duplicates
      final duplicateInfo = await identifyDuplicateUsers();
      final duplicates = duplicateInfo['duplicates'] as Map<String, List<Map<String, dynamic>>>;

      if (duplicates.isEmpty) {
        print('✅ No duplicates to clean up');
        return;
      }

      int deletedCount = 0;
      List<String> deletedDocuments = [];

      for (String email in duplicates.keys) {
        final userDocs = duplicates[email]!;

        // Sort by UID length (longer UIDs are usually newer)
        userDocs.sort((a, b) => (b['uid']?.toString().length ?? 0).compareTo(a['uid']?.toString().length ?? 0));

        // Keep the first one (longest UID), delete the rest
        for (int i = 1; i < userDocs.length; i++) {
          final docToDelete = userDocs[i];
          try {
            await _firestore.collection('Users').doc(docToDelete['uid']).delete();
            deletedCount++;
            deletedDocuments.add('${docToDelete['name']} (${docToDelete['email']}) - UID: ${docToDelete['uid']}');
            print('🗑️ Deleted duplicate: ${docToDelete['name']} (${docToDelete['email']})');
          } catch (e) {
            print('❌ Failed to delete duplicate ${docToDelete['uid']}: $e');
          }
        }
      }

      print('🎉 Cleanup completed!');
      print('✅ Deleted $deletedCount duplicate documents');

      await logSuperAdminOperation('DUPLICATE_CLEANUP', 'Cleaned up $deletedCount duplicate user documents: ${deletedDocuments.join(', ')}');

    } catch (e) {
      print('❌ Duplicate cleanup failed: $e');
      await logSuperAdminOperation('DUPLICATE_CLEANUP_ERROR', 'Cleanup failed: $e');
      rethrow;
    }
  }
}