import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryServices {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new category
  Future<void> createCategory(String name) async {
    final docRef = _db.collection('categories').doc(name);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  // Create a new subcategory under a specific category
  Future<void> createSubcategory(String categoryName, String subcategoryName) async {
    final subcategoryRef = _db
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName);

    final doc = await subcategoryRef.get();
    if (!doc.exists) {
      await subcategoryRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  // Add a video under a subcategory
  Future<void> addVideo({
    required String categoryName,
    required String subcategoryName,
    required String title,
    required String youtubeLink,
    required DateTime uploadedAt,
    required bool isVimeo
  }) async {
    final videoRef = _db
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName)
        .collection('videos')
        .doc();

    await videoRef.set({
      'videoId': videoRef.id,
      'title': title,
      'youtubeLink': youtubeLink,
      'uploadedAt': uploadedAt,
      'isVimeo': isVimeo
    });
  }

  // Stream of categories
  Stream<QuerySnapshot> getCategories() {
    return _db.collection('categories').snapshots();
  }

  // Stream of subcategories
  Stream<QuerySnapshot> getSubcategories(String categoryName) {
    return _db
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .snapshots();
  }

  // Stream of videos
  Stream<QuerySnapshot> getVideos(String categoryName, String subcategoryName) {
    return _db
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName)
        .collection('videos')
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> getAssignedVideosForCaregiver(String uid, String categoryName, String subcategoryName) {
    final videosStream = _db
        .collection('categories')
        .doc(categoryName)
        .collection('subcategories')
        .doc(subcategoryName)
        .collection('videos')
        .snapshots();

    return videosStream.asyncMap((snapshot) async {
      final docs = snapshot.docs;

      final assignedVideoIds = docs
          .where((doc) =>
      doc.data().containsKey('assignedTo') &&
          (doc.data()['assignedTo'] as List).contains(uid))
          .map((doc) => doc.id)
          .toSet();

      final publicVideoIds = docs
          .where((doc) =>
      doc.data().containsKey('isVimeo') &&
          doc.data()['isVimeo'] == false)
          .map((doc) => doc.id)
          .toSet();

      final allRelevantVideoIds = {...assignedVideoIds, ...publicVideoIds};

      if (allRelevantVideoIds.isEmpty) return [];

      final results = await Future.wait(
        allRelevantVideoIds.map((videoId) async {
          final originalDoc = docs.firstWhere((doc) => doc.id == videoId);
          final originalData = originalDoc.data();

          final isVimeo = originalData['isVimeo'] ?? false;

          if (assignedVideoIds.contains(videoId)) {
            final caregiverDoc = await _db
                .collection('caregiver_videos')
                .doc(uid)
                .collection('videos')
                .doc(videoId)
                .get();

            if (caregiverDoc.exists) {
              final data = caregiverDoc.data() as Map<String, dynamic>;
              return <String, dynamic>{
                'videoId': videoId,
                'title': data['title'],
                'videoUrl': data['youtubeLink'],
                'progress': data['progress'] ?? 0,
                'assignedBy': data['assignedBy'],
                'assignedTo': data['assignedTo'],
                'assignedDate': data['assignedDate'],
                'isVimeo': isVimeo
              };
            }
          }

          if (publicVideoIds.contains(videoId)) {
            return <String, dynamic>{
              'videoId': videoId,
              'title': originalData['title'],
              'videoUrl': originalData['youtubeLink'],
              'isVimeo': isVimeo
            };
          }

          return <String, dynamic>{};
        }).toList(),
      );

      return results.where((video) => video.isNotEmpty).toList();
    });
  }

}