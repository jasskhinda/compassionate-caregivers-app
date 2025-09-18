import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/component/other/input_text_fields/input_text_field.dart';
import 'professional_create_exam_screen.dart';

import '../../../../services/exam_services.dart';
import '../../../../utils/app_utils/AppUtils.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {

  // PROGRESS BAR
  bool isSaving = false;

  // Use this controller to get what the user typed
  late TextEditingController examNameController;
  late TextEditingController questionTitleController;
  late TextEditingController option1Controller;
  late TextEditingController option2Controller;
  late TextEditingController option3Controller;
  late TextEditingController option4Controller;
  late TextEditingController answerController;
  late TextEditingController timerController;
  List<Map<String, dynamic>> exams = []; // List to store all exam data temporarily

  // Dropdown selection
  String selectedType = 'Single Choice';

  @override
  void initState() {
    super.initState();
    timerController = TextEditingController();
    examNameController = TextEditingController();
    questionTitleController = TextEditingController();
    option1Controller = TextEditingController();
    option2Controller = TextEditingController();
    option3Controller = TextEditingController();
    option4Controller = TextEditingController();
    answerController = TextEditingController();
  }

  @override
  void dispose() {
    timerController.dispose();
    examNameController.dispose();
    questionTitleController.dispose();
    option1Controller.dispose();
    option2Controller.dispose();
    option3Controller.dispose();
    option4Controller.dispose();
    answerController.dispose();
    super.dispose();
  }


  void addQuestionToExam() {
    final options = [
      option1Controller.text.trim(),
      option2Controller.text.trim(),
      if (option3Controller.text.isNotEmpty) option3Controller.text.trim(),
      if (option4Controller.text.isNotEmpty) option4Controller.text.trim(),
    ];

    final correctAnswers = answerController.text
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .toList();

    final question = {
      'questionTitle': questionTitleController.text.trim(),
      'options': options,
      'correctAnswers': correctAnswers,
    };

    setState(() {
      // Add the question to the temporary exam map (which you will later store into exams)
      exams.add({
        'selectedType': selectedType,
        'questions': [question], // Can add more questions later
      });

      // Clear inputs for the next question
      questionTitleController.clear();
      option1Controller.clear();
      option2Controller.clear();
      option3Controller.clear();
      option4Controller.clear();
      answerController.clear();

      debugPrint('Exams DATA: $exams');
    });
  }

  void onSavePressed() async {
    final timer = int.tryParse(timerController.text.trim()) ?? 0;

    if (exams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some questions')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize & Publish Exam'),
        content: const Text('Please review all questions carefully. Once published, the exam cannot be edited or changed.\nAre you sure you want to publish this exam?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Publish', style: TextStyle(color: Colors.green.shade700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await ExamService.saveExamData(
        examTitle: examNameController.text.toString().trim(),
        timer: timer,
        items: exams,
      );
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam saved successfully')),
      );
    } catch (_) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save exam')),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
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
            // App bar
            const SettingsAppBar(title: 'Create Exam'),

            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // Exam Name
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppUtils.getColorScheme(context).primaryFixed,
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exam Title',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppUtils.getColorScheme(context).onSurface,
                                ),
                              ),
                              const SizedBox(height: 7),
                              InputTextField(
                                  controller: examNameController,
                                  onTextChanged: (value) {
                                    setState(() {}); // Call setState to rebuild the widget on text change
                                  },
                                  labelText: 'Enter your exam name',
                                  hintText: 'e.g. Blood Test or Math Quiz',
                                  prefixIcon: Icons.title,
                                  suffixIcon: Icons.clear,
                                  onIconPressed: () {
                                    setState(() {
                                      examNameController.clear(); // Clear text field on tap
                                    });
                                  }
                              ),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: timerController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Timer (in minutes)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        // QUESTIONS LIST
                        if (exams.isNotEmpty)
                          const Text(
                            'Questions List:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        if (exams.isNotEmpty)
                          Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppUtils.getColorScheme(context).primaryFixed,
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: Column(
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: exams.length,
                                itemBuilder: (context, examIndex) {
                                  final exam = exams[examIndex];
                                  final questions = exam['questions'] as List<dynamic>;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text('Q${examIndex + 1} (${exam['selectedType']})'),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                exams.removeAt(examIndex);
                                              });
                                            },
                                            icon: const Icon(Icons.delete, color: Colors.red)
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: questions.length,
                                        itemBuilder: (context, qIndex) {
                                          final q = questions[qIndex];
                                          final options = q['options'];
                                          final correctAnswers = q['correctAnswers'];

                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 5),
                                            child: ListTile(
                                              title: Text('${qIndex + 1}. ${q['questionTitle']}'),
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
                                  );
                                },
                              )
                            ],
                          )
                        ),

                        const SizedBox(height: 15),

                        // CREATE QUESTIONS
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: AppUtils.getColorScheme(context).primaryFixed,
                              borderRadius: BorderRadius.circular(20)
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enter Question Details',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppUtils.getColorScheme(context).onSurface,
                                ),
                              ),
                              const SizedBox(height: 7),

                              InputTextField(
                                  controller: questionTitleController,
                                  onTextChanged: (value) {
                                    setState(() {}); // Call setState to rebuild the widget on text change
                                  },
                                  labelText: 'Enter Question Title',
                                  hintText: 'e.g., What is 2 + 2?',
                                  prefixIcon: Icons.title,
                                  suffixIcon: Icons.clear,
                                  onIconPressed: () {
                                    setState(() {
                                      questionTitleController.clear(); // Clear text field on tap
                                    });
                                  }
                              ),
                              const SizedBox(height: 14),
                              // IMPROVED OPTIONS INPUT - Much clearer!
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📝 Answer Options (Just type the option text)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'The app automatically adds A., B., C., D. - just type the option text!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Option A
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InputTextField(
                                        controller: option1Controller,
                                        onTextChanged: (value) {
                                          setState(() {});
                                        },
                                        labelText: 'Option A',
                                        hintText: 'e.g., Red blood cells',
                                        prefixIcon: Icons.looks_one,
                                        suffixIcon: Icons.clear,
                                        onIconPressed: () {
                                          setState(() {
                                            option1Controller.clear();
                                          });
                                        }
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Option B
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'B',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InputTextField(
                                        controller: option2Controller,
                                        onTextChanged: (value) {
                                          setState(() {});
                                        },
                                        labelText: 'Option B',
                                        hintText: 'e.g., White blood cells',
                                        prefixIcon: Icons.looks_two,
                                        suffixIcon: Icons.clear,
                                        onIconPressed: () {
                                          setState(() {
                                            option2Controller.clear();
                                          });
                                        }
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Option C (Optional)
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'C',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InputTextField(
                                        controller: option3Controller,
                                        onTextChanged: (value) {
                                          setState(() {});
                                        },
                                        labelText: 'Option C (Optional)',
                                        hintText: 'e.g., Platelets',
                                        prefixIcon: Icons.looks_3,
                                        suffixIcon: Icons.clear,
                                        onIconPressed: () {
                                          setState(() {
                                            option3Controller.clear();
                                          });
                                        }
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Option D (Optional)
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'D',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InputTextField(
                                        controller: option4Controller,
                                        onTextChanged: (value) {
                                          setState(() {});
                                        },
                                        labelText: 'Option D (Optional)',
                                        hintText: 'e.g., Plasma',
                                        prefixIcon: Icons.looks_4,
                                        suffixIcon: Icons.clear,
                                        onIconPressed: () {
                                          setState(() {
                                            option4Controller.clear();
                                          });
                                        }
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 15),

                              // IMPROVED ANSWER INPUT - Much simpler!
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '✅ Correct Answer (Super Simple!)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Just type the letter: A, B, C, or D (or A,B for multiple answers)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InputTextField(
                                        controller: answerController,
                                        onTextChanged: (value) {
                                          setState(() {});
                                        },
                                        labelText: 'Correct Answer',
                                        hintText: 'A  (or  A,C  for multiple answers)',
                                        prefixIcon: Icons.check_circle,
                                        suffixIcon: Icons.clear,
                                        onIconPressed: () {
                                          setState(() {
                                            answerController.clear();
                                          });
                                        }
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.info, size: 16, color: Colors.amber.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Examples: "A" for single answer, "A,C" for multiple answers',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.amber.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: selectedType,
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['Single Choice', 'Multiple Choice'].map((String role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(role),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedType = value!;
                                  });
                                },
                              ),

                              const SizedBox(height: 15),

                              BasicButton(
                                text: 'Add',
                                buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                                textColor: Colors.white,
                                onPressed: () {
                                  if (questionTitleController.text.isNotEmpty &&
                                      option1Controller.text.isNotEmpty &&
                                      option2Controller.text.isNotEmpty &&
                                      answerController.text.isNotEmpty) {
                                    addQuestionToExam();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please fill in all required fields.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Professional Exam Creator Button
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigo.shade400, Colors.purple.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.white, size: 24),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Professional Exam Creator',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Advanced features: Multiple question types, analytics, security features, and more!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              BasicButton(
                                text: 'Try Professional Creator',
                                buttonColor: Colors.white,
                                textColor: Colors.indigo.shade700,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfessionalCreateExamScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        BasicButton(
                          text: 'Publish Simple Exam',
                          buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                          textColor: Colors.white,
                          onPressed: () {
                            onSavePressed();
                          }
                        ),

                        const SizedBox(height: 70),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
