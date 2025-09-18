import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/models/exam_models.dart';
import 'package:caregiver/services/professional_exam_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class ProfessionalCreateExamScreen extends StatefulWidget {
  const ProfessionalCreateExamScreen({super.key});

  @override
  State<ProfessionalCreateExamScreen> createState() =>
      _ProfessionalCreateExamScreenState();
}

class _ProfessionalCreateExamScreenState
    extends State<ProfessionalCreateExamScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Exam basic info
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  ExamCategory _selectedCategory = ExamCategory.general;
  ExamDifficulty _selectedDifficulty = ExamDifficulty.intermediate;

  // Exam settings
  int _timeLimit = 60;
  int _passingScore = 70;
  bool _randomizeQuestions = false;
  bool _randomizeOptions = false;
  bool _showResultsImmediately = true;
  bool _allowRetake = true;
  int _maxAttempts = 3;
  bool _preventCheating = false;
  bool _blockScreenRecording = false;
  bool _disableCopyPaste = false;
  bool _fullScreenMode = false;
  bool _lockdownBrowser = false;
  bool _webcamProctoring = false;
  int _securityLevel = 1;
  DateTime? _availableFrom;
  DateTime? _availableUntil;

  // Questions
  final List<ExamQuestion> _questions = [];

  // Current question being created
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  QuestionType _currentQuestionType = QuestionType.singleChoice;
  ExamDifficulty _currentQuestionDifficulty = ExamDifficulty.intermediate;
  int _currentQuestionPoints = 1;
  final List<bool> _selectedOptions = [false, false, false, false];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _questionController.dispose();
    _explanationController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addQuestion() {
    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question')),
      );
      return;
    }

    final options = <QuestionOption>[];
    final correctAnswers = <String>[];

    // Create options based on question type
    if (_currentQuestionType == QuestionType.trueFalse) {
      options.addAll([
        QuestionOption(id: 'A', text: 'True', isCorrect: _selectedOptions[0]),
        QuestionOption(id: 'B', text: 'False', isCorrect: _selectedOptions[1]),
      ]);
      if (_selectedOptions[0]) correctAnswers.add('A');
      if (_selectedOptions[1]) correctAnswers.add('B');
    } else if (_currentQuestionType == QuestionType.fillInBlank ||
               _currentQuestionType == QuestionType.essay) {
      // For fill-in-blank and essay, we don't need options
      correctAnswers.add(_optionControllers[0].text.trim());
    } else {
      // Multiple choice or single choice
      for (int i = 0; i < 4; i++) {
        if (_optionControllers[i].text.trim().isNotEmpty) {
          final optionId = String.fromCharCode(65 + i); // A, B, C, D
          options.add(QuestionOption(
            id: optionId,
            text: _optionControllers[i].text.trim(),
            isCorrect: _selectedOptions[i],
          ));
          if (_selectedOptions[i]) {
            correctAnswers.add(optionId);
          }
        }
      }
    }

    // Validate correct answers
    if (correctAnswers.isEmpty &&
        _currentQuestionType != QuestionType.essay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one correct answer')),
      );
      return;
    }

    final question = ExamQuestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      question: _questionController.text.trim(),
      type: _currentQuestionType,
      options: options,
      correctAnswers: correctAnswers,
      explanation: _explanationController.text.trim(),
      points: _currentQuestionPoints,
      difficulty: _currentQuestionDifficulty,
    );

    setState(() {
      _questions.add(question);
      _clearQuestionForm();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Question ${_questions.length} added successfully')),
    );
  }

  void _clearQuestionForm() {
    _questionController.clear();
    _explanationController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    for (int i = 0; i < _selectedOptions.length; i++) {
      _selectedOptions[i] = false;
    }
    _currentQuestionPoints = 1;
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _createExam() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter exam title')),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settings = ExamSettings(
        timeLimit: _timeLimit,
        passingScore: _passingScore,
        randomizeQuestions: _randomizeQuestions,
        randomizeOptions: _randomizeOptions,
        showResultsImmediately: _showResultsImmediately,
        allowRetake: _allowRetake,
        maxAttempts: _maxAttempts,
        preventCheating: _preventCheating,
        blockScreenRecording: _blockScreenRecording,
        disableCopyPaste: _disableCopyPaste,
        fullScreenMode: _fullScreenMode,
        lockdownBrowser: _lockdownBrowser,
        webcamProctoring: _webcamProctoring,
        securityLevel: _securityLevel,
        availableFrom: _availableFrom,
        availableUntil: _availableUntil,
      );

      final exam = ProfessionalExam(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        questions: _questions,
        settings: settings,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        instructions: _instructionsController.text.trim(),
        totalPoints: _questions.fold(0, (sum, q) => sum + q.points),
      );

      await ProfessionalExamService.createExam(exam);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Professional exam created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating exam: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: SafeArea(
        child: Column(
          children: [
            const SettingsAppBar(title: 'Create Professional Exam'),

            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? AppUtils.getColorScheme(context).primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Step labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Basic Info',
                    style: TextStyle(
                      fontWeight: _currentStep == 0 ? FontWeight.bold : FontWeight.normal,
                      color: _currentStep >= 0 ? AppUtils.getColorScheme(context).primary : Colors.grey,
                    ),
                  ),
                  Text('Questions',
                    style: TextStyle(
                      fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _currentStep >= 1 ? AppUtils.getColorScheme(context).primary : Colors.grey,
                    ),
                  ),
                  Text('Settings',
                    style: TextStyle(
                      fontWeight: _currentStep == 2 ? FontWeight.bold : FontWeight.normal,
                      color: _currentStep >= 2 ? AppUtils.getColorScheme(context).primary : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoPage(),
                  _buildQuestionsPage(),
                  _buildSettingsPage(),
                ],
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: BasicButton(
                        text: 'Previous',
                        buttonColor: Colors.grey.shade600,
                        textColor: Colors.white,
                        onPressed: _previousStep,
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: BasicButton(
                      text: _currentStep == 2 ? 'Create Exam' : 'Next',
                      buttonColor: AppUtils.getColorScheme(context).primary,
                      textColor: Colors.white,
                      onPressed: _isLoading ? null :
                        (_currentStep == 2 ? _createExam : _nextStep),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Exam Title *',
              hintText: 'e.g., Medical Procedures Assessment',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Brief description of the exam...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ExamCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: ExamCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ExamDifficulty>(
            value: _selectedDifficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty Level',
              border: OutlineInputBorder(),
            ),
            items: ExamDifficulty.values.map((difficulty) {
              return DropdownMenuItem(
                value: difficulty,
                child: Text(difficulty.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDifficulty = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _instructionsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Instructions for Candidates',
              hintText: 'Special instructions, rules, or notes...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Questions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_questions.length} questions',
                style: TextStyle(
                  fontSize: 16,
                  color: AppUtils.getColorScheme(context).primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Question list
          if (_questions.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppUtils.getColorScheme(context).primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _questions.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${i + 1}. ${_questions[i].question}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_questions[i].type.name.toUpperCase()} • ${_questions[i].points} pts',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeQuestion(i),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Add new question form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Question',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question *',
                    hintText: 'Enter your question here...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<QuestionType>(
                        value: _currentQuestionType,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          border: OutlineInputBorder(),
                        ),
                        items: QuestionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getQuestionTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _currentQuestionType = value!;
                            _clearQuestionForm();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: _currentQuestionPoints.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _currentQuestionPoints = int.tryParse(value) ?? 1;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildQuestionOptionsInput(),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _explanationController,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (Optional)',
                    hintText: 'Explain the correct answer...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),

                BasicButton(
                  text: 'Add Question',
                  buttonColor: AppUtils.getColorScheme(context).primary,
                  textColor: Colors.white,
                  onPressed: _addQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionOptionsInput() {
    switch (_currentQuestionType) {
      case QuestionType.singleChoice:
      case QuestionType.multipleChoice:
        return Column(
          children: [
            Text(
              _currentQuestionType == QuestionType.singleChoice
                  ? 'Options (Select one correct answer):'
                  : 'Options (Select all correct answers):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectedOptions[i],
                      onChanged: (value) {
                        setState(() {
                          if (_currentQuestionType == QuestionType.singleChoice) {
                            // Single choice: clear all others
                            for (int j = 0; j < _selectedOptions.length; j++) {
                              _selectedOptions[j] = j == i ? value! : false;
                            }
                          } else {
                            _selectedOptions[i] = value!;
                          }
                        });
                      },
                    ),
                    Text(String.fromCharCode(65 + i) + '.'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          hintText: 'Option ${String.fromCharCode(65 + i)}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case QuestionType.trueFalse:
        return Column(
          children: [
            const Text('Select the correct answer:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('True'),
                    value: _selectedOptions[0],
                    onChanged: (value) {
                      setState(() {
                        _selectedOptions[0] = value!;
                        _selectedOptions[1] = !value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('False'),
                    value: _selectedOptions[1],
                    onChanged: (value) {
                      setState(() {
                        _selectedOptions[1] = value!;
                        _selectedOptions[0] = !value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case QuestionType.fillInBlank:
        return TextFormField(
          controller: _optionControllers[0],
          decoration: const InputDecoration(
            labelText: 'Correct Answer',
            hintText: 'Enter the correct answer...',
            border: OutlineInputBorder(),
          ),
        );

      case QuestionType.essay:
        return const Text(
          'Essay questions will be manually graded.',
          style: TextStyle(fontStyle: FontStyle.italic),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exam Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Time limit
          Row(
            children: [
              const Expanded(
                child: Text('Time Limit (minutes):', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _timeLimit.toString(),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _timeLimit = int.tryParse(value) ?? 60;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Passing score
          Row(
            children: [
              const Expanded(
                child: Text('Passing Score (%):', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _passingScore.toString(),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _passingScore = int.tryParse(value) ?? 70;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Max attempts
          Row(
            children: [
              const Expanded(
                child: Text('Maximum Attempts:', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _maxAttempts.toString(),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _maxAttempts = int.tryParse(value) ?? 3;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Boolean settings
          SwitchListTile(
            title: const Text('Randomize Questions'),
            subtitle: const Text('Questions will appear in random order'),
            value: _randomizeQuestions,
            onChanged: (value) {
              setState(() {
                _randomizeQuestions = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Randomize Options'),
            subtitle: const Text('Answer options will appear in random order'),
            value: _randomizeOptions,
            onChanged: (value) {
              setState(() {
                _randomizeOptions = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Show Results Immediately'),
            subtitle: const Text('Display results after exam completion'),
            value: _showResultsImmediately,
            onChanged: (value) {
              setState(() {
                _showResultsImmediately = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Allow Retake'),
            subtitle: const Text('Allow multiple attempts'),
            value: _allowRetake,
            onChanged: (value) {
              setState(() {
                _allowRetake = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Security Settings
          const Text(
            'Security & Anti-Cheating',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Security Level Slider
          Row(
            children: [
              const Expanded(
                child: Text('Security Level:', style: TextStyle(fontSize: 16)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: _securityLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _getSecurityLevelLabel(_securityLevel),
                      onChanged: (value) {
                        setState(() {
                          _securityLevel = value.round();
                          _updateSecuritySettings(_securityLevel);
                        });
                      },
                    ),
                    Text(
                      _getSecurityLevelLabel(_securityLevel),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppUtils.getColorScheme(context).primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SwitchListTile(
            title: const Text('Prevent Cheating'),
            subtitle: const Text('Enable basic anti-cheating measures'),
            value: _preventCheating,
            onChanged: (value) {
              setState(() {
                _preventCheating = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Block Screen Recording'),
            subtitle: const Text('Prevent screen recording during exam'),
            value: _blockScreenRecording,
            onChanged: (value) {
              setState(() {
                _blockScreenRecording = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Disable Copy/Paste'),
            subtitle: const Text('Disable clipboard operations'),
            value: _disableCopyPaste,
            onChanged: (value) {
              setState(() {
                _disableCopyPaste = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Full Screen Mode'),
            subtitle: const Text('Force full screen during exam'),
            value: _fullScreenMode,
            onChanged: (value) {
              setState(() {
                _fullScreenMode = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Lockdown Browser'),
            subtitle: const Text('Restrict browser functionality'),
            value: _lockdownBrowser,
            onChanged: (value) {
              setState(() {
                _lockdownBrowser = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Webcam Proctoring'),
            subtitle: const Text('Monitor candidates via webcam'),
            value: _webcamProctoring,
            onChanged: (value) {
              setState(() {
                _webcamProctoring = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUtils.getColorScheme(context).primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exam Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Title: ${_titleController.text.isNotEmpty ? _titleController.text : 'Not set'}'),
                Text('Questions: ${_questions.length}'),
                Text('Total Points: ${_questions.fold(0, (sum, q) => sum + q.points)}'),
                Text('Time Limit: $_timeLimit minutes'),
                Text('Passing Score: $_passingScore%'),
                Text('Category: ${_selectedCategory.name.toUpperCase()}'),
                Text('Difficulty: ${_selectedDifficulty.name.toUpperCase()}'),
                Text('Security Level: ${_getSecurityLevelLabel(_securityLevel)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.fillInBlank:
        return 'Fill in the Blank';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.matching:
        return 'Matching';
      default:
        return 'Unknown';
    }
  }

  String _getSecurityLevelLabel(int level) {
    switch (level) {
      case 1:
        return 'Low Security';
      case 2:
        return 'Basic Security';
      case 3:
        return 'Standard Security';
      case 4:
        return 'High Security';
      case 5:
        return 'Maximum Security';
      default:
        return 'Standard Security';
    }
  }

  void _updateSecuritySettings(int level) {
    switch (level) {
      case 1: // Low Security
        _preventCheating = false;
        _blockScreenRecording = false;
        _disableCopyPaste = false;
        _fullScreenMode = false;
        _lockdownBrowser = false;
        _webcamProctoring = false;
        break;
      case 2: // Basic Security
        _preventCheating = true;
        _blockScreenRecording = false;
        _disableCopyPaste = true;
        _fullScreenMode = false;
        _lockdownBrowser = false;
        _webcamProctoring = false;
        break;
      case 3: // Standard Security
        _preventCheating = true;
        _blockScreenRecording = true;
        _disableCopyPaste = true;
        _fullScreenMode = true;
        _lockdownBrowser = false;
        _webcamProctoring = false;
        break;
      case 4: // High Security
        _preventCheating = true;
        _blockScreenRecording = true;
        _disableCopyPaste = true;
        _fullScreenMode = true;
        _lockdownBrowser = true;
        _webcamProctoring = false;
        break;
      case 5: // Maximum Security
        _preventCheating = true;
        _blockScreenRecording = true;
        _disableCopyPaste = true;
        _fullScreenMode = true;
        _lockdownBrowser = true;
        _webcamProctoring = true;
        break;
    }
  }
}