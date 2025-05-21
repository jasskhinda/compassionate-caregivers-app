import 'package:flutter/material.dart';
import 'package:healthcare/component/appBar/settings_app_bar.dart';
import 'package:healthcare/component/other/basic_button.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/exam/exam_detail_screen.dart';
import 'package:healthcare/utils/app_utils/AppUtils.dart';

import '../../../../services/exam_services.dart';
import '../../../../utils/appRoutes/app_routes.dart';

class ManageExamsScreen extends StatefulWidget {
  const ManageExamsScreen({super.key});

  @override
  State<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State<ManageExamsScreen> {

  List<Map<String, dynamic>> exams = [];
  bool isLoading = true;

  Future<void> fetchExams() async {
    final data = await ExamService.getAllExams();
    setState(() {
      exams = data;
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
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // APP BAR
            const SettingsAppBar(title: 'Manage Exams'),

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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamDetailScreen(examId: exam['id'].toString()),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.all(8),
                                color: AppUtils.getColorScheme(context).secondary,
                                child: ListTile(
                                  title: Text(exam['examTitle'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Questions: ${exam['items'].length} | Timer: ${exam['timer']} minutes',
                                    style: TextStyle(color: AppUtils.getColorScheme(context).onSurface.withAlpha(100)
                                    )
                                  ),
                                  trailing: FittedBox(
                                    child: Row(
                                      children: [
                                        BasicTextButton(
                                            text: 'Assign',
                                            textColor: Colors.white,
                                            buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.assignExamScreen,
                                                  arguments: {
                                                    'examTitle' : exam['examTitle'].toString(),
                                                    'id' : exam['id'].toString(),
                                                  }
                                              );
                                            }
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            final shouldDelete = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Exam'),
                                                content: const Text('Are you sure you want to delete this exam?'),
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

                                            if (shouldDelete == true) {
                                              await ExamService.deleteExamById(exam['id']);
                                              fetchExams(); // Refresh the UI
                                            }
                                          },
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ]
        ),
      ),
    );
  }
}
