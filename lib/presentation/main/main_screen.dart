import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/recent_chat_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/library_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/profile_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/clock_manager_screen.dart';
import 'package:caregiver/presentation/main/manageUser/manage_user_screen.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import '../../component/bottomBar/bottom_bar.dart';
import '../../component/bottomBar/nav_drawer.dart';
import '../../services/night_shift_monitoring_service.dart';
import '../../services/clock_management_service.dart';
import 'bottomBarScreens/home_screen.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  // Manage the selected index for both BottomBar and NavDrawer
  int _selectedIndex = 0;
  final NightShiftMonitoringService _nightShiftService = NightShiftMonitoringService();
  final ClockManagementService _clockService = ClockManagementService();
  String? _userRole;
  bool _isAdmin = false;
  bool _isStaff = false;
  bool _isCaregiver = false;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Update the selected index
  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Screen List - will be dynamically built based on user role
  List<Widget> get _pages {
    List<Widget> pages = [
      const HomeScreen(),
      const RecentChatScreen(),
      const LibraryScreen(),
      const ProfileScreen(),
    ];

    // Add User Management for Admin/Staff only
    if (_isAdmin || _isStaff) {
      pages.add(const ManageUserScreen());
    }

    // Add Clock Manager for Caregivers only
    if (_isCaregiver) {
      pages.add(const ClockManagerScreen());
    }

    return pages;
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
            _userRole = role;
            _isAdmin = role == 'Admin';
            _isStaff = role == 'Staff';
            _isCaregiver = role == 'Caregiver';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
  }

  // Update badge count based on unread notifications
  Future<void> _updateBadgeCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final unreadSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
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

  // Setup real-time listener for notification changes
  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            _updateBadgeCount();
          });
      debugPrint('Notification listener setup for badge updates');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _updateBadgeCount(); // Update badge on app launch
    _setupNotificationListener(); // Listen for new notifications
    // Note: Auto clock-in removed - will be handled via Wellsky API integration
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Start night shift monitoring if applicable (only if user is already clocked in)
      _nightShiftService.startMonitoring(context);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    // Don't stop monitoring on dispose - let it continue in background
    // Only stop when user logs out
    // _nightShiftService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: screenWidth < 1000
            ? MainMobileUI(onTabChange: _updateSelectedIndex, pages: _pages, selectedIndex: _selectedIndex)
            : MainDesktopUI(onTabChange: _updateSelectedIndex, pages: _pages, selectedIndex: _selectedIndex)
    );
  }
}

class MainDesktopUI extends StatelessWidget {
  final void Function(int) onTabChange;
  final List<Widget> pages;
  final int selectedIndex;
  const MainDesktopUI({
    super.key,
    required this.onTabChange,
    required this.pages,
    required this.selectedIndex
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Drawer
        NavDrawer(onTabChange: (index)  => onTabChange(index), pages: pages, selectedIndex: selectedIndex,),

        // Rest UI
        Expanded(
            child: IndexedStack(
                index: selectedIndex,
                children: pages
            )
        )
      ],
    );
  }
}


class MainMobileUI extends StatelessWidget {
  final void Function(int) onTabChange;
  final List<Widget> pages;
  final int selectedIndex;
  const MainMobileUI({
    super.key,
    required this.onTabChange,
    required this.pages,
    required this.selectedIndex
  });

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        IndexedStack(
            index: selectedIndex,
            children: pages
        ),
        Align(
            alignment: Alignment.bottomCenter,
            child: BottomBar(
                onTabChange: (index) => onTabChange(index),
                selectedIndex: selectedIndex
            )
        )
      ],
    );
  }
}