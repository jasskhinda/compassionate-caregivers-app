import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NightShiftMonitoringService {
  static final NightShiftMonitoringService _instance = NightShiftMonitoringService._internal();
  factory NightShiftMonitoringService() => _instance;
  NightShiftMonitoringService._internal();

  Timer? _alertTimer;
  Timer? _responseTimer;
  BuildContext? _context;
  bool _isAlertActive = false;
  DateTime? _alertStartTime;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Start monitoring for night shift caregivers
  void startMonitoring(BuildContext context) async {
    _context = context;

    // Check if current user is a night shift caregiver
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore
        .collection('Users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData == null ||
        userData['role'] != 'Caregiver' ||
        userData['shift_type'] != 'Night') {
      return; // Not a night shift caregiver
    }

    // Schedule random alerts between 20-60 minutes
    _scheduleNextAlert();
  }

  void _scheduleNextAlert() {
    // Cancel existing timer if any
    _alertTimer?.cancel();

    // Random interval between 20-60 minutes
    final random = Random();
    final minutes = 20 + random.nextInt(41); // 20 to 60 minutes
    final duration = Duration(minutes: minutes);

    debugPrint('Next alert scheduled in $minutes minutes');

    _alertTimer = Timer(duration, () {
      _showAlertDialog();
    });
  }

  void _showAlertDialog() {
    if (_context == null || !(_context!.mounted)) return;

    _isAlertActive = true;
    _alertStartTime = DateTime.now();

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.nightlight_round, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Night Shift Check-In',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please confirm you are alert and actively monitoring your patient.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.amber.shade700, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have 5 minutes to respond',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  _handleAlertResponse(true, dialogContext);
                },
                icon: Icon(Icons.check_circle),
                label: Text('I am Alert', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Start 5-minute response timer
    _responseTimer?.cancel();
    _responseTimer = Timer(Duration(minutes: 5), () {
      _handleAlertTimeout();
    });
  }

  void _handleAlertResponse(bool responded, BuildContext dialogContext) async {
    _responseTimer?.cancel();
    _isAlertActive = false;

    final user = _auth.currentUser;
    if (user == null) return;

    final responseTime = DateTime.now().difference(_alertStartTime!).inSeconds;

    // Record the response
    await _firestore.collection('night_shift_alerts').add({
      'user_id': user.uid,
      'alert_time': _alertStartTime,
      'response_time': DateTime.now(),
      'response_time_seconds': responseTime,
      'responded': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update user's last alert response
    await _firestore.collection('Users').doc(user.uid).set({
      'last_alert_response': FieldValue.serverTimestamp(),
      'last_alert_responded': true,
    }, SetOptions(merge: true));

    Navigator.pop(dialogContext);

    // Show success message
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Thank you for confirming. Stay alert!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Schedule next alert
    _scheduleNextAlert();
  }

  void _handleAlertTimeout() async {
    _isAlertActive = false;

    final user = _auth.currentUser;
    if (user == null) return;

    // Record non-response
    await _firestore.collection('night_shift_alerts').add({
      'user_id': user.uid,
      'alert_time': _alertStartTime,
      'responded': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update user's status
    await _firestore.collection('Users').doc(user.uid).set({
      'last_alert_response': FieldValue.serverTimestamp(),
      'last_alert_responded': false,
    }, SetOptions(merge: true));

    // Get user info for notification
    final userDoc = await _firestore.collection('Users').doc(user.uid).get();
    final userName = userDoc.data()?['name'] ?? 'Unknown';

    // Send alert to admin/staff
    await _firestore.collection('admin_alerts').add({
      'type': 'night_shift_no_response',
      'caregiver_id': user.uid,
      'caregiver_name': userName,
      'alert_time': _alertStartTime,
      'message': 'No confirmation received - $userName might be sleeping',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Close dialog if still open
    if (_context != null && _context!.mounted) {
      Navigator.of(_context!).pop();

      // Show warning message
      showDialog(
        context: _context!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Alert Not Acknowledged'),
              ],
            ),
            content: Text(
              'You did not respond to the check-in alert within 5 minutes. This has been reported to administration.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }

    // Schedule next alert
    _scheduleNextAlert();
  }

  void stopMonitoring() {
    _alertTimer?.cancel();
    _responseTimer?.cancel();
    _alertTimer = null;
    _responseTimer = null;
    _context = null;
    _isAlertActive = false;
  }

  // Check if monitoring is active
  bool get isMonitoring => _alertTimer != null;

  // Get next alert time (approximate)
  DateTime? get nextAlertTime {
    // This is approximate since we don't store the exact time
    return null;
  }
}