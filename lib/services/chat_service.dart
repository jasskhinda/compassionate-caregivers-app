import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Message>> getMessages(String receiverId) {
    final currentUserId = _auth.currentUser?.uid;
    final chatId = _getChatId(currentUserId!, receiverId);

    return _firestore
        .collection('chat_rooms')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList();
    });
  }

  Future<String?> _uploadMedia({String? mediaPath, Uint8List? mediaBytes, String? fileName}) async {
    try {
      if (mediaPath == null && (mediaBytes == null || fileName == null)) {
        return null;
      }

      final currentUserId = _auth.currentUser?.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'chat_media/$currentUserId/$timestamp${fileName ?? '_media'}';
      final storageRef = _storage.ref().child(storagePath);

      UploadTask uploadTask;
      if (kIsWeb && mediaBytes != null) {
        uploadTask = storageRef.putData(mediaBytes);
      } else if (mediaPath != null) {
        final file = File(mediaPath);
        uploadTask = storageRef.putFile(file);
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  Future<void> sendMessage({
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? mediaPath,
    Uint8List? mediaBytes,
    String? fileName,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      final currentUserEmail = _auth.currentUser?.email;
      final chatId = _getChatId(currentUserId!, receiverId);
      final timestamp = DateTime.now();

      String? mediaUrl;
      if (messageType == 'media') {
        mediaUrl = await _uploadMedia(
          mediaPath: mediaPath,
          mediaBytes: mediaBytes,
          fileName: fileName,
        );
      }

      final newMessage = Message(
        id: timestamp.millisecondsSinceEpoch.toString(),
        senderId: currentUserId,
        senderEmail: currentUserEmail ?? '',
        receiverId: receiverId,
        content: message,
        timestamp: timestamp,
        messageType: messageType,
        mediaPath: mediaPath,
        mediaUrl: mediaUrl,
      );

      await _firestore
          .collection('chat_rooms')
          .doc(chatId)
          .collection('messages')
          .add(newMessage.toMap());
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  String _getChatId(String currentUserId, String receiverId) {
    return currentUserId.hashCode <= receiverId.hashCode
        ? '$currentUserId-$receiverId'
        : '$receiverId-$currentUserId';
  }
} 