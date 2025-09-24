import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/listLayout/manage_user_layout.dart';
import 'package:caregiver/component/other/input_text_fields/text_input.dart';
import '../../../../component/other/basic_button.dart';
import '../../../../services/email_service.dart';
import '../../../../services/user_services.dart';
import '../../../../services/notification_service.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../component/listLayout/user_layout.dart';
import '../../../../utils/appRoutes/app_routes.dart';

class AssignVideoScreen extends StatefulWidget {
  const AssignVideoScreen({super.key});

  @override
  State<AssignVideoScreen> createState() => _AssignVideoScreenState();
}

class _AssignVideoScreenState extends State<AssignVideoScreen> {
  late TextEditingController _searchController;

  final UserServices _userServices = UserServices();
  final NotificationService _notificationService = NotificationService();
  List<String> assignedCaregivers = [];

  // Function to create a secure display ID from video URL
  String _createSecureDisplayId(String videoUrl) {
    if (videoUrl.isEmpty) return 'No video URL';

    // Extract video ID from different URL formats
    String videoId = '';

    if (videoUrl.contains('vimeo.com/video/')) {
      // Vimeo URL: https://player.vimeo.com/video/1121625494?h=f812d12007
      final match = RegExp(r'vimeo\.com/video/([0-9]+)').firstMatch(videoUrl);
      if (match != null) {
        videoId = match.group(1) ?? '';
        return 'VID-${videoId.substring(0, 4)}****';
      }
    } else if (videoUrl.contains('youtube.com/watch') || videoUrl.contains('youtu.be/')) {
      // YouTube URLs
      final match = RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)').firstMatch(videoUrl);
      if (match != null) {
        videoId = match.group(1) ?? '';
        return 'YT-${videoId.substring(0, 4)}****';
      }
    }

    // Fallback for other URLs - show first 12 chars + masked rest
    if (videoUrl.length > 12) {
      return '${videoUrl.substring(0, 12)}****[PROTECTED]';
    }

    return 'VID-[PROTECTED]';
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    Future.microtask(() async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final categoryName = args['categoryName'];
        final subcategoryName = args['subcategoryName'];
        final videoId = args['videoId'];

        final doc = await FirebaseFirestore.instance
            .collection('categories')
            .doc(categoryName)
            .collection('subcategories')
            .doc(subcategoryName)
            .collection('videos')
            .doc(videoId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['assignedTo'] != null) {
            setState(() {
              assignedCaregivers = List<String>.from(data['assignedTo']);
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _assignVideoToFirestore(
      String videoTitle,
      String videoUrl,
      String categoryVideoId,
      String categoryName,
      String subcategoryName,
  ) async {

    if(!mounted) return;

    // Show loading circle
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    if (videoTitle.isEmpty || videoUrl.isEmpty || assignedCaregivers.isEmpty) {
      if (!mounted) return;

      // Close loading dialog - using a more reliable method
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all details and select caregivers")));
      return;
    }

    Timestamp assignedDate = Timestamp.now();
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Store in `assigned_videos` collection
    // await firestore.collection("assigned_videos").doc(categoryVideoId).set({
    //   "title": videoTitle,
    //   "videoUrl": videoUrl,
    //   "videoId": categoryVideoId,
    //   "assignedCaregivers": assignedCaregivers,
    //   "assignedBy": auth.currentUser?.uid,
    //   "assignedDate": assignedDate
    // });

    // Store per caregiver in `caregiver_videos` collection
    for (String caregiverId in assignedCaregivers) {
      await firestore.collection("caregiver_videos").doc(caregiverId).collection("videos").doc(categoryVideoId).set({
        "title": videoTitle,
        "youtubeLink": videoUrl,
        "progress": 0.0, // Changed from 0 to 0.0 to ensure it's a double
        "completed": 0,
        "assignedBy": auth.currentUser?.uid,
        "assignedDate": assignedDate,
        "assignedTo": caregiverId,
        "videoId": categoryVideoId,
        "restCaregiver" : assignedCaregivers
      });
    }

    // Update with assigned caregiver
    await firestore
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName)
        .collection('videos')
        .doc(categoryVideoId)
        .set({"assignedTo": assignedCaregivers, "assignedBy": auth.currentUser?.uid, "assignedDate": assignedDate}, SetOptions(merge: true));

    // Increment assigned video number for each caregiver
    for (String caregiverId in assignedCaregivers) {
      await firestore
          .collection('Users')
          .doc(caregiverId)
          .set({"assigned_video": FieldValue.increment(1)}, SetOptions(merge: true));
      print("Updating caregiverId: $caregiverId");
    }

    // Send notifications to assigned caregivers
    await _notificationService.sendNotificationToUsers(
      userIds: assignedCaregivers,
      title: 'New Video Assigned',
      body: 'A new video "$videoTitle" has been assigned to you.',
      data: {
        'videoId': categoryVideoId,
        'videoTitle': videoTitle,
        'youtubeLink': videoUrl,
        'categoryName': categoryName,
        'subcategoryName': subcategoryName,
        'type': 'video_assigned'
      },
    );

    // Send emails to assigned caregivers
    for (String caregiverId in assignedCaregivers) {
      try {
        final docSnapshot = await firestore.collection('Users').doc(caregiverId).get();
        if (docSnapshot.exists) {
          final caregiverEmail = docSnapshot.data()?['email'];
          if (caregiverEmail != null && caregiverEmail.isNotEmpty) {
            await sendAssignedVideoEmail(
              recipientEmail: caregiverEmail,
              videoBody: 'You have been assigned a new video titled',
              videoTitle: videoTitle,
              type: 'Video'
            );
          }
        }
      } catch (e) {
        print('Failed to send email to caregiver $caregiverId: $e');
      }
    }

    // Close the loading dialog
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video assigned successfully!")));
  }

  void _bottomSheet() {
    showModalBottomSheet(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userServices.getCaregiverStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading caregivers"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No caregivers available"));
                }

                List<Map<String, dynamic>> caregivers = snapshot.data!;
                String query = _searchController.text.toLowerCase();

                List<Map<String, dynamic>> filteredCaregivers = caregivers.where((caregiver) {
                  final name = caregiver['name']?.toLowerCase() ?? '';
                  final email = caregiver['email']?.toLowerCase() ?? '';
                  return name.contains(query) || email.contains(query);
                }).toList();

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    right: 15,
                    left: 15,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppUtils.getColorScheme(context).onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextInput(
                        obscureText: false,
                        onChanged: (value) {
                          setModalState(() {}); // this works now!
                        },
                        controller: _searchController,
                        labelText: 'Search',
                        hintText: 'e.g. john doe, smith...',
                        errorText: '',
                        prefixIcon: Icon(Icons.search, color: AppUtils.getColorScheme(context).tertiaryContainer),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setModalState(() {});
                          },
                          icon: Icon(Icons.clear, color: AppUtils.getColorScheme(context).tertiaryContainer),
                        )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filteredCaregivers.isEmpty
                            ? const Center(child: Text("No caregivers match your search."))
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredCaregivers.length,
                          itemBuilder: (context, index) {
                            String caregiverId = filteredCaregivers[index]["uid"];
                            String caregiverName = filteredCaregivers[index]["name"];
                            String caregiverEmail = filteredCaregivers[index]["email"] ?? '';
                            bool isAdded = assignedCaregivers.contains(caregiverId);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: UserLayout(
                                title: caregiverName,
                                description: caregiverEmail,
                                profileImageUrl: filteredCaregivers[index]['profile_image_url'],
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.assignedVideoScreen,
                                    arguments: {
                                      'userID': filteredCaregivers[index]['uid']
                                    }
                                  );
                                },
                                trailing: ElevatedButton(
                                  onPressed: isAdded
                                      ? null // disable button if already added
                                      : () {
                                    setModalState(() {
                                      assignedCaregivers.add(caregiverId);
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAdded
                                        ? Colors.grey
                                        : AppUtils.getColorScheme(context).tertiaryContainer,
                                  ),
                                  child: Text(
                                    isAdded ? "Added" : "Add",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 70)
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    final videoId = args['videoId'] ?? '';
    final videoTitle = args['videoTitle'] ?? '';
    final videoLink = args['videoLink'] ?? '';
    final categoryName = args['categoryName'] ?? '';
    final subcategoryName = args['subcategoryName'] ?? '';

    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: Center(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SettingsAppBar(title: 'Assign Video'),
            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Video Title
                        Text(
                          'Video Title',
                          style: TextStyle(color: AppUtils.getColorScheme(context).onSurface, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppUtils.getColorScheme(context).secondary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            videoTitle,
                            style: TextStyle(color: AppUtils.getColorScheme(context).onSurface)
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Paste Link
                        Text(
                            'Video ID',
                            style: TextStyle(color: AppUtils.getColorScheme(context).onSurface, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppUtils.getColorScheme(context).secondary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                              _createSecureDisplayId(videoLink),
                              style: TextStyle(color: AppUtils.getColorScheme(context).onSurface)
                          ),
                        ),

                        const SizedBox(height: 20),

                        IconBasicButton(
                          onPressed: () {
                            _bottomSheet();
                          },
                          icon: Icons.add,
                          text: 'Assign video to caregiver',
                          buttonColor: AppUtils.getColorScheme(context).secondary,
                          textColor: AppUtils.getColorScheme(context).onSurface,
                        ),

                        const SizedBox(height: 10),

                        BasicButton(
                          onPressed: () {
                            _assignVideoToFirestore(
                              videoTitle,
                              videoLink,
                              videoId,
                              categoryName,
                              subcategoryName
                            );
                          },
                          text: 'Assign',
                          buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                          textColor: Colors.white,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}