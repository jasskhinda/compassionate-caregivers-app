import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String messageType;
  final String? mediaUrl;
  final String? mediaPath;
  final bool isGroupMessage;

  Message({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.messageType,
    this.mediaUrl,
    this.mediaPath,
    this.isGroupMessage = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'mediaPath': mediaPath,
      'isGroupMessage': isGroupMessage,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    final timestamp = map['timestamp'];
    return Message(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? map['message'] ?? '',
      timestamp: timestamp is Timestamp 
          ? timestamp.toDate() 
          : (timestamp is DateTime ? timestamp : DateTime.now()),
      messageType: map['messageType'] ?? map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      mediaPath: map['mediaPath'],
      isGroupMessage: map['isGroupMessage'] ?? false,
    );
  }
}