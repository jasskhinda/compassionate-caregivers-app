import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/main_app_bar.dart';
import 'package:caregiver/presentation/main/manageUser/caregiver_list.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';
import '../../../../../component/listLayout/assigned_video_layout.dart';
import '../../../../../component/other/not_found_dialog.dart';
import '../../../../../services/user_video_services.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  // User Info
  String? _role;

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

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            MainAppBar(title: 'Video Library'),

            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 10),

                        if (_isLoading)
                          const Center(child: CircularProgressIndicator()),

                        if (_role != 'Caregiver')
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  'Manage learning content',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppUtils.getColorScheme(context).onSurface
                                  )
                              )
                          ),

                        // Assigned video section(only for caregiver)
                        if (_role == 'Caregiver')
                          _assignedVideos(),

                        // Caregivers name list(only for admin & nurse)
                        if (_role != 'Caregiver')
                          const CaregiverList(),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ]
      ),
    );
  }

  Widget _assignedVideos() {
    final UserVideoServices userVideoServices = UserVideoServices();
    final FirebaseAuth auth = FirebaseAuth.instance;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: userVideoServices.getAssignedVideosForCaregiver(auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: NotFoundDialog(title: 'No Video Assigned Yet', description: 'A video will appear here once it has been assigned to you.'));
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
            final videoUrl = video['videoUrl'] ?? '';
            final progress = video['progress'] ?? '';
            final assignedByUid = video['assignedBy'] ?? '';
            final caregiver = video['assignedTo'] ?? '';
            String date = DateFormat('dd MMM yyyy').format(video['assignedDate'].toDate());
            print('CHECK HERE FIRST$caregiver');

            // Get admin name
            return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('Users').doc(assignedByUid).get(),
                builder: (context, snapshot) {
                  String adminName = 'Loading...';
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
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
                          AppRoutes.videoScreen,
                          arguments: {
                            'videoId': videoId,
                            'date': date,
                            'adminName': adminName,
                            'videoTitle': videoTitle,
                            'videoUrl': videoUrl,
                            'caregiver': caregiver,
                            'progress': progress
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