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
          feedbackMessage = "😟 Don't worry, our staff will teach you!";
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

    // Calculate total questions
    int totalQuestions = 0;
    for (var item in items) {
      final questions = item['questions'] as List<dynamic>? ?? [];
      totalQuestions += questions.length;
    }

    // Calculate answered questions
    int answeredQuestions = selectedAnswers.values.where((answer) {
      if (answer is Set<int>) {
        return answer.isNotEmpty;
      } else if (answer is int) {
        return answer >= 0;
      }
      return false;
    }).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // PROFESSIONAL EXAM HEADER
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppUtils.getColorScheme(context).primary,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppUtils.getColorScheme(context).primary,
                      AppUtils.getColorScheme(context).primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exam Title
                        Text(
                          examData?['examTitle'] ?? 'Professional Assessment',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Progress and Timer Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Progress
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Progress: $answeredQuestions / $totalQuestions',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            // Timer
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: Colors.red.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDuration(duration),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Progress Bar
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: totalQuestions > 0 ? answeredQuestions / totalQuestions : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

                                    // Calculate overall question number across all items
                                    int overallQuestionNumber = 1;
                                    for (int i = 0; i < itemIndex; i++) {
                                      final prevItem = items[i];
                                      final prevQuestions = prevItem['questions'] as List<dynamic>? ?? [];
                                      overallQuestionNumber += prevQuestions.length;
                                    }
                                    overallQuestionNumber += qIndex;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      color: AppUtils.getColorScheme(context).surface,
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Question Header
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppUtils.getColorScheme(context).primary,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    'Question $overallQuestionNumber',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isMultiple ? Colors.orange.shade100 : Colors.blue.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    isMultiple ? 'Multiple Choice' : 'Single Choice',
                                                    style: TextStyle(
                                                      color: isMultiple ? Colors.orange.shade800 : Colors.blue.shade800,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 16),

                                            // Question Text
                                            Text(
                                              questionTitle,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: AppUtils.getColorScheme(context).onSurface,
                                                height: 1.4,
                                              ),
                                            ),

                                            if (isMultiple) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Select all that apply',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ],

                                            const SizedBox(height: 20),

                                            // Answer Options
                                            ...List.generate(options.length, (optIndex) {
                                              final isSelected = isMultiple
                                                  ? (selectedAnswers[key] as Set<int>).contains(optIndex)
                                                  : (selectedAnswers[key] == optIndex);

                                              final optionLetter = String.fromCharCode(65 + optIndex); // A, B, C, D

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
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? AppUtils.getColorScheme(context).primary
                                                          : Colors.grey.shade300,
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                    color: isSelected
                                                        ? AppUtils.getColorScheme(context).primary.withOpacity(0.1)
                                                        : AppUtils.getColorScheme(context).surface,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Option Letter Badge
                                                      Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: isSelected
                                                              ? AppUtils.getColorScheme(context).primary
                                                              : Colors.grey.shade200,
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? AppUtils.getColorScheme(context).primary
                                                                : Colors.grey.shade400,
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            optionLetter,
                                                            style: TextStyle(
                                                              color: isSelected
                                                                  ? Colors.white
                                                                  : Colors.grey.shade600,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),

                                                      // Option Text
                                                      Expanded(
                                                        child: Text(
                                                          options[optIndex],
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: AppUtils.getColorScheme(context).onSurface,
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),

                                                      // Selection Indicator
                                                      if (isSelected)
                                                        Icon(
                                                          isMultiple ? Icons.check_box : Icons.radio_button_checked,
                                                          color: AppUtils.getColorScheme(context).primary,
                                                          size: 20,
                                                        )
                                                      else
                                                        Icon(
                                                          isMultiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked,
                                                          color: Colors.grey.shade400,
                                                          size: 20,
                                                        ),
                                                    ],
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

                      const SizedBox(height: 30),

                      // EXAM COMPLETION SECTION
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Completion Status
                            Row(
                              children: [
                                Icon(
                                  answeredQuestions == totalQuestions
                                      ? Icons.check_circle
                                      : Icons.info_outline,
                                  color: answeredQuestions == totalQuestions
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        answeredQuestions == totalQuestions
                                            ? 'All questions completed!'
                                            : 'Questions remaining',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: answeredQuestions == totalQuestions
                                              ? Colors.green
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                      Text(
                                        '$answeredQuestions of $totalQuestions questions answered',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Warning for incomplete exam
                            if (answeredQuestions < totalQuestions) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You can submit now, but unanswered questions will be marked as incorrect.',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: submitExam,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppUtils.getColorScheme(context).primary,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      answeredQuestions == totalQuestions
                                          ? 'Submit Exam'
                                          : 'Submit Incomplete Exam',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
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
