// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> init() async {
    try {
      // Initialize local notifications with onSelectNotification handler
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔗 Local notification tapped: ${response.payload}');
          // Handle local notification tap
          _handleNotificationTap(response.payload);
        },
      );
      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  // Handle notification tap navigation
  static void _handleNotificationTap(String? payload) {
    // This would typically involve a navigation service
    // For now, we'll just log it - you might want to implement a navigation service
    debugPrint('🔗 Handling notification tap with payload: $payload');

    // You could parse the payload and navigate to the appropriate screen
    // This would require access to the Navigator context or a navigation service
  }

  // Initialize FCM
  Future<void> initializeFCM() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
        
        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          // Save token to Firestore
          await _saveTokenToFirestore(token);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
        
        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showLocalNotification(message);
        });
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('Users').doc(userId).update({
          'fcmToken': token,
        });
        debugPrint('FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Send notification to specific users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get FCM tokens for the specified users
      List<String> tokens = [];
      for (String userId in userIds) {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String? token = userData['fcmToken'];
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }

      // Store notification in Firestore for each user
      for (String userId in userIds) {
        await _firestore.collection('Users').doc(userId).collection('notifications').add({
          'title': title,
          'body': body,
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        // Update badge count for this user
        await _updateBadgeCountForUser(userId);
      }

      // If you want to send actual push notifications, you would need a server-side component
      // This is because FCM requires a server to send notifications
      // For now, we're just storing the notification in Firestore

      debugPrint('Notifications stored for ${userIds.length} users');
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  // Update badge count for a specific user
  Future<void> _updateBadgeCountForUser(String userId) async {
    try {
      // Only update badge if this is the current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        final unreadSnapshot = await _firestore
            .collection('Users')
            .doc(userId)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();

        final unreadCount = unreadSnapshot.docs.length;

        if (unreadCount > 0) {
          FlutterAppBadger.updateBadgeCount(unreadCount);
        } else {
          FlutterAppBadger.removeBadge();
        }
        debugPrint('Badge count updated: $unreadCount');
      }
    } catch (e) {
      debugPrint('Error updating badge count: $e');
    }
  }

  // Show local notification when app is in foreground
  void _showLocalNotification(RemoteMessage message) {
    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null) {
        // Create payload with notification data for deep linking
        String payload = '';
        if (message.data.isNotEmpty) {
          // Convert data to a simple string format for payload
          payload = message.data.entries
              .map((e) => '${e.key}:${e.value}')
              .join('|');
        }

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: payload,
        );
        debugPrint('Local notification shown: ${notification.title}');
      }
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
}

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}