import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:caregiver/component/appBar/home_app_bar.dart';
import 'package:caregiver/component/home/initial_option_layout.dart';
import 'package:caregiver/component/listLayout/assigned_video_layout.dart';
import 'package:caregiver/component/other/not_found_dialog.dart';
import 'package:caregiver/presentation/main/manageUser/caregiver_list.dart';
import 'package:caregiver/services/user_video_services.dart';
import 'package:caregiver/services/firebase_service.dart';
import 'package:caregiver/services/user_services.dart';
import 'package:caregiver/services/night_shift_monitoring_service.dart';
import 'package:caregiver/services/clock_management_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';

import '../../../component/home/user_count_layout.dart';
import '../../../utils/appRoutes/app_routes.dart';

// Global notifier for clock manager refresh
class ClockManagerRefreshNotifier extends ChangeNotifier {
  static final ClockManagerRefreshNotifier _instance = ClockManagerRefreshNotifier._internal();
  factory ClockManagerRefreshNotifier() => _instance;
  ClockManagerRefreshNotifier._internal();

  static ClockManagerRefreshNotifier get instance => _instance;

  void notifyRefresh() {
    notifyListeners();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User video services instance
  final UserVideoServices _userVideoServices = UserVideoServices();

  // User services instance
  final UserServices _userServices = UserServices();

  // Night shift monitoring service
  final NightShiftMonitoringService _nightShiftService = NightShiftMonitoringService();

  // Clock management service
  final ClockManagementService _clockService = ClockManagementService();

  // User count
  int? _staff;
  int? _caregiver;
  bool _isLoading = true;

  // User info
  String? _role;
  String? _username;
  int? _assignedVideo;
  int? _completedVideo;
  bool _isClockedIn = false;
  String? _shiftType;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Get all user count
  Future<void> _getUserCount() async {
    try {
      final data = await FirebaseService.retryOperation(
        () => FirebaseService.getUsersCount(),
      );

      if (data != null) {
        setState(() {
          _staff = data['nurse'] ?? 0;
          _caregiver = data['caregiver'] ?? 0;
          _isLoading = false;
        });
        debugPrint('User count loaded: staff=$_staff, caregiver=$_caregiver');
      } else {
        setState(() {
          _staff = 0;
          _caregiver = 0;
          _isLoading = false;
        });
        debugPrint('Failed to load user count, using default values');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staff = 0;
        _caregiver = 0;
        _isLoading = false;
      });
      debugPrint("Error fetching user count: $e");
    }
  }


  // Clock in/out functionality
  Future<void> _clockIn() async {
    try {
      final success = await _clockService.clockIn(_username ?? 'User');
      if (success) {
        // Notify clock manager to refresh recent activity
        _notifyClockManagerRefresh();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully clocked in!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clock in. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clocking in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clockOut() async {
    try {
      final success = await _clockService.clockOut(_username ?? 'User');
      if (success) {
        // Notify clock manager to refresh recent activity
        _notifyClockManagerRefresh();

        // Stop night shift monitoring
        if (_shiftType == 'Night') {
          _nightShiftService.stopMonitoring();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully clocked out!'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clock out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clocking out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Notify clock manager to refresh recent activity
  void _notifyClockManagerRefresh() {
    // Post a message to trigger refresh in clock manager
    // This will be picked up by any listening clock manager screens
    Future.delayed(Duration(milliseconds: 100), () {
      // Broadcast to all screens that might be interested
      // Using a simple approach with a global event
      ClockManagerRefreshNotifier.instance.notifyRefresh();
    });
  }

  @override
  void initState() {
    super.initState();
    _setupRealTimeUserListener();
    _initializeAndSyncData();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeUserListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _userDataSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data() as Map<String, dynamic>?;
        if (userData != null) {
          setState(() {
            _role = userData['role'] ?? 'Caregiver';
            _username = userData['name'] ?? 'User';
            _assignedVideo = userData['assigned_video'] ?? 0;
            _completedVideo = userData['completed_video'] ?? 0;
            _isClockedIn = userData['is_clocked_in'] ?? false;
            _shiftType = userData['shift_type'];
            _isLoading = false;
          });
          debugPrint('Real-time user info updated: role=$_role, username=$_username, isClockedIn=$_isClockedIn');
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to user data: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _initializeAndSyncData() async {
    // Real-time listener handles user info, just wait a moment for initial data
    await Future.delayed(Duration(milliseconds: 500));

    // If user is an admin, sync user counts to fix discrepancies
    if (_role == 'Admin') {
      try {
        await _userServices.syncUserCounts();
        debugPrint('✅ Admin login detected - user counts synced');
      } catch (e) {
        debugPrint('❌ Failed to sync user counts: $e');
      }
    }

    // Then get the updated user count
    await _getUserCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _isLoading = true;
            });
            try {
              // Real-time listener handles user info, just refresh user count
              await _getUserCount();
            } finally {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // App Bar
              HomeAppBar(name: _username ?? ''),

              SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    width: AppUtils.getScreenSize(context).width >= 600
                        ? AppUtils.getScreenSize(context).width * 0.50
                        : double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only For admins
                          if (_role == 'Admin')
                            InitialOptionLayout(
                              title: 'Assigned Staff',
                              optionOneTitle: 'Staff',
                              optionOneIcon: Icons.health_and_safety,
                              optionTwoTitle: 'Caregiver',
                              optionTwoIcon: Icons.person,
                              optionOneCount: _staff.toString(),
                              optionTwoCount: _caregiver.toString(),
                              optionOneOnTap: () => Navigator.pushNamed(context, AppRoutes.allStaffUserScreen),
                              optionTwoOnTap: () => Navigator.pushNamed(context, AppRoutes.allCaregiverUserScreen),
                            ),

                            // Only for Caregiver
                            if (_role == 'Caregiver')
                              InitialOptionLayout(
                                  title: 'Learning Status',
                                  optionOneTitle: 'Videos Assigned',
                                  optionOneIcon: Icons.video_library,
                                  optionTwoTitle: 'Videos Watched',
                                  optionTwoIcon: Icons.slow_motion_video_rounded,
                                  optionOneCount: _assignedVideo != null ? _assignedVideo.toString() : '0',
                                  optionTwoCount: _completedVideo != null ? _completedVideo.toString() : '0'
                              ),

                            // Clock-in/Clock-out for Night Shift Caregivers
                            if (_role == 'Caregiver' && _shiftType == 'Night')
                              Column(
                                children: [
                                  const SizedBox(height: 20),
                                  _buildClockInOutSection(),
                                ],
                              ),

                          if (_role == 'Admin')
                            const SizedBox(height: 15),

                          // Only for Staff & Admin
                          if (_role != 'Caregiver')
                            Text(
                                'Manage content',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppUtils.getColorScheme(context).onSurface
                                )
                            ),
                          const SizedBox(height: 4),
                          if (_role == 'Admin')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: MaterialButton(
                                      height: 84,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15)
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(context, AppRoutes.createUserScreen);
                                      },
                                      color: AppUtils.getColorScheme(context).tertiaryContainer,
                                      child: const Text(
                                        'Add Users',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white
                                        ),
                                      ),
                                    )
                                ),
                              ],
                            ),

                          // Staff management capabilities
                          if (_role == 'Staff')
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: MaterialButton(
                                        height: 84,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15)
                                        ),
                                        onPressed: () {
                                          Navigator.pushNamed(context, AppRoutes.createCategoryScreen);
                                        },
                                        color: AppUtils.getColorScheme(context).tertiaryContainer,
                                        child: const Text(
                                          'Create Categories',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white
                                          ),
                                        ),
                                      )
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: MaterialButton(
                                        height: 84,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15)
                                        ),
                                        onPressed: () {
                                          Navigator.pushNamed(context, AppRoutes.libraryScreen);
                                        },
                                        color: AppUtils.getColorScheme(context).tertiaryContainer,
                                        child: const Text(
                                          'Library',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white
                                          ),
                                        ),
                                      )
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                UserCountLayout(
                                  title: 'Caregiver',
                                  count: _caregiver.toString(),
                                  icon: Icons.person
                                ),
                              ],
                            ),

                          const SizedBox(height: 15),

                          // Exam Management - Admin has full access, Staff can only assign
                          Text(
                              _role == 'Admin' ? 'Exam Management' : _role == 'Staff' ? 'Assign Exams' : 'Assigned Exams',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppUtils.getColorScheme(context).onSurface
                              )
                          ),
                          const SizedBox(height: 4),

                          // Admin: Full exam management (create & manage)
                          if (_role == 'Admin')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: MaterialButton(
                                      height: 84,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15)
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(context, AppRoutes.createExamScreen);
                                      },
                                      color: AppUtils.getColorScheme(context).tertiaryContainer,
                                      child: const Text(
                                        'Create New Exams',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white
                                        ),
                                      ),
                                    )
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                    child: MaterialButton(
                                      height: 84,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15)
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(context, AppRoutes.manageExamScreen);
                                      },
                                      color: AppUtils.getColorScheme(context).tertiaryContainer,
                                      child: const Text(
                                        'Manage Exam',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white
                                        ),
                                      ),
                                    )
                                ),
                              ],
                            ),

                          // Staff: Can only assign existing exams
                          if (_role == 'Staff')
                            SizedBox(
                              width: double.infinity,
                              child: MaterialButton(
                                height: 84,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.manageExamScreen);
                                },
                                color: AppUtils.getColorScheme(context).tertiaryContainer,
                                child: const Text(
                                  'Assign Exams to Caregivers',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white
                                  ),
                                ),
                              ),
                            ),

                          if (_role == 'Caregiver')
                            SizedBox(
                              width: double.infinity,
                              child: MaterialButton(
                                height: 84,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.takeExamScreen);
                                },
                                color: AppUtils.getColorScheme(context).tertiaryContainer,
                                child: const Text(
                                  'View & Start Exam',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 18),

                          Text(
                            _role == 'Caregiver' ? 'Assigned videos' : 'Manage learning content',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSurface
                            )
                          ),

                          // Show caregivers if its not caregiver
                          if (_role != 'Caregiver')
                            const CaregiverList(),

                          // Only for Caregiver
                          if (_role == 'Caregiver')
                            _assignedVideos(),

                          const SizedBox(height: 120)
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ]
          ),
        ),
      )
    );
  }

  Widget _assignedVideos() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _userVideoServices.getAssignedVideosForCaregiver(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: NotFoundDialog(title: 'No Video Assigned Yet', description: 'A video will appear here once it has been assigned to you.')
          );
        }

        final videos = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final videoId = video['videoId'] ?? '';
            final videoTitle = video['title'] ?? '';
            final videoUrl = video['youtubeLink'] ?? '';
            final progress = (video['progress'] as num?)?.toDouble() ?? 0.0;
            final assignedByUid = video['assignedBy'] ?? '';
            final assignedDate = video['assignedDate'] as Timestamp?;
            String date = assignedDate != null ? DateFormat('dd MMM yyyy').format(assignedDate.toDate()) : '';

            // Get admin name
            return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('Users').doc(
                    assignedByUid).get(),
                builder: (context, snapshot) {
                  String adminName = 'Loading...';
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data!.data() != null) {
                    final data = snapshot.data!.data() as Map<String,
                        dynamic>;
                    adminName = data['name'] ?? 'User no longer exists';
                  }
                  return AssignedVideoLayout(
                    videoTitle: videoTitle,
                    adminName: adminName,
                    progress: progress,
                    date: date,
                    onTap: () {
                      Navigator.pushNamed(
                          context,
                          video.containsKey('restCaregiver') ? AppRoutes.vimeoVideoScreen : AppRoutes.videoScreen,
                          arguments: {
                            'videoId': videoId,
                            'date': date,
                            'adminName': adminName,
                            'videoTitle': videoTitle,
                            'videoUrl': videoUrl
                          }
                      );
                    },
                  );
                }
            );
          },
        );
      },
    );

  }

  Widget _buildClockInOutSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isClockedIn
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isClockedIn
              ? Colors.green.shade300
              : Colors.blue.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isClockedIn ? Colors.green : Colors.blue).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isClockedIn
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isClockedIn ? Icons.work : Icons.work_outline,
                  color: _isClockedIn
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Night Shift Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppUtils.getColorScheme(context).onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isClockedIn ? 'Currently clocked in' : 'Not clocked in',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isClockedIn
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isClockedIn ? _clockOut : _clockIn,
              icon: Icon(
                _isClockedIn ? Icons.logout : Icons.login,
                color: Colors.white,
              ),
              label: Text(
                _isClockedIn ? 'Clock Out' : 'Clock In',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClockedIn
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}