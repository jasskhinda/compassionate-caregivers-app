import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/exam/caregiver/exam_screen.dart';
import '../../../../../services/exam_services.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class TakeExamScreen extends StatefulWidget {
  const TakeExamScreen({super.key});

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> exams = [];
  bool isLoading = true;

  Future<void> fetchExams() async {
    final userId = _auth.currentUser!.uid;
    final data = await ExamService.getExamsAssignedToUser(userId);

    List<Map<String, dynamic>> filteredExams = [];

    for (var exam in data) {
      final examDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('exams')
          .doc(exam['id'].toString())
          .get();

      if (!examDoc.exists || examDoc.data()?['score'] == null) {
        filteredExams.add(exam);
      }
    }

    setState(() {
      exams = filteredExams;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchExams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // APP BAR
          const SettingsAppBar(title: 'Assigned Exams'),

          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : exams.isEmpty
                          ? const Center(child: Text('No exams found'))
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: exams.length,
                        itemBuilder: (context, index) {
                          final exam = exams[index];
                          return GestureDetector(
                            onTap: () async {
                              final userId = _auth.currentUser!.uid;
                              final existingSubmission = await FirebaseFirestore.instance
                                  .collection('Users')
                                  .doc(userId)
                                  .collection('exams')
                                  .doc(exam['id'].toString())
                                  .get();

                              if (existingSubmission.exists && existingSubmission.data()?['score'] != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You have already submitted this exam.')),
                                );
                                return;
                              }

                              final shouldStart = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Begin Exam?'),
                                  content: const Text(
                                    'Once you start this exam, it must be completed in one sitting.\nYou won\'t be able to pause, go back or make changes once it begins',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Start Exam', style: TextStyle(color: Colors.green.shade700)),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldStart == true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamScreen(examId: exam['id'].toString()),
                                  ),
                                );
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.all(8),
                              color: AppUtils.getColorScheme(context).secondary,
                              child: ListTile(
                                title: Text(
                                  exam['examTitle'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Questions: ${exam['items'].length} | Timer: ${exam['timer']} minutes',
                                  style: TextStyle(
                                    color: AppUtils.getColorScheme(context).onSurface.withAlpha(100),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ]
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}