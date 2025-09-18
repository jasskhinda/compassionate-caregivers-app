import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/models/exam_models.dart';
import 'package:caregiver/services/professional_exam_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class ManageProfessionalExamsScreen extends StatefulWidget {
  const ManageProfessionalExamsScreen({super.key});

  @override
  State<ManageProfessionalExamsScreen> createState() => _ManageProfessionalExamsScreenState();
}

class _ManageProfessionalExamsScreenState extends State<ManageProfessionalExamsScreen> {
  List<ProfessionalExam> exams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchExams();
  }

  Future<void> fetchExams() async {
    try {
      final data = await ProfessionalExamService.getAllExams();
      setState(() {
        exams = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching exams: $e')),
      );
    }
  }

  void _showCopyDialog(ProfessionalExam exam) {
    final titleController = TextEditingController(
      text: '${exam.title} (Copy)',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Professional Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'New Exam Title',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose an option:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _copyExam(
                exam.id,
                titleController.text.trim(),
                publishImmediately: false,
              );
            },
            child: const Text('Copy as Draft'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _copyExam(
                exam.id,
                titleController.text.trim(),
                publishImmediately: true,
              );
            },
            child: const Text(
              'Copy & Publish',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExam(String examId, String newTitle, {bool publishImmediately = false}) async {
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the new exam')),
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
      final newExamId = await ProfessionalExamService.copyExam(
        examId: examId,
        newTitle: newTitle,
        publishImmediately: publishImmediately,
      );

      Navigator.of(context).pop(); // Dismiss loading dialog

      final message = publishImmediately
          ? 'Professional exam copied and published successfully!'
          : 'Professional exam copied as draft successfully!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Refresh the exam list
      fetchExams();

    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying exam: $e')),
      );
    }
  }

  Future<void> _publishExam(ProfessionalExam exam) async {
    try {
      await ProfessionalExamService.publishExam(exam.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam published successfully!')),
      );
      fetchExams(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publishing exam: $e')),
      );
    }
  }

  Future<void> _deleteExam(ProfessionalExam exam) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Professional Exam'),
        content: Text('Are you sure you want to delete "${exam.title}"?'),
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
      try {
        await ProfessionalExamService.deleteExam(exam.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam deleted successfully')),
        );
        fetchExams(); // Refresh
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting exam: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SettingsAppBar(title: 'Manage Professional Exams'),
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
                            ? const Center(child: Text('No professional exams found'))
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: exams.length,
                          itemBuilder: (context, index) {
                            final exam = exams[index];
                            return Card(
                              margin: const EdgeInsets.all(8),
                              color: AppUtils.getColorScheme(context).secondary,
                              child: ListTile(
                                title: Text(
                                  exam.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Questions: ${exam.questions.length} | Category: ${exam.category.name.toUpperCase()}',
                                      style: TextStyle(
                                        color: AppUtils.getColorScheme(context).onSurface.withAlpha(100),
                                      ),
                                    ),
                                    Text(
                                      'Difficulty: ${exam.difficulty.name.toUpperCase()} | ${exam.isPublished ? "Published" : "Draft"}',
                                      style: TextStyle(
                                        color: exam.isPublished ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: FittedBox(
                                  child: Row(
                                    children: [
                                      if (!exam.isPublished)
                                        BasicTextButton(
                                          text: 'Publish',
                                          textColor: Colors.white,
                                          buttonColor: Colors.green,
                                          onPressed: () => _publishExam(exam),
                                        ),
                                      if (exam.isPublished)
                                        BasicTextButton(
                                          text: 'Assign',
                                          textColor: Colors.white,
                                          buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                                          onPressed: () {
                                            // TODO: Add professional exam assignment functionality
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Professional exam assignment coming soon!')),
                                            );
                                          },
                                        ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () => _showCopyDialog(exam),
                                        icon: const Icon(Icons.copy, color: Colors.blue),
                                        tooltip: 'Copy Exam',
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteExam(exam),
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: 'Delete Exam',
                                      ),
                                    ],
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
            ),
          ],
        ),
      ),
    );
  }
}