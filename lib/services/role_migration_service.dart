import 'package:cloud_firestore/cloud_firestore.dart';

class RoleMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// One-time migration to convert all "Nurse" roles to "Staff"
  /// This should be run once after deployment to update existing users
  static Future<void> migrateNurseRolesToStaff() async {
    try {
      print('🔄 Starting migration: Converting Nurse roles to Staff...');

      // Get all users with "Nurse" role
      QuerySnapshot nursesQuery = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      if (nursesQuery.docs.isEmpty) {
        print('✅ No Nurse roles found. Migration not needed.');
        return;
      }

      print('📊 Found ${nursesQuery.docs.length} users with Nurse role to migrate');

      int successCount = 0;
      int errorCount = 0;

      // Update each nurse to staff role
      for (QueryDocumentSnapshot doc in nursesQuery.docs) {
        try {
          await doc.reference.update({'role': 'Staff'});

          final userData = doc.data() as Map<String, dynamic>;
          final userName = userData['name'] ?? 'Unknown';
          final userEmail = userData['email'] ?? 'No email';

          print('✅ Updated user: $userName ($userEmail) from Nurse to Staff');
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

      // Optionally update the user counts to reflect the changes
      await _updateUserCounts();

    } catch (e) {
      print('❌ Migration failed with error: $e');
      rethrow;
    }
  }

  /// Update the user counts document after migration
  static Future<void> _updateUserCounts() async {
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
  static Future<void> verifyMigration() async {
    try {
      print('🔍 Verifying migration...');

      // Check for any remaining Nurse roles
      QuerySnapshot remainingNurses = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Nurse')
          .get();

      if (remainingNurses.docs.isEmpty) {
        print('✅ Migration verification successful: No Nurse roles remaining');
      } else {
        print('⚠️ Migration incomplete: ${remainingNurses.docs.length} Nurse roles still exist');
        for (QueryDocumentSnapshot doc in remainingNurses.docs) {
          final userData = doc.data() as Map<String, dynamic>;
          print('   - ${userData['name']} (${userData['email']})');
        }
      }

      // Count all Staff roles
      QuerySnapshot staffQuery = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Staff')
          .get();

      print('📊 Current Staff count: ${staffQuery.docs.length}');

    } catch (e) {
      print('❌ Migration verification failed: $e');
    }
  }

  /// Run complete migration with verification
  static Future<void> runCompleteMigration() async {
    print('🚀 Starting complete role migration process...');

    try {
      await migrateNurseRolesToStaff();
      await verifyMigration();
      print('🎉 Complete migration process finished successfully!');
    } catch (e) {
      print('❌ Migration process failed: $e');
      rethrow;
    }
  }
}