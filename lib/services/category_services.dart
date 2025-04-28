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
}