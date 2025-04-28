import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/component/appBar/settings_app_bar.dart';
import 'package:healthcare/component/other/basic_button.dart';
import 'package:healthcare/component/other/upload_video_dialog.dart';
import 'package:healthcare/services/category_services.dart';
import 'package:healthcare/utils/appRoutes/app_routes.dart';
import 'package:intl/intl.dart';

import '../../../../../component/listLayout/assigned_video_layout.dart';
import '../../../../../component/other/not_found_dialog.dart';
import '../../../../../services/user_video_services.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class SubcategoryVideoScreen extends StatefulWidget {
  const SubcategoryVideoScreen({super.key});

  @override
  State<SubcategoryVideoScreen> createState() => _SubcategoryVideoScreenState();
}

class _SubcategoryVideoScreenState extends State<SubcategoryVideoScreen> {

  // User info
  String? _role;

  // Instance
  final firestore = CategoryServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Text editing controller
  late TextEditingController titleController = TextEditingController();
  late TextEditingController linkController = TextEditingController();

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
        });
      } else {
        debugPrint("No such document!");
      }
    } catch (e) {
      debugPrint("Error fetching document: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    linkController = TextEditingController();
    _getUserInfo();
  }

  @override
  void dispose() {
    titleController.dispose();
    linkController.dispose();
    super.dispose();
  }

  // Extract youtube video id from link
  String? extractYouTubeVideoId(String url) {
    final RegExp regExp = RegExp(
        r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([^\s&#?]+)'
    );
    final match = regExp.firstMatch(url);
    // return match != null ? match.group(1) : null;
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    final categoryName = args['categoryName'] ?? 'Default Category Title';
    final subcategoryName = args['subcategoryName'] ?? 'Default Sub Category Title';

    return Scaffold(
      bottomNavigationBar: _role == 'Admin' ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Upload video from youtube
              BasicTextButton(
                  width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.3 : AppUtils.getScreenSize(context).width * 0.7,
                  text: 'Upload Video from youtube',
                  fontSize: 14,
                  buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                  textColor: Colors.white,
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Upload Video"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(hintText: "Video Title"),
                          ),
                          TextField(
                            controller: linkController,
                            decoration: const InputDecoration(hintText: "YouTube Link"),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // Extract YouTube ID
                            final String? youtubeVideoId = extractYouTubeVideoId(linkController.text);
                            if (youtubeVideoId == null) {
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a valid YouTube link")),
                              );
                              return;
                            }
                            firestore.addVideo(
                              categoryName: categoryName,
                              subcategoryName: subcategoryName,
                              title: titleController.text.trim(),
                              youtubeLink: youtubeVideoId.trim(),
                              uploadedAt: DateTime.now(),
                              isVimeo: false
                            );
                            Navigator.pop(context);
                            titleController.clear();
                            linkController.clear();
                          },
                          child: Text("Upload", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
                        ),
                      ],
                    ),
                  );
                }
              ),

              const SizedBox(width: 10),

              // Upload video from vimeo
              BasicTextButton(
                  width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.3 : AppUtils.getScreenSize(context).width * 0.7,
                  text: 'Upload Video from vimeo',
                  fontSize: 14,
                  buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                  textColor: Colors.white,
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => UploadVideoDialog(categoryName: categoryName, subcategoryName: subcategoryName),
                    );
                  }
              ),
            ],
          ),

          const SizedBox(height: 20)
        ],
      ) : const SizedBox.shrink(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SettingsAppBar(title: '$subcategoryName Videos'),

          SliverToBoxAdapter(
              child: Center(
                  child: SizedBox(
                      width: AppUtils.getScreenSize(context).width >= 600
                          ? AppUtils.getScreenSize(context).width * 0.45
                          : double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 10),

                                // if (_isLoading)
                                //   const Center(child: CircularProgressIndicator()),

                                // Assigned video section(only for caregiver)
                                if (_role == 'Caregiver')
                                  _assignedVideos(categoryName, subcategoryName),

                                if (_role != 'Caregiver')
                                  _subcategoryVideos(categoryName, subcategoryName),

                                const SizedBox(height: 90)
                              ]
                          )
                      )
                  )
              )
          )
        ]
      )
    );
  }

  Widget _assignedVideos(String categoryName, String subcategoryName) {
    final UserVideoServices userVideoServices = UserVideoServices();
    final FirebaseAuth auth = FirebaseAuth.instance;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: userVideoServices.getAssignedVideosForCaregiver(auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: NotFoundDialog(title: 'No Assigned Videos Found', description: 'You haven\'t been assigned any videos yet. Please check back later!'),);
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
                            'progress': progress,
                            'categoryName': categoryName,
                            'subcategoryName': subcategoryName
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

  Widget _subcategoryVideos(String categoryName, String subcategoryName) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.getVideos(categoryName, subcategoryName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: NotFoundDialog(
              title: 'No Videos Found',
              description: 'No videos available for this subcategory. Upload or assign a new video to get started.',
            ),
          );
        }

        final videos = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final videoTitle = video['title'];
            final videoLink = video['youtubeLink'];
            final videoId = video['videoId'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.videoScreen,
                    arguments: {
                      'videoId' : videoId,
                      'videoUrl': videoLink,
                      'videoTitle' : videoTitle,
                      'categoryName': categoryName,
                      'subcategoryName': subcategoryName
                    }
                  );
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  tileColor: AppUtils.getColorScheme(context).secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(videoTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BasicTextButton(
                        text: 'Assign',
                        textColor: Colors.white,
                        buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.assignVideoScreen,
                            arguments: {
                              'videoId' : videoId,
                              'videoTitle' : videoTitle,
                              'videoLink' : videoLink,
                              'categoryName' : categoryName,
                              'subcategoryName' : subcategoryName
                            }
                          );
                        }
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // Show confirmation dialog
                          bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Video'),
                              content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              // Delete from categories collection
                              await FirebaseFirestore.instance
                                  .collection('categories')
                                  .doc(categoryName)
                                  .collection('subcategories')
                                  .doc(subcategoryName)
                                  .collection('videos')
                                  .doc(videoId)
                                  .delete();

                              // Delete from assigned_videos collection
                              await FirebaseFirestore.instance
                                  .collection('assigned_videos')
                                  .where('videoId', isEqualTo: videoId)
                                  .get()
                                  .then((snapshot) {
                                for (var doc in snapshot.docs) {
                                  doc.reference.delete();
                                }
                              });

                              // Delete from caregiver_videos collection
                              // First get the assigned caregivers from categories
                              final videoDoc = await FirebaseFirestore.instance
                                  .collection('categories')
                                  .doc(categoryName)
                                  .collection('subcategories')
                                  .doc(subcategoryName)
                                  .collection('videos')
                                  .doc(videoId)
                                  .get();

                              final assignedCaregivers = videoDoc.data()?['assignedTo'] as List<dynamic>? ?? [];

                              // Delete from each caregiver's video collection
                              for (String caregiverId in assignedCaregivers) {
                                await FirebaseFirestore.instance
                                    .collection('caregiver_videos')
                                    .doc(caregiverId)
                                    .collection('videos')
                                    .doc(videoId)
                                    .delete();
                              }

                              // Update assigned video count in Users collection
                              await FirebaseFirestore.instance
                                  .collection('Users')
                                  .where('assignedVideos', arrayContains: videoId)
                                  .get()
                                  .then((snapshot) {
                                for (var doc in snapshot.docs) {
                                  doc.reference.update({
                                    'assignedVideos': FieldValue.arrayRemove([videoId]),
                                    'assignedVideoCount': FieldValue.increment(-1)
                                  });
                                }
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Video deleted successfully')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting video: $e')),
                              );
                            }
                          }
                        },
                      ),
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
}