import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:intl/intl.dart';
import '../../../../../component/listLayout/assigned_video_layout.dart';
import '../../../../../component/other/not_found_dialog.dart';
import '../../../../../services/user_video_services.dart';
import '../../../../../utils/appRoutes/app_routes.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class AssignedVideoScreen extends StatefulWidget {
  const AssignedVideoScreen({super.key});

  @override
  State<AssignedVideoScreen> createState() => _AssignedVideoScreenState();
}

class _AssignedVideoScreenState extends State<AssignedVideoScreen> {

  // Firebase Instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User services instance
  final UserVideoServices _userVideoServices = UserVideoServices();

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userID = args?['userID'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          const SettingsAppBar(title: 'Assigned Videos'),

          // Rest of ui
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Column(
                    children: [
                      _assignedVideos(userID),
                      const SizedBox(height: 100),
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

  Widget _assignedVideos(String userID) {

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _userVideoServices.getAssignedVideosForCaregiver(
        userID.isNotEmpty ? userID : _auth.currentUser!.uid
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: NotFoundDialog(title: 'No Video Assigned Yet', description: 'A video will appear here once it has been assigned to you.'));
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
            final progress = video['progress'] ?? 0.0;
            final assignedByUid = video['assignedBy'] ?? '';
            String date = DateFormat('dd MMM yyyy').format(video['assignedDate'].toDate());

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
                    progress: progress.toDouble(),
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
