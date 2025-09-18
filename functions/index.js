const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to delete a user from both Firebase Auth and Firestore
 * This function can only be called by authenticated Admin users
 */
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated',
        'User must be authenticated.');
  }

  // Check if the user has admin privileges
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('Users')
      .doc(callerUid).get();

  if (!callerDoc.exists || callerDoc.data().role !== 'Admin') {
    throw new functions.https.HttpsError('permission-denied',
        'Only admins can delete users.');
  }

  const {userId, role} = data;

  if (!userId || !role) {
    throw new functions.https.HttpsError('invalid-argument',
        'userId and role are required.');
  }

  try {
    // Step 1: Delete user from Firebase Authentication
    try {
      await admin.auth().deleteUser(userId);
      console.log(`✅ User ${userId} deleted from Firebase Auth`);
    } catch (authError) {
      console.log(`⚠️ Could not delete user from Auth: ${authError.message}`);
      // Continue with Firestore deletion even if Auth deletion fails
    }

    // Step 2: Delete caregiver videos if needed
    if (role.toLowerCase() === 'caregiver') {
      const videosSnapshot = await admin.firestore()
          .collection('caregiver_videos')
          .doc(userId)
          .collection('videos')
          .get();

      const batch = admin.firestore().batch();
      videosSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      if (!videosSnapshot.empty) {
        await batch.commit();
        console.log(`✅ Deleted ${videosSnapshot.size} videos for user ` +
                    `${userId}`);
      }

      // Delete caregiver_videos/{userId} doc
      await admin.firestore().collection('caregiver_videos')
          .doc(userId).delete();
    }

    // Step 3: Delete Users/{userId} doc
    await admin.firestore().collection('Users').doc(userId).delete();

    // Step 4: Update user count
    const userCountField = (role.toLowerCase() === 'staff' || role.toLowerCase() === 'nurse') ? 'nurse' : role.toLowerCase();
    await admin.firestore()
        .collection('users_count')
        .doc('Ki8jsRs1u9Mk05F0g1UL')
        .update({
          [userCountField]: admin.firestore.FieldValue.increment(-1),
        });

    console.log(`✅ All user data deleted for ${userId}`);

    return {
      success: true,
      message: `User ${userId} deleted successfully`,
    };
  } catch (error) {
    console.error(`❌ Error deleting user ${userId}:`, error);
    throw new functions.https.HttpsError('internal',
        `Failed to delete user: ${error.message}`);
  }
});

/**
 * Cloud Function to sync user counts with actual Firestore data
 * This function can only be called by authenticated Admin users
 */
exports.syncUserCounts = functions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated',
        'User must be authenticated.');
  }

  // Check if the user has admin privileges
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('Users')
      .doc(callerUid).get();

  if (!callerDoc.exists || callerDoc.data().role !== 'Admin') {
    throw new functions.https.HttpsError('permission-denied',
        'Only admins can sync user counts.');
  }

  try {
    // Get all users from Firestore
    const usersSnapshot = await admin.firestore().collection('Users').get();

    let staffCount = 0;
    let caregiverCount = 0;

    // Count actual users by role
    usersSnapshot.docs.forEach((doc) => {
      const userData = doc.data();
      const role = userData.role || '';

      switch (role.toLowerCase()) {
        case 'staff':
        case 'nurse': // Keep for backward compatibility
          staffCount++;
          break;
        case 'caregiver':
          caregiverCount++;
          break;
      }
    });

    // Update the count document with actual counts
    await admin.firestore()
        .collection('users_count')
        .doc('Ki8jsRs1u9Mk05F0g1UL')
        .update({
          nurse: staffCount, // Keep 'nurse' field name for backward compatibility
          caregiver: caregiverCount,
        });

    console.log(`✅ User counts synced: Staff: ${staffCount}, ` +
                `Caregivers: ${caregiverCount}`);

    return {
      success: true,
      staffCount,
      caregiverCount,
      message: 'User counts synced successfully',
    };
  } catch (error) {
    console.error('❌ Error syncing user counts:', error);
    throw new functions.https.HttpsError('internal',
        `Failed to sync user counts: ${error.message}`);
  }
});
