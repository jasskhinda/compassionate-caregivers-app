import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caregiver/models/message.dart';
import 'package:uuid/uuid.dart';

class ChatServices {

  // Get instance of firestore & auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = Uuid();

  // Get user stream
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Go through each individual user
        final user = doc.data();
        // Return user
        return user;
      }).toList();
    });
  }

  // Refresh user stream
  Future<void> refreshUserStream() async {
    // Force a refresh by getting a new snapshot
    await _firestore.collection("Users").get();
  }

  // Refresh group stream
  Future<void> refreshGroupStream() async {
    // Force a refresh by getting a new snapshot
    await _firestore.collection("groups").get();
  }

  // Create a new group chat
  Future<String> createGroupChat({
    required String groupName,
    required List<String> memberIds,
    required String createdBy,
  }) async {
    try {
      // Get current user's role
      DocumentSnapshot currentUserDoc = await _firestore.collection('Users').doc(createdBy).get();
      String currentUserRole = currentUserDoc.get('role') ?? '';

      // Add all admins to the group
      QuerySnapshot adminSnapshot = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Admin')
          .get();

      List<String> allMemberIds = [...memberIds];
      for (var doc in adminSnapshot.docs) {
        String adminId = doc.id;
        if (!allMemberIds.contains(adminId)) {
          allMemberIds.add(adminId);
        }
      }

      // Create group document
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'members': allMemberIds,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      return groupRef.id;
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  // Send message to group
  Future<void> sendGroupMessage(String groupId, String message, {String? messageType}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final messageData = {
        'senderId': currentUser.uid,
        'senderEmail': currentUser.email,
        'message': message,
        'type': messageType ?? 'text',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      print('Error sending group message: $e');
      rethrow;
    }
  }

  // Get group messages
  Stream<List<Message>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Message.fromMap(data);
          }).toList();
        });
  }

  // Get user's groups
  Stream<QuerySnapshot> getUserGroups() {
    String userId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Send message
  Future<void> sendMessage(String receiverId, String message, {String? messageType}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final messageData = {
        'senderId': currentUser.uid,
        'senderEmail': currentUser.email,
        'message': message,
        'type': messageType ?? 'text',
        'timestamp': FieldValue.serverTimestamp(),
      };

      String chatRoomId = _getChatId(currentUser.uid, receiverId);
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages
  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    // Create a chat room ID from user IDs (sorted to ensure consistency)
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data());
      }).toList();
    });
  }

  // Add members to group
  Future<void> addMembersToGroup(String groupId, List<String> newMemberIds) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion(newMemberIds),
      });
    } catch (e) {
      print('Error adding members to group: $e');
      rethrow;
    }
  }

  // Remove members from group
  Future<void> removeMembersFromGroup(String groupId, List<String> memberIds) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove(memberIds),
      });
    } catch (e) {
      print('Error removing members from group: $e');
      rethrow;
    }
  }

  // Delete group
  Future<void> deleteGroup(String groupId) async {
    try {
      // Delete all messages in the group
      final messages = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .get();
      
      for (var message in messages.docs) {
        // Delete any media associated with the message
        if (message.data()['mediaUrl'] != null) {
          await _storage.refFromURL(message.data()['mediaUrl']).delete();
        }
        await message.reference.delete();
      }

      // Delete the group document
      await _firestore.collection('groups').doc(groupId).delete();
    } catch (e) {
      print('Error deleting group: $e');
      rethrow;
    }
  }

  String _getChatId(String userId1, String userId2) {
    // Sort IDs to ensure consistent chat room ID
    final sortedIds = [userId1, userId2]..sort();
    return sortedIds.join('_');
  }

  // Send media message
  Future<void> sendMediaMessage(String receiverId, String type, {required String mediaUrl, bool isGroup = false}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final message = {
        'senderId': currentUser.uid,
        'senderEmail': currentUser.email,
        'receiverId': receiverId,
        'message': mediaUrl,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (isGroup) {
        await _firestore
            .collection('groups')
            .doc(receiverId)
            .collection('messages')
            .add(message);
          
        // Update group's last message
        await _firestore.collection('groups').doc(receiverId).update({
          'lastMessage': type == 'image' ? '📷 Image' : '🎥 Video',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      } else {
        String chatRoomId = _getChatId(currentUser.uid, receiverId);
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .add(message);
      }
    } catch (e) {
      print('Error sending media message: $e');
      rethrow;
    }
  }

  // Send audio message
  Future<void> sendAudioMessage(String receiverID, File audioFile) async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      final String currentUserEmail = _auth.currentUser!.email!;
      final DateTime timestamp = DateTime.now();

      // Upload audio file to Firebase Storage
      String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      String mediaPath = 'chat_media/$currentUserID/audio/$fileName';
      
      final ref = _storage.ref().child(mediaPath);
      await ref.putFile(audioFile);
      String mediaUrl = await ref.getDownloadURL();

      Message newMessage = Message(
        id: _uuid.v4(),
        senderId: currentUserID,
        senderEmail: currentUserEmail,
        receiverId: receiverID,
        content: 'Audio Message',
        timestamp: timestamp,
        messageType: 'audio',
        mediaUrl: mediaUrl,
        mediaPath: mediaPath,
        isGroupMessage: false,
      );

      List<String> ids = [currentUserID, receiverID];
      ids.sort();
      String chatRoomID = ids.join('_');

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomID)
          .collection('messages')
          .add(newMessage.toMap());
    } catch (e) {
      print('Error sending audio message: $e');
      rethrow;
    }
  }

  // Get group members
  Stream<DocumentSnapshot> getGroupInfo(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  Future<void> sendGroupMediaMessage(String groupId, File file, String messageType) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Upload file to Firebase Storage
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'media_$timestamp.${file.path.split('.').last}';
      String mediaPath = 'chat_media/groups/$groupId/$fileName';
      
      final ref = _storage.ref().child(mediaPath);
      await ref.putFile(file);
      String mediaUrl = await ref.getDownloadURL();

      final messageData = {
        'senderId': currentUser.uid,
        'senderEmail': currentUser.email,
        'message': mediaUrl,
        'type': messageType,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add message to group
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      // Update group's last message info
      await _firestore.collection('groups').doc(groupId).update({
        'lastMessage': messageType == 'image' ? '📷 Image' : '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending group media message: $e');
      rethrow;
    }
  }

  // Reset unread count for individual chat
  Future<void> resetUnreadCount(String chatRoomId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount_$currentUserId': 0,
    });
  }

  // Reset unread count for group chat
  Future<void> resetGroupUnreadCount(String groupId) async {
    final String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('groups').doc(groupId).update({
      'unreadCount_$currentUserId': 0,
    });
  }
}