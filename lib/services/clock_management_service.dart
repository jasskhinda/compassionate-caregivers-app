import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'night_shift_monitoring_service.dart';

class ClockManagementService {
  static final ClockManagementService _instance = ClockManagementService._internal();
  factory ClockManagementService() => _instance;
  ClockManagementService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NightShiftMonitoringService _nightShiftService = NightShiftMonitoringService();

  // Auto clock-out when user logs out
  Future<void> autoClockOutOnLogout() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user is currently clocked in
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData != null && userData['is_clocked_in'] == true) {
        final userName = userData['name'] ?? 'Unknown';
        final role = userData['role'] ?? '';
        final shiftType = userData['shift_type'];

        // Clock out the user
        await _firestore.collection('Users').doc(user.uid).update({
          'is_clocked_in': false,
          'last_clock_out_time': FieldValue.serverTimestamp(),
          'auto_clock_out_reason': 'logout',
        });

        // Update attendance record
        final today = DateTime.now().toIso8601String().split('T')[0];
        final attendanceQuery = await _firestore
            .collection('attendance')
            .where('user_id', isEqualTo: user.uid)
            .where('date', isEqualTo: today)
            .orderBy('clock_in_time', descending: true)
            .limit(1)
            .get();

        if (attendanceQuery.docs.isNotEmpty) {
          await attendanceQuery.docs.first.reference.update({
            'clock_out_time': FieldValue.serverTimestamp(),
            'clock_out_type': 'auto_logout',
          });
        }

        // Create admin notification
        await _firestore.collection('admin_alerts').add({
          'type': 'night_shift_clock_out',
          'caregiver_id': user.uid,
          'caregiver_name': userName,
          'message': '$userName automatically clocked out (logout)',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'status': 'clocked_out',
          'clock_out_time': FieldValue.serverTimestamp(),
          'clock_out_type': 'auto_logout',
          'reason': 'Application logout',
        });

        // Stop night shift monitoring if applicable
        if (role == 'Caregiver' && shiftType == 'Night') {
          _nightShiftService.stopMonitoring();
        }

        debugPrint('✅ Auto clock-out completed for $userName (logout)');
      }
    } catch (e) {
      debugPrint('❌ Error during auto clock-out: $e');
    }
  }

  // Manual clock-in
  Future<bool> clockIn(String userName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('Users').doc(user.uid).set({
        'is_clocked_in': true,
        'last_clock_in_time': FieldValue.serverTimestamp(),
        'manual_clock_in': true,
      }, SetOptions(merge: true));

      // Create attendance record
      await _firestore.collection('attendance').add({
        'user_id': user.uid,
        'user_name': userName,
        'clock_in_time': FieldValue.serverTimestamp(),
        'type': 'manual_clock_in',
        'date': DateTime.now().toIso8601String().split('T')[0],
      });

      // Create admin notification
      await _firestore.collection('admin_alerts').add({
        'type': 'night_shift_clock_in',
        'caregiver_id': user.uid,
        'caregiver_name': userName,
        'message': '$userName manually clocked in',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'clocked_in',
        'clock_in_time': FieldValue.serverTimestamp(),
        'clock_in_type': 'manual',
        'source': 'clock_management_tab',
      });

      return true;
    } catch (e) {
      debugPrint('❌ Clock-in error: $e');
      return false;
    }
  }

  // Manual clock-out
  Future<bool> clockOut(String userName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('Users').doc(user.uid).set({
        'is_clocked_in': false,
        'last_clock_out_time': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update attendance record
      final today = DateTime.now().toIso8601String().split('T')[0];
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('user_id', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .orderBy('clock_in_time', descending: true)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        await attendanceQuery.docs.first.reference.update({
          'clock_out_time': FieldValue.serverTimestamp(),
          'clock_out_type': 'manual',
        });
      }

      // Create admin notification
      await _firestore.collection('admin_alerts').add({
        'type': 'night_shift_clock_out',
        'caregiver_id': user.uid,
        'caregiver_name': userName,
        'message': '$userName manually clocked out',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'clocked_out',
        'clock_out_time': FieldValue.serverTimestamp(),
        'clock_out_type': 'manual',
        'source': 'clock_management_tab',
      });

      // Stop night shift monitoring
      _nightShiftService.stopMonitoring();

      return true;
    } catch (e) {
      debugPrint('❌ Clock-out error: $e');
      return false;
    }
  }

  // Get current clock status
  Future<Map<String, dynamic>?> getCurrentClockStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData == null) return null;

      return {
        'is_clocked_in': userData['is_clocked_in'] ?? false,
        'last_clock_in_time': userData['last_clock_in_time'],
        'last_clock_out_time': userData['last_clock_out_time'],
        'name': userData['name'],
        'role': userData['role'],
        'shift_type': userData['shift_type'],
      };
    } catch (e) {
      debugPrint('❌ Error getting clock status: $e');
      return null;
    }
  }
}