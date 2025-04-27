import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/theme/theme.dart';

class ThemeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemeData _themeData = lightMode;

  ThemeProvider() {
    _loadUserTheme();
  }

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == darkMode;

  String? get userId => _auth.currentUser?.uid;

  // Load theme from Firestore
  Future<void> _loadUserTheme() async {
    if (userId == null) return; // Safety check if user is not logged in

    try {
      DocumentSnapshot userDoc = await _firestore.collection('Users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        bool? isDark = data['isDark'] as bool?;
        if (isDark != null) {
          _themeData = isDark ? darkMode : lightMode;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  // Toggle theme and update Firestore
  Future<void> toggleTheme() async {
    if (userId == null) return; // Safety check

    _themeData = isDarkMode ? lightMode : darkMode;
    notifyListeners();

    try {
      await _firestore.collection('Users').doc(userId).set({
        'isDark': isDarkMode,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating theme: $e');
    }
  }
}
