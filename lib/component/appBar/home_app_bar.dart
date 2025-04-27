import 'package:flutter/material.dart';
import 'package:healthcare/utils/appRoutes/app_routes.dart';
import '../../utils/app_utils/AppUtils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeAppBar extends StatelessWidget {
  final String name;
  const HomeAppBar({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      floating: true,
      expandedHeight: 100,
      backgroundColor: AppUtils.getColorScheme(context).surface,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final bool isExpanded = constraints.maxHeight > kToolbarHeight;

          return FlexibleSpaceBar(
            centerTitle: true,
            expandedTitleScale: 1.2,
            titlePadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Padding(
              padding: EdgeInsets.only(bottom: isExpanded ? 18.0 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.45,
                          child: Text(
                              'Hi, $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)
                          )
                      ),
                      Text('Your care makes all the difference...',style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]))
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      // Mark all notifications as read before navigating
                      final notificationsRef = FirebaseFirestore.instance
                          .collection('Users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('notifications');
                      
                      final unreadNotifications = await notificationsRef
                          .where('read', isEqualTo: false)
                          .get();
                      
                      for (var doc in unreadNotifications.docs) {
                        await notificationsRef.doc(doc.id).update({'read': true});
                      }
                      
                      if (context.mounted) {
                        Navigator.pushNamed(context, AppRoutes.notificationScreen);
                      }
                    },
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('notifications')
                          .where('read', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('Error in notification stream: ${snapshot.error}');
                          return const SizedBox.shrink();
                        }

                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final unreadCount = snapshot.data!.docs.length;
                        debugPrint('Unread notifications count: $unreadCount');
                        
                        return Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppUtils.getColorScheme(context).primaryFixed.withAlpha(110),
                                  borderRadius: BorderRadius.circular(100)
                              ),
                              child: Icon(
                                Icons.notifications,
                                color: AppUtils.getColorScheme(context).onSurface,
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}