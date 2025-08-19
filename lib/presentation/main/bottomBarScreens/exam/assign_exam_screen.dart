import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/listLayout/manage_user_layout.dart';
import 'package:caregiver/component/other/input_text_fields/text_input.dart';
import 'package:caregiver/services/exam_services.dart';
import '../../../../component/other/basic_button.dart';
import '../../../../services/email_service.dart';
import '../../../../services/user_services.dart';
import '../../../../services/notification_service.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../component/listLayout/user_layout.dart';
import '../../../../utils/appRoutes/app_routes.dart';

class AssignExamScreen extends StatefulWidget {
  const AssignExamScreen({super.key});

  @override
  State<AssignExamScreen> createState() => _AssignExamScreenState();
}

class _AssignExamScreenState extends State<AssignExamScreen> {

  // Firebase instance
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Search text view
  late TextEditingController _searchController;

  final UserServices _userServices = UserServices();
  final NotificationService _notificationService = NotificationService();
  List<String> assignedCaregivers = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    Future.microtask(() async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final examID = args['id'];

        final doc = await FirebaseFirestore.instance
            .collection('exams')
            .doc(examID)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['assignedUsers'] != null) {
            setState(() {
              assignedCaregivers = List<String>.from(data['assignedUsers']);
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

  void _assignExamToFirestore(String examID, String examTitle) async {
    if (assignedCaregivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one caregiver.")),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (String userId in assignedCaregivers) {
        await ExamService.assignExamToUser(userId: userId, examId: examID);
      }

      Navigator.of(context).pop(); // Dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exam assigned successfully.")),
      );

      // Send notifications to assigned caregivers
      await _notificationService.sendNotificationToUsers(
        userIds: assignedCaregivers,
        title: 'New Video Assigned',
        body: 'A new video "$examTitle" has been assigned to you.',
        data: {
          'examId': examID,
          'videoTitle': examTitle,
          'type': 'exam_assigned'
        },
      );

      // Send emails to assigned caregivers
      for (String userId in assignedCaregivers) {
        try {
          final docSnapshot = await firestore.collection('Users').doc(userId).get();
          if (docSnapshot.exists) {
            final caregiverEmail = docSnapshot.data()?['email'];
            if (caregiverEmail != null && caregiverEmail.isNotEmpty) {
              await sendAssignedVideoEmail(
                recipientEmail: caregiverEmail,
                videoBody: 'You have been assigned a new exam titled',
                videoTitle: examTitle,
                type: 'Exam'
              );
            }
          }
        } catch (e) {
          print('Failed to send email to caregiver $userId: $e');
        }
      }

      setState(() {
        assignedCaregivers.clear();
      });

      Navigator.pop(context); // Optionally close screen
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog on error

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error assigning exam: $e")),
      );
    }
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
    final examTitle = args['examTitle'] ?? '';
    final id = args['id'] ?? '';

    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: Center(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SettingsAppBar(title: 'Assign Exam'),
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
                            'Exam ID',
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
                              id,
                              style: TextStyle(color: AppUtils.getColorScheme(context).onSurface)
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Paste Link
                        Text(
                            'Exam Title',
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
                              examTitle,
                              style: TextStyle(color: AppUtils.getColorScheme(context).onSurface)
                          ),
                        ),

                        const SizedBox(height: 20),

                        IconBasicButton(
                          onPressed: () {
                            _bottomSheet();
                          },
                          icon: Icons.add,
                          text: 'Assign exam to caregiver',
                          buttonColor: AppUtils.getColorScheme(context).secondary,
                          textColor: AppUtils.getColorScheme(context).onSurface,
                        ),

                        const SizedBox(height: 10),

                        BasicButton(
                          onPressed: () {
                            _assignExamToFirestore(id, examTitle);
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