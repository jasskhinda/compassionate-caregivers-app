import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../utils/app_utils/AppUtils.dart';
import '../../services/chat_services.dart';

class BottomBar extends StatefulWidget {
  final void Function(int)? onTabChange;
  final int selectedIndex;
  const BottomBar({super.key, this.onTabChange, required this.selectedIndex});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {

  late int _currentIndex;
  bool _isAdmin = false;
  bool _isStaff = false;
  final ChatServices _chatServices = ChatServices();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _checkUserRole();
  }

  // Check user role
  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final role = userData['role'] ?? '';

          setState(() {
            _isAdmin = role == 'Admin';
            _isStaff = role == 'Staff';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
  }

  Stream<int> _getTotalUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    // Combine group chats and individual chats unread counts
    final groupUnreadStream = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final fieldName = 'unreadCount_${currentUser.uid}';
        if (data?.containsKey(fieldName) == true) {
          totalUnread += (data![fieldName] as int? ?? 0);
        }
      }
      return totalUnread;
    });

    final individualUnreadStream = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final fieldName = 'unreadCount_${currentUser.uid}';
        if (data?.containsKey(fieldName) == true) {
          totalUnread += (data![fieldName] as int? ?? 0);
        }
      }
      return totalUnread;
    });

    // Combine both streams
    return groupUnreadStream.asyncExpand((groupCount) {
      return individualUnreadStream.map((individualCount) => groupCount + individualCount);
    });
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.white,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppUtils.getColorScheme(context).surface
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
            child: Stack(
              children: [
                GNav(
                    onTabChange: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(index);
                      }
                    },
                    selectedIndex: _currentIndex,
                    color: AppUtils.getColorScheme(context).onSurface.withAlpha(80),
                    activeColor: AppUtils.getColorScheme(context).onSurface,
                    tabBackgroundColor: AppUtils.getColorScheme(context).secondary,
                    padding: const EdgeInsets.all(12.0),
                    gap: 8,
                    textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppUtils.getColorScheme(context).onSurface),
                    tabs: [
                      GButton(
                          icon: _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                          text: 'Home'
                      ),
                      GButton(
                          icon: _currentIndex == 1 ? Icons.message_rounded : Icons.message_outlined,
                          text: 'Chat'
                      ),
                      GButton(
                          icon: _currentIndex == 2 ? Icons.video_library : Icons.video_library_outlined,
                          text: 'Library'
                      ),
                      GButton(
                          icon: _currentIndex == 3 ? Icons.person : Icons.person_outline,
                          text: 'Profile'
                      ),

                      // User Management tab for Admin/Staff only
                      if (_isAdmin || _isStaff)
                        GButton(
                            icon: _currentIndex == 4 ? Icons.home : Icons.home_outlined,
                            text: 'Manage'
                        ),
                    ]
                ),
                // Red dot indicator for chat tab
                StreamBuilder<int>(
                  stream: _getTotalUnreadCount(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount == 0) return const SizedBox.shrink();

                    // Calculate position for chat tab (second tab, index 1)
                    final screenWidth = MediaQuery.of(context).size.width;
                    final tabWidth = (screenWidth - 30) / (_isAdmin || _isStaff ? 5 : 4);
                    final chatTabPosition = tabWidth * 1.5; // Position for second tab

                    return Positioned(
                      left: chatTabPosition + 15,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}