// Professional Exam System Models

enum QuestionType {
  singleChoice,
  multipleChoice,
  trueFalse,
  fillInBlank,
  essay,
  matching
}

enum ExamDifficulty {
  beginner,
  intermediate,
  advanced,
  expert
}

enum ExamCategory {
  medical,
  nursing,
  caregiving,
  safety,
  procedures,
  regulations,
  general
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCorrect': isCorrect,
    };
  }

  factory QuestionOption.fromMap(Map<String, dynamic> map) {
    return QuestionOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
    );
  }
}

class ExamQuestion {
  final String id;
  final String question;
  final QuestionType type;
  final List<QuestionOption> options;
  final List<String> correctAnswers;
  final String explanation;
  final int points;
  final ExamDifficulty difficulty;
  final List<String> tags;
  final String imageUrl;

  ExamQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.correctAnswers = const [],
    this.explanation = '',
    this.points = 1,
    this.difficulty = ExamDifficulty.intermediate,
    this.tags = const [],
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'type': type.name,
      'options': options.map((x) => x.toMap()).toList(),
      'correctAnswers': correctAnswers,
      'explanation': explanation,
      'points': points,
      'difficulty': difficulty.name,
      'tags': tags,
      'imageUrl': imageUrl,
    };
  }

  factory ExamQuestion.fromMap(Map<String, dynamic> map) {
    return ExamQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => QuestionType.singleChoice,
      ),
      options: List<QuestionOption>.from(
        map['options']?.map((x) => QuestionOption.fromMap(x)) ?? [],
      ),
      correctAnswers: List<String>.from(map['correctAnswers'] ?? []),
      explanation: map['explanation'] ?? '',
      points: map['points']?.toInt() ?? 1,
      difficulty: ExamDifficulty.values.firstWhere(
        (e) => e.name == map['difficulty'],
        orElse: () => ExamDifficulty.intermediate,
      ),
      tags: List<String>.from(map['tags'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}

class ExamSettings {
  final int timeLimit; // in minutes
  final int passingScore; // percentage
  final bool randomizeQuestions;
  final bool randomizeOptions;
  final bool showResultsImmediately;
  final bool allowRetake;
  final int maxAttempts;
  final bool preventCheating;
  final bool requireAuthentication;
  final bool blockScreenRecording;
  final bool disableCopyPaste;
  final bool fullScreenMode;
  final bool lockdownBrowser;
  final bool webcamProctoring;
  final int securityLevel; // 1-5 (low to high)
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  ExamSettings({
    this.timeLimit = 60,
    this.passingScore = 70,
    this.randomizeQuestions = false,
    this.randomizeOptions = false,
    this.showResultsImmediately = true,
    this.allowRetake = true,
    this.maxAttempts = 3,
    this.preventCheating = false,
    this.requireAuthentication = true,
    this.blockScreenRecording = false,
    this.disableCopyPaste = false,
    this.fullScreenMode = false,
    this.lockdownBrowser = false,
    this.webcamProctoring = false,
    this.securityLevel = 1,
    this.availableFrom,
    this.availableUntil,
  });

  Map<String, dynamic> toMap() {
    return {
      'timeLimit': timeLimit,
      'passingScore': passingScore,
      'randomizeQuestions': randomizeQuestions,
      'randomizeOptions': randomizeOptions,
      'showResultsImmediately': showResultsImmediately,
      'allowRetake': allowRetake,
      'maxAttempts': maxAttempts,
      'preventCheating': preventCheating,
      'requireAuthentication': requireAuthentication,
      'blockScreenRecording': blockScreenRecording,
      'disableCopyPaste': disableCopyPaste,
      'fullScreenMode': fullScreenMode,
      'lockdownBrowser': lockdownBrowser,
      'webcamProctoring': webcamProctoring,
      'securityLevel': securityLevel,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableUntil': availableUntil?.toIso8601String(),
    };
  }

  factory ExamSettings.fromMap(Map<String, dynamic> map) {
    return ExamSettings(
      timeLimit: map['timeLimit']?.toInt() ?? 60,
      passingScore: map['passingScore']?.toInt() ?? 70,
      randomizeQuestions: map['randomizeQuestions'] ?? false,
      randomizeOptions: map['randomizeOptions'] ?? false,
      showResultsImmediately: map['showResultsImmediately'] ?? true,
      allowRetake: map['allowRetake'] ?? true,
      maxAttempts: map['maxAttempts']?.toInt() ?? 3,
      preventCheating: map['preventCheating'] ?? false,
      requireAuthentication: map['requireAuthentication'] ?? true,
      blockScreenRecording: map['blockScreenRecording'] ?? false,
      disableCopyPaste: map['disableCopyPaste'] ?? false,
      fullScreenMode: map['fullScreenMode'] ?? false,
      lockdownBrowser: map['lockdownBrowser'] ?? false,
      webcamProctoring: map['webcamProctoring'] ?? false,
      securityLevel: map['securityLevel']?.toInt() ?? 1,
      availableFrom: map['availableFrom'] != null
          ? DateTime.parse(map['availableFrom'])
          : null,
      availableUntil: map['availableUntil'] != null
          ? DateTime.parse(map['availableUntil'])
          : null,
    );
  }
}

class ProfessionalExam {
  final String id;
  final String title;
  final String description;
  final ExamCategory category;
  final ExamDifficulty difficulty;
  final List<ExamQuestion> questions;
  final ExamSettings settings;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublished;
  final List<String> assignedUsers;
  final String instructions;
  final int totalPoints;

  ProfessionalExam({
    required this.id,
    required this.title,
    this.description = '',
    this.category = ExamCategory.general,
    this.difficulty = ExamDifficulty.intermediate,
    this.questions = const [],
    required this.settings,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isPublished = false,
    this.assignedUsers = const [],
    this.instructions = '',
    this.totalPoints = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'difficulty': difficulty.name,
      'questions': questions.map((x) => x.toMap()).toList(),
      'settings': settings.toMap(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPublished': isPublished,
      'assignedUsers': assignedUsers,
      'instructions': instructions,
      'totalPoints': totalPoints,
    };
  }

  factory ProfessionalExam.fromMap(Map<String, dynamic> map) {
    return ProfessionalExam(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: ExamCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ExamCategory.general,
      ),
      difficulty: ExamDifficulty.values.firstWhere(
        (e) => e.name == map['difficulty'],
        orElse: () => ExamDifficulty.intermediate,
      ),
      questions: List<ExamQuestion>.from(
        map['questions']?.map((x) => ExamQuestion.fromMap(x)) ?? [],
      ),
      settings: ExamSettings.fromMap(map['settings'] ?? {}),
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isPublished: map['isPublished'] ?? false,
      assignedUsers: List<String>.from(map['assignedUsers'] ?? []),
      instructions: map['instructions'] ?? '',
      totalPoints: map['totalPoints']?.toInt() ?? 0,
    );
  }

  ProfessionalExam copyWith({
    String? id,
    String? title,
    String? description,
    ExamCategory? category,
    ExamDifficulty? difficulty,
    List<ExamQuestion>? questions,
    ExamSettings? settings,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    List<String>? assignedUsers,
    String? instructions,
    int? totalPoints,
  }) {
    return ProfessionalExam(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      questions: questions ?? this.questions,
      settings: settings ?? this.settings,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      assignedUsers: assignedUsers ?? this.assignedUsers,
      instructions: instructions ?? this.instructions,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
}