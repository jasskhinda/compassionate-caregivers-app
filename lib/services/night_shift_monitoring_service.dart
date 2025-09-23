import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'video_interaction_service.dart';

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
    if (user == null) {
      debugPrint('NightShift: No user logged in');
      return;
    }

    final userDoc = await _firestore
        .collection('Users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData == null) {
      debugPrint('NightShift: No user data found');
      return;
    }

    final role = userData['role'];
    final shiftType = userData['shift_type'];
    final isClockedIn = userData['is_clocked_in'] ?? false;

    debugPrint('NightShift: User role: $role, shift: $shiftType, clocked in: $isClockedIn');

    if (role != 'Caregiver') {
      debugPrint('NightShift: User is not a caregiver');
      return;
    }

    if (shiftType != 'Night') {
      debugPrint('NightShift: User is not night shift');
      return;
    }

    // For testing: Skip clock-in requirement and start monitoring immediately
    // if (!isClockedIn) {
    //   debugPrint('NightShift: User is not clocked in, monitoring will start when they clock in');
    //   return;
    // }

    debugPrint('NightShift: Starting monitoring for night shift caregiver');
    // Schedule first alert quickly for testing
    _scheduleNextAlert(isFirstAlert: true);
  }

  void _scheduleNextAlert({bool isFirstAlert = false}) {
    // Cancel existing timer if any
    _alertTimer?.cancel();

    final random = Random();
    Duration duration;

    if (isFirstAlert) {
      // For testing: First alert comes very quickly (10-30 seconds)
      final seconds = 10 + random.nextInt(21); // 10 to 30 seconds
      duration = Duration(seconds: seconds);
      debugPrint('TESTING: First alert scheduled in $seconds seconds');
    } else {
      // For testing: Subsequent alerts come faster (1-5 minutes instead of 20-60)
      final minutes = 1 + random.nextInt(5); // 1 to 5 minutes
      duration = Duration(minutes: minutes);
      debugPrint('TESTING: Next alert scheduled in $minutes minutes');
    }

    _alertTimer = Timer(duration, () {
      debugPrint('NightShift: Timer triggered, showing alert dialog');
      if (_context != null && _context!.mounted) {
        _showAlertDialog();
      } else {
        debugPrint('NightShift: Context is null or not mounted, stopping monitoring');
        stopMonitoring();
      }
    });
  }

  void _showAlertDialog() {
    if (_context == null || !(_context!.mounted)) return;

    _isAlertActive = true;
    _alertStartTime = DateTime.now();

    // Disable video interaction when showing dialog
    _disableVideoInteraction();

    showDialog(
      context: _context!,
      barrierDismissible: false,
      useRootNavigator: true, // Show above all content including video players
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7), // Stronger overlay
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(_context!).size.width * 0.9,
                    maxHeight: MediaQuery.of(_context!).size.height * 0.8,
                  ),
                  child: AlertDialog(
                    elevation: 24, // Higher elevation to ensure it's on top
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
                ),
              ),
            ),
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

    // Get user info for admin notification
    final userDoc = await _firestore.collection('Users').doc(user.uid).get();
    final userName = userDoc.data()?['name'] ?? 'Unknown';

    // Create admin alert for successful response
    await _firestore.collection('admin_alerts').add({
      'type': 'night_shift_response',
      'caregiver_id': user.uid,
      'caregiver_name': userName,
      'alert_time': _alertStartTime,
      'response_time': DateTime.now(),
      'response_time_seconds': responseTime,
      'message': '$userName responded to night shift check in ${responseTime}s',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'status': 'responded',
    });

    Navigator.pop(dialogContext);

    // Re-enable video interaction after dialog closes
    _enableVideoInteraction();

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
    debugPrint('NightShift: Scheduling next alert after successful response');
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
      'status': 'no_response',
    });

    // Close dialog if still open
    if (_context != null && _context!.mounted) {
      Navigator.of(_context!).pop();

      // Re-enable video interaction
      _enableVideoInteraction();

      // Show warning message
      _disableVideoInteraction(); // Disable for warning dialog too
      showDialog(
        context: _context!,
        barrierDismissible: false,
        useRootNavigator: true, // Show above all content including video players
        builder: (BuildContext context) {
          return Material(
            type: MaterialType.transparency,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8), // Even stronger overlay for warning
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(_context!).size.width * 0.9,
                    maxHeight: MediaQuery.of(_context!).size.height * 0.8,
                  ),
                  child: AlertDialog(
                    elevation: 30, // Higher elevation for critical warning
                    backgroundColor: Colors.red.shade50,
                    title: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Alert Not Acknowledged',
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      'You did not respond to the check-in alert within 5 minutes. This has been reported to administration.',
                      style: TextStyle(fontSize: 16, color: Colors.red.shade700),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _enableVideoInteraction(); // Re-enable when warning dialog closes
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Schedule next alert
    debugPrint('NightShift: Scheduling next alert after timeout/no response');
    _scheduleNextAlert();
  }

  // Start monitoring immediately after clock-in
  void startMonitoringAfterClockIn(BuildContext context) async {
    debugPrint('NightShift: Checking if monitoring should start after clock-in');

    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore
        .collection('Users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData == null) return;

    final role = userData['role'];
    final shiftType = userData['shift_type'];

    if (role == 'Caregiver' && shiftType == 'Night') {
      debugPrint('NightShift: Night shift caregiver clocked in, starting monitoring');
      _context = context;
      _scheduleNextAlert(isFirstAlert: true);
    }
  }

  void stopMonitoring() {
    debugPrint('NightShift: Stopping monitoring');
    _alertTimer?.cancel();
    _responseTimer?.cancel();
    _alertTimer = null;
    _responseTimer = null;
    _context = null;
    _isAlertActive = false;
  }

  // Stop monitoring when user clocks out
  void stopMonitoringOnClockOut() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore
        .collection('Users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData != null &&
        userData['role'] == 'Caregiver' &&
        userData['shift_type'] == 'Night' &&
        userData['is_clocked_in'] == false) {
      debugPrint('NightShift: Caregiver clocked out, stopping monitoring');
      stopMonitoring();
    }
  }

  // Check if monitoring is active
  bool get isMonitoring => _alertTimer != null;

  // Get monitoring status for debugging
  String get monitoringStatus {
    if (_alertTimer == null) return 'Monitoring: INACTIVE';
    if (_isAlertActive) return 'Monitoring: ACTIVE - Alert waiting for response';
    return 'Monitoring: ACTIVE - Next alert scheduled';
  }

  // Get next alert time (approximate)
  DateTime? get nextAlertTime {
    // This is approximate since we don't store the exact time
    return null;
  }

  // JavaScript communication functions to disable/enable video interaction
  void _disableVideoInteraction() {
    debugPrint('NightShift: Attempting to disable video interaction');
    try {
      // Use the VideoInteractionService to disable interaction
      VideoInteractionService.disableVideoInteraction();
    } catch (e) {
      debugPrint('NightShift: Error disabling video interaction: $e');
    }
  }

  void _enableVideoInteraction() {
    debugPrint('NightShift: Attempting to enable video interaction');
    try {
      // Use the VideoInteractionService to enable interaction
      VideoInteractionService.enableVideoInteraction();
    } catch (e) {
      debugPrint('NightShift: Error enabling video interaction: $e');
    }
  }
}