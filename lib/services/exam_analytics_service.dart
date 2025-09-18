import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_models.dart';

class ExamAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get comprehensive exam analytics
  static Future<Map<String, dynamic>> getExamAnalytics(String examId) async {
    try {
      final exam = await _getExamData(examId);
      final results = await _getExamResults(examId);
      final userPerformance = await _getUserPerformance(examId);
      final questionAnalytics = await _getQuestionAnalytics(examId, results);
      final timeAnalytics = await _getTimeAnalytics(results);

      return {
        'exam': exam,
        'overview': _calculateOverviewStats(results),
        'userPerformance': userPerformance,
        'questionAnalytics': questionAnalytics,
        'timeAnalytics': timeAnalytics,
        'difficultyBreakdown': _calculateDifficultyBreakdown(exam, results),
        'passFailTrends': _calculatePassFailTrends(results),
        'improvementSuggestions': _generateImprovementSuggestions(exam, results),
      };
    } catch (e) {
      print('Error getting exam analytics: $e');
      return {};
    }
  }

  // Get exam data
  static Future<ProfessionalExam?> _getExamData(String examId) async {
    try {
      final doc = await _firestore
          .collection('professional_exams')
          .doc(examId)
          .get();

      if (doc.exists) {
        return ProfessionalExam.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching exam data: $e');
      return null;
    }
  }

  // Get all exam results
  static Future<List<Map<String, dynamic>>> _getExamResults(String examId) async {
    try {
      final snapshot = await _firestore
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching exam results: $e');
      return [];
    }
  }

  // Calculate overview statistics
  static Map<String, dynamic> _calculateOverviewStats(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return {
        'totalAttempts': 0,
        'uniqueUsers': 0,
        'averageScore': 0.0,
        'passRate': 0.0,
        'highestScore': 0,
        'lowestScore': 0,
        'medianScore': 0.0,
        'completionRate': 0.0,
      };
    }

    final scores = results
        .where((r) => r['status'] == 'completed')
        .map((r) => (r['score'] as num).toDouble())
        .toList();

    final uniqueUsers = results.map((r) => r['userId']).toSet().length;
    final completedAttempts = scores.length;
    final totalAttempts = results.length;

    scores.sort();
    final passedCount = scores.where((score) => score >= 70).length; // Default passing score

    return {
      'totalAttempts': totalAttempts,
      'uniqueUsers': uniqueUsers,
      'averageScore': scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0,
      'passRate': scores.isNotEmpty ? (passedCount / scores.length) * 100 : 0.0,
      'highestScore': scores.isNotEmpty ? scores.last : 0,
      'lowestScore': scores.isNotEmpty ? scores.first : 0,
      'medianScore': scores.isNotEmpty ? _calculateMedian(scores) : 0.0,
      'completionRate': totalAttempts > 0 ? (completedAttempts / totalAttempts) * 100 : 0.0,
    };
  }

  // Get user performance data
  static Future<List<Map<String, dynamic>>> _getUserPerformance(String examId) async {
    try {
      final results = await _getExamResults(examId);
      final userStats = <String, Map<String, dynamic>>{};

      for (var result in results) {
        final userId = result['userId'] as String;

        if (!userStats.containsKey(userId)) {
          userStats[userId] = {
            'userId': userId,
            'userName': result['userName'] ?? 'Unknown User',
            'attempts': 0,
            'bestScore': 0.0,
            'averageScore': 0.0,
            'totalTime': 0,
            'scores': <double>[],
            'lastAttempt': null,
          };
        }

        final userStat = userStats[userId]!;
        userStat['attempts']++;

        if (result['status'] == 'completed') {
          final score = (result['score'] as num).toDouble();
          userStat['scores'].add(score);
          userStat['bestScore'] = score > userStat['bestScore'] ? score : userStat['bestScore'];
          userStat['totalTime'] += result['timeSpent'] ?? 0;
          userStat['lastAttempt'] = result['submittedAt'];
        }
      }

      // Calculate average scores
      for (var userStat in userStats.values) {
        final scores = userStat['scores'] as List<double>;
        if (scores.isNotEmpty) {
          userStat['averageScore'] = scores.reduce((a, b) => a + b) / scores.length;
        }
      }

      return userStats.values.toList();
    } catch (e) {
      print('Error getting user performance: $e');
      return [];
    }
  }

  // Get question-level analytics
  static Future<List<Map<String, dynamic>>> _getQuestionAnalytics(
      String examId, List<Map<String, dynamic>> results) async {
    try {
      final exam = await _getExamData(examId);
      if (exam == null) return [];

      final questionStats = <String, Map<String, dynamic>>{};

      // Initialize stats for each question
      for (var question in exam.questions) {
        questionStats[question.id] = {
          'questionId': question.id,
          'question': question.question,
          'type': question.type.name,
          'difficulty': question.difficulty.name,
          'points': question.points,
          'totalAttempts': 0,
          'correctAnswers': 0,
          'incorrectAnswers': 0,
          'skippedAnswers': 0,
          'averageTime': 0.0,
          'difficultyIndex': 0.0,
          'discriminationIndex': 0.0,
        };
      }

      // Analyze each result
      for (var result in results) {
        if (result['status'] != 'completed') continue;

        final answers = result['answers'] as Map<String, dynamic>? ?? {};
        final questionTimes = result['questionTimes'] as Map<String, dynamic>? ?? {};

        for (var questionId in questionStats.keys) {
          final stat = questionStats[questionId]!;
          stat['totalAttempts']++;

          if (answers.containsKey(questionId)) {
            final isCorrect = answers[questionId]['isCorrect'] ?? false;
            if (isCorrect) {
              stat['correctAnswers']++;
            } else {
              stat['incorrectAnswers']++;
            }
          } else {
            stat['skippedAnswers']++;
          }

          // Add time data
          if (questionTimes.containsKey(questionId)) {
            final timeSpent = questionTimes[questionId] as num;
            stat['averageTime'] = (stat['averageTime'] * (stat['totalAttempts'] - 1) + timeSpent) / stat['totalAttempts'];
          }
        }
      }

      // Calculate indices
      for (var stat in questionStats.values) {
        if (stat['totalAttempts'] > 0) {
          stat['difficultyIndex'] = stat['correctAnswers'] / stat['totalAttempts'];
          // Simplified discrimination index calculation
          stat['discriminationIndex'] = _calculateDiscriminationIndex(stat);
        }
      }

      return questionStats.values.toList();
    } catch (e) {
      print('Error getting question analytics: $e');
      return [];
    }
  }

  // Get time analytics
  static Future<Map<String, dynamic>> _getTimeAnalytics(List<Map<String, dynamic>> results) async {
    final completedResults = results.where((r) => r['status'] == 'completed').toList();

    if (completedResults.isEmpty) {
      return {
        'averageCompletionTime': 0.0,
        'fastestCompletion': 0,
        'slowestCompletion': 0,
        'timeDistribution': <String, int>{},
      };
    }

    final times = completedResults
        .map((r) => (r['timeSpent'] as num?)?.toInt() ?? 0)
        .where((t) => t > 0)
        .toList();

    if (times.isEmpty) {
      return {
        'averageCompletionTime': 0.0,
        'fastestCompletion': 0,
        'slowestCompletion': 0,
        'timeDistribution': <String, int>{},
      };
    }

    times.sort();

    return {
      'averageCompletionTime': times.reduce((a, b) => a + b) / times.length,
      'fastestCompletion': times.first,
      'slowestCompletion': times.last,
      'medianTime': _calculateMedian(times.map((t) => t.toDouble()).toList()),
      'timeDistribution': _calculateTimeDistribution(times),
    };
  }

  // Calculate difficulty breakdown
  static Map<String, dynamic> _calculateDifficultyBreakdown(
      ProfessionalExam? exam, List<Map<String, dynamic>> results) {
    if (exam == null) return {};

    final difficultyStats = <String, Map<String, dynamic>>{};

    for (var difficulty in ExamDifficulty.values) {
      difficultyStats[difficulty.name] = {
        'totalQuestions': 0,
        'averageScore': 0.0,
        'passRate': 0.0,
      };
    }

    // Count questions by difficulty
    for (var question in exam.questions) {
      difficultyStats[question.difficulty.name]!['totalQuestions']++;
    }

    return difficultyStats;
  }

  // Calculate pass/fail trends over time
  static List<Map<String, dynamic>> _calculatePassFailTrends(List<Map<String, dynamic>> results) {
    final trends = <Map<String, dynamic>>[];
    final dailyStats = <String, Map<String, int>>{};

    for (var result in results) {
      if (result['status'] != 'completed') continue;

      final submittedAt = DateTime.parse(result['submittedAt']);
      final date = '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}';

      if (!dailyStats.containsKey(date)) {
        dailyStats[date] = {'passed': 0, 'failed': 0};
      }

      final score = (result['score'] as num).toDouble();
      if (score >= 70) { // Default passing score
        dailyStats[date]!['passed']++;
      } else {
        dailyStats[date]!['failed']++;
      }
    }

    for (var entry in dailyStats.entries) {
      trends.add({
        'date': entry.key,
        'passed': entry.value['passed'],
        'failed': entry.value['failed'],
        'total': entry.value['passed']! + entry.value['failed']!,
      });
    }

    trends.sort((a, b) => a['date'].compareTo(b['date']));
    return trends;
  }

  // Generate improvement suggestions
  static List<String> _generateImprovementSuggestions(
      ProfessionalExam? exam, List<Map<String, dynamic>> results) {
    final suggestions = <String>[];

    if (exam == null || results.isEmpty) {
      return ['Insufficient data for suggestions'];
    }

    final overview = _calculateOverviewStats(results);
    final passRate = overview['passRate'] as double;
    final completionRate = overview['completionRate'] as double;

    if (passRate < 50) {
      suggestions.add('Consider reviewing exam difficulty - pass rate is below 50%');
    }

    if (completionRate < 80) {
      suggestions.add('Many students are not completing the exam - consider reducing length or time pressure');
    }

    if (exam.questions.length < 10) {
      suggestions.add('Consider adding more questions for better assessment reliability');
    }

    if (exam.settings.timeLimit < 60) {
      suggestions.add('Consider increasing time limit to reduce time pressure');
    }

    return suggestions.isEmpty ? ['Exam performance looks good!'] : suggestions;
  }

  // Helper methods
  static double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    values.sort();
    final middle = values.length ~/ 2;
    if (values.length % 2 == 0) {
      return (values[middle - 1] + values[middle]) / 2;
    } else {
      return values[middle];
    }
  }

  static double _calculateDiscriminationIndex(Map<String, dynamic> questionStat) {
    final totalAttempts = questionStat['totalAttempts'] as int;
    final correctAnswers = questionStat['correctAnswers'] as int;

    if (totalAttempts == 0) return 0.0;

    // Simplified calculation - in practice, you'd compare high vs low performers
    final accuracy = correctAnswers / totalAttempts;
    return accuracy > 0.8 ? 0.9 : (accuracy < 0.2 ? 0.1 : 0.5);
  }

  static Map<String, int> _calculateTimeDistribution(List<int> times) {
    final distribution = <String, int>{};

    for (var time in times) {
      final bucket = ((time / 300).floor() * 5).toString(); // 5-minute buckets
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }

    return distribution;
  }
}