import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/other/basic_button.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  const ExamScreen({super.key, required this.examId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  // TIMER
  Timer? countdownTimer;
  Duration duration = Duration.zero;

  // LOADING EXAM DATA
  Map<String, dynamic>? examData;
  bool isLoading = true;

  // SELECTED ANSWER
  Map<String, dynamic> selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    fetchExamData();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
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

          // Start Timer
          final minutes = examData?['timer'] ?? 0;
          duration = Duration(minutes: minutes);
          startTimer();

          isLoading = false;
        });
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

  void startTimer() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (duration.inSeconds > 0) {
        setState(() {
          duration = duration - const Duration(seconds: 1);
        });
      } else {
        countdownTimer?.cancel();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time's up! Submitting exam...")),
        );

        submitExam();
      }
    });
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> submitExam() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Prevent resubmission
    final existingSubmission = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('exams')
        .doc(widget.examId)
        .get();

    if (existingSubmission.exists && existingSubmission.data()?['score'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already submitted this exam.')),
      );
      return;
    }

    int totalQuestions = 0;
    int correctAnswersCount = 0;
    final List<dynamic> items = examData?['items'] ?? [];
    Map<String, dynamic> answersToSave = {};

    print("Starting exam submission...");

    for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
      final item = items[itemIndex];
      final questions = item['questions'] as List<dynamic>? ?? [];
      final selectedType = (item['selectedType'] ?? '').toString().toLowerCase();

      for (int qIndex = 0; qIndex < questions.length; qIndex++) {
        final q = questions[qIndex];
        final options = (q['options'] ?? []).cast<String>();
        final correctAnswers = (q['correctAnswers'] ?? [])
            .cast<String>()
            .map((e) => e.trim().toUpperCase())
            .toSet();

        final key = '${itemIndex}_$qIndex';
        totalQuestions++;

        final selected = selectedAnswers[key];
        print("\nProcessing question $key");
        print("Question type: '$selectedType'");
        print("Selected answer: $selected");
        print("Available options: $options");
        print("Correct answers (stored): $correctAnswers");

        bool isCorrect = false;
        dynamic answerToSave;

        if (selected == null) {
          print("No answer selected. Skipping...");
          continue;
        }

        if (selectedType.contains('multiple')) {
          final selectedIndexes = selected as Set<int>;
          // Convert selected indexes to letters (A, B, C, D)
          final selectedLetters = selectedIndexes
              .map((i) => String.fromCharCode(65 + i)) // 65 = 'A'
              .toSet();

          print("Selected indexes: $selectedIndexes");
          print("Selected letters: $selectedLetters");
          print("Correct answers: $correctAnswers");

          // Compare letters to letters
          isCorrect = selectedLetters.length == correctAnswers.length &&
              selectedLetters.difference(correctAnswers).isEmpty;

          answerToSave = selectedLetters.toList();
        } else if (selected is int) {
          final selectedIndex = selected;
          if (selectedIndex >= 0 && selectedIndex < options.length) {
            // Convert selected index to letter (A, B, C, D)
            final selectedLetter = String.fromCharCode(65 + selectedIndex);

            print("Selected index: $selectedIndex");
            print("Selected letter: $selectedLetter");
            print("Correct answers: $correctAnswers");

            isCorrect = correctAnswers.contains(selectedLetter);
            answerToSave = selectedLetter;
          }
        }

        if (isCorrect) {
          correctAnswersCount++;
          print("✅ CORRECT! Total correct so far: $correctAnswersCount");
        } else {
          print("❌ INCORRECT!");
        }

        answersToSave[key] = answerToSave;
      }
    }

    print("\n🎯 FINAL SCORING SUMMARY:");
    print("Total Questions: $totalQuestions");
    print("Correct Answers: $correctAnswersCount");
    print("Final Score: ${((correctAnswersCount / totalQuestions) * 100).round()}%");
    print("Final Answers to Save: $answersToSave");

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('exams')
        .doc(widget.examId)
        .set({
      'selectedOption': answersToSave,
      'score': correctAnswersCount,
      'total': totalQuestions,
      'submittedAt': DateTime.now(),
    }, SetOptions(merge: true));

    showDialog(
      context: context,
      builder: (context) {
        int percentage = ((correctAnswersCount / totalQuestions) * 100).round();
        String feedbackMessage;

        if (percentage < 50) {
          feedbackMessage = "😟 Don't worry, our nurse will teach you!";
        } else if (percentage < 80) {
          feedbackMessage = "😊 Good job! Keep practicing.";
        } else {
          feedbackMessage = "🎉 Excellent! You're ready to assist!";
        }

        return AlertDialog(
          title: const Text("Exam Submitted"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("You scored $percentage%", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(feedbackMessage),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context); // Navigate back from the current screen
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

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
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // APP BAR
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Exam',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Exam will ends in: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppUtils.getColorScheme(context).onSurface,
                      ),
                    ),
                    Text(
                      formatDuration(duration),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // REST UI
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
                      Column(
                        children: items.asMap().map<int, Widget>((itemIndex, item) {
                          final questions = item['questions'] as List<dynamic>? ?? [];
                          final selectedType = item['selectedType'];

                          return MapEntry(
                            itemIndex,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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

                                    final key = '${itemIndex}_$qIndex';
                                    final selectedTypeStr = selectedType?.toString().toLowerCase() ?? 'single'; // 'single' or 'multiple'
                                    final isMultiple = selectedTypeStr.contains('multiple');

                                    selectedAnswers.putIfAbsent(key, () => isMultiple ? <int>{} : -1);

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 5),
                                      color: AppUtils.getColorScheme(context).secondary,
                                      child: ListTile(
                                        title: Text('Q. $questionTitle', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Options:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            ...List.generate(options.length, (optIndex) {
                                              final isSelected = isMultiple
                                                  ? (selectedAnswers[key] as Set<int>).contains(optIndex)
                                                  : (selectedAnswers[key] == optIndex);

                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (isMultiple) {
                                                      final selectedSet = selectedAnswers[key] as Set<int>;
                                                      if (selectedSet.contains(optIndex)) {
                                                        selectedSet.remove(optIndex);
                                                      } else {
                                                        selectedSet.add(optIndex);
                                                      }
                                                    } else {
                                                      selectedAnswers[key] = optIndex;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(10),
                                                    color: isSelected
                                                        ? AppUtils.getColorScheme(context).tertiaryContainer
                                                        : AppUtils.getColorScheme(context).primaryFixed,
                                                  ),
                                                  child: Text(
                                                    options[optIndex],
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : AppUtils.getColorScheme(context).onSurface,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
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

                      const SizedBox(height: 15),

                      // SUBMIT BUTTON
                      BasicButton(
                        text: 'Submit Exam',
                        buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                        onPressed: submitExam,
                        textColor: Colors.white,
                      ),

                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
