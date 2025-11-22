import 'package:cloud_firestore/cloud_firestore.dart';

class ExamService {

  // Save Exam Data
  static Future<void> saveExamData({
    required String examTitle,
    required int timer,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      // Create a reference to a new document
      final docRef = FirebaseFirestore.instance.collection('exams').doc();

      final dataToSave = {
        'id': docRef.id,
        'examTitle': examTitle,
        'timer': timer,
        'items': items,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await docRef.set(dataToSave);
      print("Data saved successfully with ID: ${docRef.id}");
    } catch (e) {
      print("Error saving exam data: $e");
      rethrow;
    }
  }

  // Fetch all exams
  static Future<List<Map<String, dynamic>>> getAllExams() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exams')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'examTitle': doc['examTitle'],
          'timer': doc['timer'],
          'items': doc['items'],
          'timestamp': doc['timestamp'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching exams: $e');
      return [];
    }
  }

  // Delete particular exam
  static Future<void> deleteExamById(String examId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 1. Get the exam document
      final examDoc = await firestore.collection('exams').doc(examId).get();

      if (!examDoc.exists) {
        print("Exam not found");
        return;
      }

      final assignedCaregivers = examDoc.data()?['assignedUsers'] as List<dynamic>? ?? [];

      print("Assigned users: $assignedCaregivers"); // Log the assigned users to check if they are populated

      // 2. Loop through each user and delete the exam from their personal collection
      for (String userId in assignedCaregivers) {
        print("Attempting to delete exam for user: $userId"); // Log before deletion

        final userExamRef = firestore
            .collection('Users')
            .doc(userId)
            .collection('exams')
            .doc(examId);

        try {
          await userExamRef.delete();
          print("Exam deleted for user: $userId"); // Log after deletion

          // 3. Optionally: Remove the examId from user's assignedExamIds array
          await firestore.collection('Users').doc(userId).set({
            'assignedExamIds': FieldValue.arrayRemove([examId]),
          }, SetOptions(merge: true));

          print("Exam removed from assignedExamIds for user: $userId"); // Log after updating the user's assignedExamIds array
        } catch (e) {
          print("Error deleting exam for user $userId: $e"); // Log any error during user exam deletion
        }
      }

      print("Exam removed from all assigned users.");

      await FirebaseFirestore.instance.collection('exams').doc(examId).delete();
    } catch (e) {
      print('Error deleting exam: $e');
    }
  }

  // Assign data to particular person
  static Future<void> assignExamToUser({
    required String userId,
    required String examId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Fetch the exam data
      final examSnapshot = await firestore.collection('exams').doc(examId).get();

      if (!examSnapshot.exists) {
        throw Exception("Exam not found");
      }

      final examData = examSnapshot.data()!;

      // 2. Add 'assignedUsers' field in the original exam (if not already)
      await firestore.collection('exams').doc(examId).update({
        'assignedUsers': FieldValue.arrayUnion([userId])
      });

      // 3. Store exam ID in user's main doc for quick reference
      await firestore.collection('Users').doc(userId).set({
        'assignedExamIds': FieldValue.arrayUnion([examId])
      }, SetOptions(merge: true));

      // 4. Copy full exam into user's personal exams collection
      final userExamRef = firestore
          .collection('Users')
          .doc(userId)
          .collection('exams')
          .doc(examId);

      // Optional: Add empty `selectedOption` field in each item
      List<Map> updatedItems = (examData['items'] as List)
          .map((e) => {
        ...e,
        'selectedOption': null, // Will hold A/B/C/D or whatever later
      })
          .toList();

      final userExamData = {
        ...examData,
        'items': updatedItems,
        'assignedAt': FieldValue.serverTimestamp(),
        'status': 'assigned', // can be used for tracking
      };

      await userExamRef.set(userExamData);

      print("Exam successfully assigned to $userId");

    } catch (e) {
      print("Error assigning exam: $e");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getExamsAssignedToUser(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('exams')
          .orderBy('assignedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(), // includes: examTitle, timer, items, etc.
        };
      }).toList();
    } catch (e) {
      print('Error fetching user exams: $e');
      return [];
    }
  }

  // Copy an existing exam
  static Future<String> copyExam({
    required String examId,
    String? newTitle,
    bool publishImmediately = false,
  }) async {
    try {
      // 1. Get the original exam
      final originalExamDoc = await FirebaseFirestore.instance
          .collection('exams')
          .doc(examId)
          .get();

      if (!originalExamDoc.exists) {
        throw Exception("Original exam not found");
      }

      final originalData = originalExamDoc.data()!;

      // 2. Create new document reference
      final newDocRef = FirebaseFirestore.instance.collection('exams').doc();

      // 3. Prepare new exam data
      final newExamData = {
        'id': newDocRef.id,
        'examTitle': newTitle ?? '${originalData['examTitle']} (Copy)',
        'timer': originalData['timer'],
        'items': originalData['items'], // Copy all questions
        'timestamp': FieldValue.serverTimestamp(),
        'assignedUsers': <String>[], // Reset assigned users for copy
        'isPublished': publishImmediately, // Can be published immediately or kept as draft
        'copiedFrom': examId, // Track the original exam
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4. Save the new exam
      await newDocRef.set(newExamData);

      print("Exam copied successfully. New ID: ${newDocRef.id}");
      return newDocRef.id;

    } catch (e) {
      print("Error copying exam: $e");
      rethrow;
    }
  }

  // Get exam by ID (useful for editing copied exams)
  static Future<Map<String, dynamic>?> getExamById(String examId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('exams')
          .doc(examId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching exam by ID: $e');
      return null;
    }
  }

}
