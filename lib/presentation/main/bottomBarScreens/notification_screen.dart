import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<String> _readNotifications = {};

  Future<void> _refreshNotifications() async {
    setState(() {
      _readNotifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SettingsAppBar(title: 'Notifications'),
            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: _buildNotificationsList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off,
                  size: 50,
                  color: AppUtils.getColorScheme(context).onSurface.withAlpha(50),
                ),
                const SizedBox(height: 10),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    color: AppUtils.getColorScheme(context).onSurface.withAlpha(70),
                  ),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index].data() as Map<String, dynamic>;
            final timestamp = notification['timestamp'] as Timestamp?;
            final title = notification['title'] ?? 'Notification';
            final body = notification['body'] ?? '';
            final data = notification['data'] as Map<String, dynamic>?;
            final read = _readNotifications.contains(notifications[index].id) || (notification['read'] ?? false);
            final documentId = notifications[index].id;

            String formattedDate = 'Just now';
            if (timestamp != null) {
              final now = DateTime.now();
              final difference = now.difference(timestamp.toDate());
              
              if (difference.inDays > 0) {
                formattedDate = DateFormat('MMM d, y').format(timestamp.toDate());
              } else if (difference.inHours > 0) {
                formattedDate = '${difference.inHours}h ago';
              } else if (difference.inMinutes > 0) {
                formattedDate = '${difference.inMinutes}m ago';
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              color: read 
                  ? AppUtils.getColorScheme(context).surface 
                  : AppUtils.getColorScheme(context).secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: () async {
                  if (!read) {
                    setState(() {
                      _readNotifications.add(documentId);
                    });
                    
                    await _firestore
                        .collection('Users')
                        .doc(_auth.currentUser!.uid)
                        .collection('notifications')
                        .doc(documentId)
                        .update({'read': true});

                    // Handle notification tap based on type
                    if (data != null) {
                      debugPrint("🔗 Notification tapped with type: ${data['type']}");

                      switch (data['type']) {
                        case 'video_assigned':
                          if (context.mounted) {
                            debugPrint("📺 Navigating to assigned video: ${data['videoTitle']}");

                            // Check if it's a Vimeo video (private)
                            bool isVimeoVideo = data.containsKey('restCaregiver') ||
                                              (data['youtubeLink']?.toString().contains('vimeo.com') ?? false);

                            String routeName = isVimeoVideo ? AppRoutes.vimeoVideoScreen : AppRoutes.videoScreen;

                            Navigator.pushNamed(
                              context,
                              routeName,
                              arguments: {
                                'videoUrl': data['youtubeLink'] ?? data['videoUrl'],
                                'videoId': data['videoId'],
                                'videoTitle': data['videoTitle'],
                                'categoryName': data['categoryName'],
                                'subcategoryName': data['subcategoryName'],
                                'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
                                'adminName': 'Admin', // You might want to get actual admin name
                              },
                            );
                          }
                          break;

                        case 'exam_assigned':
                          if (context.mounted) {
                            debugPrint("📝 Navigating to assigned exam: ${data['examTitle']}");
                            Navigator.pushNamed(
                              context,
                              AppRoutes.examScreen,
                              arguments: {
                                'examId': data['examId'],
                                'examTitle': data['examTitle'],
                              },
                            );
                          }
                          break;

                        case 'night_shift_alert':
                          if (context.mounted) {
                            debugPrint("🌙 Night shift alert notification tapped");
                            // Could navigate to a specific night shift screen or just show the alert
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(data['body'] ?? 'Night shift alert'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          break;

                        case 'chat_message':
                          if (context.mounted) {
                            debugPrint("💬 Navigating to chat from: ${data['senderName']}");
                            Navigator.pushNamed(
                              context,
                              AppRoutes.chatScreen,
                              arguments: {
                                'receiverId': data['senderId'],
                                'receiverEmail': data['senderName'],
                              },
                            );
                          }
                          break;

                        case 'group_message':
                          if (context.mounted) {
                            debugPrint("👥 Navigating to group chat: ${data['groupName']}");
                            Navigator.pushNamed(
                              context,
                              AppRoutes.chatScreen,
                              arguments: {
                                'groupId': data['groupId'],
                                'groupName': data['groupName'],
                                'isGroup': true,
                              },
                            );
                          }
                          break;

                        default:
                          debugPrint("❓ Unknown notification type: ${data['type']}");
                          break;
                      }
                    } else {
                      debugPrint("ℹ️ Notification tapped but no data available for deep linking");
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _getNotificationIcon(data?['type']),
                                  color: read
                                      ? AppUtils.getColorScheme(context).onSurface.withAlpha(180)
                                      : AppUtils.getColorScheme(context).primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                                      color: read 
                                          ? AppUtils.getColorScheme(context).onSurface.withAlpha(180)
                                          : AppUtils.getColorScheme(context).onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (!read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppUtils.getColorScheme(context).primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppUtils.getColorScheme(context).onSurface.withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: TextStyle(
                          color: read 
                              ? AppUtils.getColorScheme(context).onSurface.withAlpha(180)
                              : AppUtils.getColorScheme(context).onSurface,
                        ),
                      ),
                      // if (data?['type'] == 'video_assigned') ...[
                      //   const SizedBox(height: 8),
                      //   Container(
                      //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      //     decoration: BoxDecoration(
                      //       color: AppUtils.getColorScheme(context).primary.withAlpha(25),
                      //       borderRadius: BorderRadius.circular(4),
                      //     ),
                      //     child: Text(
                      //       'Tap to view video',
                      //       style: TextStyle(
                      //         fontSize: 12,
                      //         color: AppUtils.getColorScheme(context).primary,
                      //       ),
                      //     ),
                      //   ),
                      // ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'video_assigned':
        return Icons.video_library;
      case 'exam_assigned':
        return Icons.quiz;
      case 'night_shift_alert':
        return Icons.nights_stay;
      case 'clocking_reminder':
        return Icons.access_time;
      case 'attendance_update':
        return Icons.check_circle_outline;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'group_message':
        return Icons.group;
      default:
        return Icons.notifications;
    }
  }
}
