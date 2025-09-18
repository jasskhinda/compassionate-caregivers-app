import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exam_models.dart';

class ProfessionalExamService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new professional exam
  static Future<String> createExam(ProfessionalExam exam) async {
    try {
      final docRef = _firestore.collection('professional_exams').doc();
      final examWithId = exam.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(examWithId.toMap());
      print('Professional exam created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating professional exam: $e');
      rethrow;
    }
  }

  // Update an existing exam
  static Future<void> updateExam(ProfessionalExam exam) async {
    try {
      final updatedExam = exam.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('professional_exams')
          .doc(exam.id)
          .update(updatedExam.toMap());
      print('Professional exam updated: ${exam.id}');
    } catch (e) {
      print('Error updating professional exam: $e');
      rethrow;
    }
  }

  // Get all exams
  static Future<List<ProfessionalExam>> getAllExams() async {
    try {
      final snapshot = await _firestore
          .collection('professional_exams')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProfessionalExam.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching professional exams: $e');
      return [];
    }
  }

  // Get exam by ID
  static Future<ProfessionalExam?> getExamById(String examId) async {
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
      print('Error fetching exam: $e');
      return null;
    }
  }

  // Get exams by category
  static Future<List<ProfessionalExam>> getExamsByCategory(
      ExamCategory category) async {
    try {
      final snapshot = await _firestore
          .collection('professional_exams')
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProfessionalExam.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching exams by category: $e');
      return [];
    }
  }

  // Get exams created by user
  static Future<List<ProfessionalExam>> getExamsByCreator(
      String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection('professional_exams')
          .where('createdBy', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProfessionalExam.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching exams by creator: $e');
      return [];
    }
  }

  // Delete exam
  static Future<void> deleteExam(String examId) async {
    try {
      // First, remove exam from all assigned users
      final exam = await getExamById(examId);
      if (exam != null && exam.assignedUsers.isNotEmpty) {
        final batch = _firestore.batch();

        for (String userId in exam.assignedUsers) {
          final userExamRef = _firestore
              .collection('Users')
              .doc(userId)
              .collection('professional_exams')
              .doc(examId);

          batch.delete(userExamRef);

          // Remove from user's assigned exam list
          final userRef = _firestore.collection('Users').doc(userId);
          batch.update(userRef, {
            'assignedProfessionalExamIds': FieldValue.arrayRemove([examId])
          });
        }

        await batch.commit();
      }

      // Delete the main exam document
      await _firestore.collection('professional_exams').doc(examId).delete();

      // Delete all exam results
      final resultsSnapshot = await _firestore
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .get();

      final resultsBatch = _firestore.batch();
      for (var doc in resultsSnapshot.docs) {
        resultsBatch.delete(doc.reference);
      }
      await resultsBatch.commit();

      print('Professional exam deleted: $examId');
    } catch (e) {
      print('Error deleting professional exam: $e');
      rethrow;
    }
  }

  // Publish exam
  static Future<void> publishExam(String examId) async {
    try {
      await _firestore
          .collection('professional_exams')
          .doc(examId)
          .update({
        'isPublished': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      print('Exam published: $examId');
    } catch (e) {
      print('Error publishing exam: $e');
      rethrow;
    }
  }

  // Assign exam to users
  static Future<void> assignExamToUsers(
      String examId, List<String> userIds) async {
    try {
      final batch = _firestore.batch();
      final exam = await getExamById(examId);

      if (exam == null) {
        throw Exception('Exam not found');
      }

      // Update the main exam document
      final examRef = _firestore.collection('professional_exams').doc(examId);
      batch.update(examRef, {
        'assignedUsers': FieldValue.arrayUnion(userIds),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Add exam to each user's collection
      for (String userId in userIds) {
        final userExamRef = _firestore
            .collection('Users')
            .doc(userId)
            .collection('professional_exams')
            .doc(examId);

        batch.set(userExamRef, {
          'examId': examId,
          'examTitle': exam.title,
          'assignedAt': DateTime.now().toIso8601String(),
          'status': 'assigned',
          'attempts': 0,
          'maxAttempts': exam.settings.maxAttempts,
          'bestScore': 0,
        });

        // Add to user's assigned exam list
        final userRef = _firestore.collection('Users').doc(userId);
        batch.update(userRef, {
          'assignedProfessionalExamIds': FieldValue.arrayUnion([examId])
        });
      }

      await batch.commit();
      print('Exam assigned to ${userIds.length} users');
    } catch (e) {
      print('Error assigning exam: $e');
      rethrow;
    }
  }

  // Get exam statistics
  static Future<Map<String, dynamic>> getExamStatistics(
      String examId) async {
    try {
      final resultsSnapshot = await _firestore
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .get();

      if (resultsSnapshot.docs.isEmpty) {
        return {
          'totalAttempts': 0,
          'averageScore': 0.0,
          'passRate': 0.0,
          'highestScore': 0,
          'lowestScore': 0,
        };
      }

      final scores = resultsSnapshot.docs
          .map((doc) => (doc.data()['score'] as num).toDouble())
          .toList();

      final exam = await getExamById(examId);
      final passingScore = exam?.settings.passingScore ?? 70;
      final passedCount = scores.where((score) => score >= passingScore).length;

      return {
        'totalAttempts': scores.length,
        'averageScore': scores.reduce((a, b) => a + b) / scores.length,
        'passRate': (passedCount / scores.length) * 100,
        'highestScore': scores.reduce((a, b) => a > b ? a : b),
        'lowestScore': scores.reduce((a, b) => a < b ? a : b),
        'passedCount': passedCount,
        'failedCount': scores.length - passedCount,
      };
    } catch (e) {
      print('Error getting exam statistics: $e');
      return {};
    }
  }

  // Search exams
  static Future<List<ProfessionalExam>> searchExams(String query) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a simple implementation using title search
      final snapshot = await _firestore
          .collection('professional_exams')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .get();

      return snapshot.docs
          .map((doc) => ProfessionalExam.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error searching exams: $e');
      return [];
    }
  }

  // Get exam templates
  static Future<List<ProfessionalExam>> getExamTemplates() async {
    try {
      final snapshot = await _firestore
          .collection('professional_exam_templates')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProfessionalExam.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching exam templates: $e');
      return [];
    }
  }

  // Create exam from template
  static Future<String> createExamFromTemplate(
      String templateId, String newTitle) async {
    try {
      final template = await _firestore
          .collection('professional_exam_templates')
          .doc(templateId)
          .get();

      if (!template.exists) {
        throw Exception('Template not found');
      }

      final templateData = template.data()!;
      final newExam = ProfessionalExam.fromMap(templateData).copyWith(
        title: newTitle,
        createdBy: _auth.currentUser?.uid ?? '',
        isPublished: false,
        assignedUsers: [],
      );

      return await createExam(newExam);
    } catch (e) {
      print('Error creating exam from template: $e');
      rethrow;
    }
  }

  // Copy an existing professional exam
  static Future<String> copyExam({
    required String examId,
    String? newTitle,
    bool publishImmediately = false,
  }) async {
    try {
      final originalExam = await getExamById(examId);
      if (originalExam == null) {
        throw Exception('Original exam not found');
      }

      final newExam = originalExam.copyWith(
        id: '', // Will be set by createExam
        title: newTitle ?? '${originalExam.title} (Copy)',
        createdBy: _auth.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPublished: publishImmediately,
        assignedUsers: [], // Reset assigned users for copy
      );

      final newExamId = await createExam(newExam);
      print('Professional exam copied successfully. New ID: $newExamId');
      return newExamId;

    } catch (e) {
      print('Error copying professional exam: $e');
      rethrow;
    }
  }
}