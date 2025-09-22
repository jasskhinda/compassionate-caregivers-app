import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:caregiver/component/appBar/home_app_bar.dart';
import 'package:caregiver/component/home/initial_option_layout.dart';
import 'package:caregiver/component/listLayout/assigned_video_layout.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/component/other/not_found_dialog.dart';
import 'package:caregiver/presentation/main/manageUser/caregiver_list.dart';
import 'package:caregiver/services/user_video_services.dart';
import 'package:caregiver/services/firebase_service.dart';
import 'package:caregiver/services/user_services.dart';
import 'package:caregiver/services/night_shift_monitoring_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';

import '../../../component/home/user_count_layout.dart';
import '../../../utils/appRoutes/app_routes.dart';

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

  // Get user video details
  Future<void> _getUserInfo() async {
    try {
      if (!FirebaseService.isUserAuthenticated()) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final document = await FirebaseService.retryOperation(
        () => FirebaseService.getUserDocument(_auth.currentUser!.uid),
      );

      if (document != null && document.exists) {
        final rawData = document.data();
        if (rawData != null) {
          var data = rawData as Map<String, dynamic>;
          setState(() {
            _role = data['role'] ?? 'Caregiver';
            _username = data['name'] ?? 'User';
            _assignedVideo = data['assigned_video'] ?? 0;
            _completedVideo = data['completed_video'] ?? 0;
            _isClockedIn = data['is_clocked_in'] ?? false;
            _shiftType = data['shift_type'];
            _isLoading = false;
          });
          debugPrint('User info loaded: role=$_role, username=$_username');
        } else {
          setState(() {
            _role = 'Caregiver';
            _username = 'User';
            _assignedVideo = 0;
            _completedVideo = 0;
            _isLoading = false;
          });
          debugPrint("User document data is null, using default values");
        }
      } else {
        setState(() {
          _role = 'Caregiver';
          _username = 'User';
          _assignedVideo = 0;
          _completedVideo = 0;
          _isLoading = false;
        });
        debugPrint("User document not found, using default values");
      }
    } catch (e) {
      if(!mounted) return;
      setState(() {
        _role = 'Caregiver';
        _username = 'User';
        _assignedVideo = 0;
        _completedVideo = 0;
        _isLoading = false;
      });
      debugPrint("Error fetching user info: $e");
    }
  }

  // Clock in/out functionality
  Future<void> _clockIn() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({
            'is_clocked_in': true,
            'last_clock_in_time': FieldValue.serverTimestamp(),
            'manual_clock_in': true,
          }, SetOptions(merge: true));

      // Create attendance record
      await FirebaseFirestore.instance
          .collection('attendance')
          .add({
            'user_id': user.uid,
            'user_name': _username,
            'clock_in_time': FieldValue.serverTimestamp(),
            'type': 'manual_clock_in',
            'date': DateTime.now().toIso8601String().split('T')[0],
          });

      // Create admin notification
      await FirebaseFirestore.instance
          .collection('admin_alerts')
          .add({
            'type': 'night_shift_clock_in',
            'caregiver_id': user.uid,
            'caregiver_name': _username,
            'message': '$_username manually clocked in from dashboard',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'status': 'clocked_in',
            'clock_in_time': FieldValue.serverTimestamp(),
            'clock_in_type': 'manual',
            'source': 'dashboard',
          });

      // Real-time listener will automatically update _isClockedIn

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully clocked in!'),
          backgroundColor: Colors.green,
        ),
      );
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
      final user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({
            'is_clocked_in': false,
            'last_clock_out_time': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update attendance record - simplified query to avoid index requirement
      final today = DateTime.now().toIso8601String().split('T')[0];
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // Filter for today's record and find the one without clock_out_time
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        if (data['date'] == today && data['clock_out_time'] == null) {
          await doc.reference.update({
            'clock_out_time': FieldValue.serverTimestamp(),
            'clock_out_type': 'manual',
          });
          break;
        }
      }

      // Create admin notification
      await FirebaseFirestore.instance
          .collection('admin_alerts')
          .add({
            'type': 'night_shift_clock_out',
            'caregiver_id': user.uid,
            'caregiver_name': _username,
            'message': '$_username manually clocked out from dashboard',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'status': 'clocked_out',
            'clock_out_time': FieldValue.serverTimestamp(),
            'clock_out_type': 'manual',
            'source': 'dashboard',
          });

      // Real-time listener will automatically update _isClockedIn

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clocking out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                                          Navigator.pushNamed(context, AppRoutes.uploadVideoScreen);
                                        },
                                        color: AppUtils.getColorScheme(context).tertiaryContainer,
                                        child: const Text(
                                          'Upload Videos',
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
                    adminName = data['name'] ?? 'Unknown';
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