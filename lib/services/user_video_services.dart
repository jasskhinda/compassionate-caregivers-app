import 'package:cloud_firestore/cloud_firestore.dart';

class UserVideoServices{
  // Get instance of firestore & auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getAssignedVideosForCaregiver(String caregiverUid) {
    return _firestore.collection("caregiver_videos")
        .doc(caregiverUid)
        .collection("videos")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getAssignedCaregiverVideos(String categoryName, String subcategoryName, String videoId) {
    final subcategoryRef = _firestore
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName)
        .collection('videos')
        .doc(videoId);

    return subcategoryRef.snapshots().asyncMap((docSnapshot) async {
      final data = docSnapshot.data();
      if (data == null || data['assignedTo'] == null) return [];

      final assignedTo = List<String>.from(data['assignedTo']);

      final futures = assignedTo.map((uid) async {
        // Get caregiver details from Users collection
        final caregiverDoc = await _firestore.collection('Users').doc(uid).get();
        final caregiverData = caregiverDoc.data() ?? {};
        final caregiverName = caregiverData['name'] ?? 'Unknown';
        final profilePicture = caregiverData['profile_image_url'] ?? '';

        // Get video progress
        final videoDoc = await _firestore
            .collection('caregiver_videos')
            .doc(uid)
            .collection('videos')
            .doc(videoId)
            .get();

        final videoData = videoDoc.data() ?? {};
        final progress = videoData['progress'] ?? 0.0;

        return {
          'caregiverName': caregiverName,
          'profilePicture': profilePicture,
          'progress': progress,
          'caregiverId': uid,
        };
      });

      return await Future.wait(futures);
    });
  }

}