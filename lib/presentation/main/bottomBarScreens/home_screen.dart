import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/home_app_bar.dart';
import 'package:caregiver/component/home/initial_option_layout.dart';
import 'package:caregiver/component/listLayout/assigned_video_layout.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/component/other/not_found_dialog.dart';
import 'package:caregiver/presentation/main/manageUser/caregiver_list.dart';
import 'package:caregiver/services/user_video_services.dart';
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

  // User count
  int? _nurse;
  int? _caregiver;
  bool _isLoading = true;

  // User info
  String? _role;
  String? _username;
  int? _assignedVideo;
  int? _completedVideo;

  // Get all user count
  Future<void> _getUserCount() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _nurse = data['nurse'];
          _caregiver = data['caregiver'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  // Get user video details
  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
          _username = data['name'];
          _assignedVideo = data['assigned_video'];
          _completedVideo = data['completed_video'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      if(!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _getUserCount();
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
              await Future.wait([
                _getUserInfo(),
                _getUserCount(),
              ]);
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
                              optionOneTitle: 'Nurse',
                              optionOneIcon: Icons.health_and_safety,
                              optionTwoTitle: 'Caregiver',
                              optionTwoIcon: Icons.person,
                              optionOneCount: _nurse.toString(),
                              optionTwoCount: _caregiver.toString(),
                              optionOneOnTap: () => Navigator.pushNamed(context, AppRoutes.allNurseUserScreen),
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

                          if (_role == 'Admin')
                            const SizedBox(height: 15),

                          // Only for Nurse & Admin
                          if (_role != 'Caregiver')
                            Text(
                                'Manage content',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppUtils.getColorScheme(context).onSurface
                                )
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // if user is admin show add user button
                              if (_role == 'Admin')
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

                              // If user is nurse show caregiver count
                              if (_role == 'Nurse')
                                Expanded(
                                  child: UserCountLayout(
                                    title: 'Caregiver',
                                    count: _caregiver.toString(),
                                    icon: Icons.person
                                  )
                                ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // Exam
                          Text(
                              _role == 'Admin' ? 'Exam Management' : 'Assigned Exams',
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
}