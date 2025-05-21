import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'exam_review_screen.dart';

class ExamDetailScreen extends StatefulWidget {
  final String examId;

  const ExamDetailScreen({super.key, required this.examId});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  Map<String, dynamic>? examData;
  bool isLoading = true;
  List<Map<String, String>> caregivers = [];

  @override
  void initState() {
    super.initState();
    fetchExamData();
  }

  Future<void> fetchExamData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (doc.exists) {
        setState(() {
          examData = doc.data();
          isLoading = false;
        });
        fetchCaregivers();
      } else {
        throw Exception("Exam not found");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching exam: $e')),
      );
    }
  }

  Future<void> fetchCaregivers() async {
    final assignedCaregivers = (examData?['assignedUsers'] as List<dynamic>? ?? []);

    List<Map<String, String>> tempCaregivers = [];
    for (var uid in assignedCaregivers) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          tempCaregivers.add({
            'uid': uid,
            'email': userData?['email'] ?? 'No email available',
          });
        }
      } catch (e) {
        debugPrint("Error fetching caregiver data: $e");
      }
    }

    setState(() {
      caregivers = tempCaregivers;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (examData == null) {
      return const Scaffold(
        body: Center(child: Text("No data available.")),
      );
    }

    final items = (examData?['items'] as List<dynamic>? ?? []);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Exam Details")),
        body: const Center(
          child: Text("No questions found for this exam."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Exam Details")),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Text('ASSIGNED CAREGIVER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 5),
                    // Display caregiver emails in a horizontal list
                    if (caregivers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 15),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: caregivers.map<Widget>((caregiver) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ExamReviewScreen(
                                        examId: widget.examId,
                                        userId: caregiver['uid']!,  // pass UID here
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppUtils.getColorScheme(context).tertiaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    caregiver['email']!,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    if (caregivers.isEmpty)
                      const Align(alignment: Alignment.center, child: Text('NO CAREGIVER ASSIGNED', style: TextStyle(fontWeight: FontWeight.bold))),

                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Text('Questions List', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: AppUtils.getColorScheme(context).primaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: items.asMap().map<int, Widget>((itemIndex, item) {
                          final questions = item['questions'] as List<dynamic>? ?? [];
                          final selectedType = item['selectedType'];

                          return MapEntry(
                            itemIndex,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Q${itemIndex + 1} ($selectedType)'),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: questions.length,
                                  itemBuilder: (context, qIndex) {
                                    final q = questions[qIndex];
                                    final questionTitle = q['questionTitle'] ?? 'No Title';
                                    final options = (q['options'] ?? []) as List<dynamic>;
                                    final correctAnswers = (q['correctAnswers'] ?? []) as List<dynamic>;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 5),
                                      child: ListTile(
                                        title: Text('Q. $questionTitle'),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ...options.map<Widget>((opt) => Text('- $opt')).toList(),
                                            const SizedBox(height: 7),
                                            const Text('Correct:', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ...correctAnswers.map<Widget>((ans) => Text('- $ans')).toList(),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).values.toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}