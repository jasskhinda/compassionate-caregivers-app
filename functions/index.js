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

  // Check if the user has admin privileges or is super admin
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('Users')
      .doc(callerUid).get();

  if (!callerDoc.exists || callerDoc.data().role !== 'Admin') {
    throw new functions.https.HttpsError('permission-denied',
        'Only admins can delete users.');
  }

  // Check if caller is super admin for enhanced permissions
  const callerEmail = callerDoc.data().email;
  const isSuperAdmin = callerEmail &&
      callerEmail.toLowerCase() === 'j.khinda@ccgrhc.com';

  const {userId, role} = data;

  console.log(`🔍 Delete user request: userId=${userId}, role=${role}, ` +
      `caller=${callerEmail}, isSuperAdmin=${isSuperAdmin}`);

  if (!userId || !role) {
    console.error('❌ Missing parameters:', {userId, role, data});
    throw new functions.https.HttpsError('invalid-argument',
        'userId and role are required.');
  }

  try {
    // Step 1: Delete user from Firebase Authentication
    let authDeleted = false;
    try {
      await admin.auth().deleteUser(userId);
      console.log(`✅ User ${userId} deleted from Firebase Auth`);
      authDeleted = true;
    } catch (authError) {
      console.log(`⚠️ Could not delete user from Auth: ${authError.message}`);
      if (authError.code === 'auth/user-not-found') {
        console.log(`ℹ️ User ${userId} was already deleted from Auth or ` +
            `never existed`);
        authDeleted = true; // Consider this a success
      }
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
    const userCountField = (role.toLowerCase() === 'staff' ||
        role.toLowerCase() === 'nurse') ? 'nurse' : role.toLowerCase();
    await admin.firestore()
        .collection('users_count')
        .doc('Ki8jsRs1u9Mk05F0g1UL')
        .update({
          [userCountField]: admin.firestore.FieldValue.increment(-1),
        });

    console.log(`✅ All user data deleted for ${userId} ` +
        `(Auth: ${authDeleted ? 'deleted' : 'skipped'})`);

    return {
      success: true,
      message: `User ${userId} deleted successfully from Firestore` +
          `${authDeleted ? ' and Firebase Auth' : ' (Auth deletion failed)'}`,
      authDeleted,
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
          // Keep 'nurse' field name for backward compatibility
          nurse: staffCount,
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

/**
 * Cloud Function to send push notification when a new chat message is created
 * Triggers on new document creation in chat_rooms/{chatRoomId}/messages
 */
exports.sendChatNotification = functions.firestore
    .document('chat_rooms/{chatRoomId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
      try {
        const messageData = snap.data();
        const {senderId, senderEmail, message, messageType} = messageData;
        const chatRoomId = context.params.chatRoomId;

        console.log(
            `📨 New message in chat room ${chatRoomId} from ${senderId}`);

        // Get the chat room document to find participants
        const chatRoomDoc = await admin.firestore()
            .collection('chat_rooms')
            .doc(chatRoomId)
            .get();

        if (!chatRoomDoc.exists) {
          console.log('⚠️ Chat room document does not exist');
          return null;
        }

        const chatRoomData = chatRoomDoc.data();
        const participants = chatRoomData.participants || [];

        // Find the receiver (the participant who is not the sender)
        const receiverId = participants.find((id) => id !== senderId);

        if (!receiverId) {
          console.log('⚠️ No receiver found for notification');
          return null;
        }

        // Get sender's name
        const senderDoc = await admin.firestore()
            .collection('Users')
            .doc(senderId)
            .get();

        const senderName = senderDoc.exists ?
            senderDoc.data().name || senderEmail : senderEmail;

        // Get receiver's FCM token
        const receiverDoc = await admin.firestore()
            .collection('Users')
            .doc(receiverId)
            .get();

        if (!receiverDoc.exists) {
          console.log(`⚠️ Receiver ${receiverId} document does not exist`);
          return null;
        }

        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) {
          console.log(`⚠️ Receiver ${receiverId} has no FCM token`);
          return null;
        }

        // Prepare notification message
        let notificationBody = message;
        if (messageType === 'image') {
          notificationBody = '📷 Sent an image';
        } else if (messageType === 'video') {
          notificationBody = '🎥 Sent a video';
        } else if (messageType === 'audio') {
          notificationBody = '🎤 Sent an audio message';
        }

        // Create notification payload
        const payload = {
          notification: {
            title: senderName,
            body: notificationBody,
          },
          data: {
            type: 'chat_message',
            chatRoomId: chatRoomId,
            senderId: senderId,
            senderName: senderName,
            messageType: messageType || 'text',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
          token: fcmToken,
        };

        // Send notification
        const response = await admin.messaging().send(payload);
        console.log(`✅ Notification sent successfully: ${response}`);

        // Store notification in receiver's notifications collection
        await admin.firestore()
            .collection('Users')
            .doc(receiverId)
            .collection('notifications')
            .add({
              title: senderName,
              body: notificationBody,
              data: {
                type: 'chat_message',
                chatRoomId: chatRoomId,
                senderId: senderId,
                senderName: senderName,
              },
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              read: false,
            });

        console.log(`✅ Notification document created for user ${receiverId}`);

        return response;
      } catch (error) {
        console.error('❌ Error sending chat notification:', error);
        return null;
      }
    });

/**
 * Cloud Function to send push notification when a new group message is created
 * Triggers on new document creation in groups/{groupId}/messages
 */
exports.sendGroupNotification = functions.firestore
    .document('groups/{groupId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
      try {
        const messageData = snap.data();
        const {senderId, senderEmail, message, type} = messageData;
        const groupId = context.params.groupId;

        console.log(`📨 New message in group ${groupId} from ${senderId}`);

        // Get the group document to find members and group name
        const groupDoc = await admin.firestore()
            .collection('groups')
            .doc(groupId)
            .get();

        if (!groupDoc.exists) {
          console.log('⚠️ Group document does not exist');
          return null;
        }

        const groupData = groupDoc.data();
        const members = groupData.members || [];
        const groupName = groupData.name || 'Group Chat';

        // Get sender's name
        const senderDoc = await admin.firestore()
            .collection('Users')
            .doc(senderId)
            .get();

        const senderName = senderDoc.exists ?
            senderDoc.data().name || senderEmail : senderEmail;

        // Prepare notification message
        let notificationBody = `${senderName}: ${message}`;
        if (type === 'image') {
          notificationBody = `${senderName} sent an image`;
        } else if (type === 'video') {
          notificationBody = `${senderName} sent a video`;
        } else if (type === 'audio') {
          notificationBody = `${senderName} sent an audio message`;
        }

        // Get FCM tokens for all members except the sender
        const memberTokens = [];
        const notificationPromises = [];

        for (const memberId of members) {
          if (memberId === senderId) continue; // Skip sender

          const memberDoc = await admin.firestore()
              .collection('Users')
              .doc(memberId)
              .get();

          if (!memberDoc.exists) continue;

          const memberData = memberDoc.data();
          const fcmToken = memberData.fcmToken;

          if (fcmToken) {
            memberTokens.push({
              token: fcmToken,
              userId: memberId,
            });
          }
        }

        if (memberTokens.length === 0) {
          console.log('⚠️ No members with FCM tokens to notify');
          return null;
        }

        // Send notifications to all members
        for (const {token, userId} of memberTokens) {
          const payload = {
            notification: {
              title: groupName,
              body: notificationBody,
            },
            data: {
              type: 'group_message',
              groupId: groupId,
              groupName: groupName,
              senderId: senderId,
              senderName: senderName,
              messageType: type || 'text',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            token: token,
          };

          // Send notification
          const notificationPromise = admin.messaging().send(payload)
              .then((response) => {
                console.log(
                    `✅ Notification sent to user ${userId}: ${response}`);
                return response;
              })
              .catch((error) => {
                console.error(
                    `❌ Failed to send notification to ${userId}:`,
                    error);
                return null;
              });

          notificationPromises.push(notificationPromise);

          // Store notification in user's notifications collection
          await admin.firestore()
              .collection('Users')
              .doc(userId)
              .collection('notifications')
              .add({
                title: groupName,
                body: notificationBody,
                data: {
                  type: 'group_message',
                  groupId: groupId,
                  groupName: groupName,
                  senderId: senderId,
                  senderName: senderName,
                },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
              });
        }

        // Wait for all notifications to be sent
        const results = await Promise.all(notificationPromises);
        console.log(`✅ Sent ${results.filter((r) => r !== null).length} ` +
            `notifications for group ${groupId}`);

        return results;
      } catch (error) {
        console.error('❌ Error sending group notification:', error);
        return null;
      }
    });
