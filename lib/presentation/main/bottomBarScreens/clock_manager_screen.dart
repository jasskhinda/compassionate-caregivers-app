import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caregiver/services/clock_management_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';

class ClockManagerScreen extends StatefulWidget {
  const ClockManagerScreen({super.key});

  @override
  State<ClockManagerScreen> createState() => _ClockManagerScreenState();
}

class _ClockManagerScreenState extends State<ClockManagerScreen> {
  final ClockManagementService _clockService = ClockManagementService();
  Map<String, dynamic>? _clockStatus;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadClockStatus();
    _loadRecentActivity();
  }

  Future<void> _loadClockStatus() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('Clock Manager: Loading clock status...');
      final status = await _clockService.getCurrentClockStatus();
      debugPrint('Clock Manager: Status loaded: $status');
      setState(() {
        _clockStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading clock status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('clock_in_time', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> activity = [];
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        activity.add({
          'id': doc.id,
          'date': data['date'],
          'clock_in_time': data['clock_in_time'],
          'clock_out_time': data['clock_out_time'],
          'type': data['type'] ?? 'manual_clock_in',
          'clock_out_type': data['clock_out_type'],
        });
      }

      setState(() => _recentActivity = activity);
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    }
  }

  Future<void> _handleClockIn() async {
    if (_clockStatus == null) return;

    final success = await _clockService.clockIn(_clockStatus!['name']);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Successfully clocked in!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadClockStatus();
      _loadRecentActivity();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to clock in. Please try again.'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleClockOut() async {
    if (_clockStatus == null) return;

    final success = await _clockService.clockOut(_clockStatus!['name']);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Successfully clocked out!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadClockStatus();
      _loadRecentActivity();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to clock out. Please try again.'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';
    final dateTime = timestamp.toDate();
    return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
  }

  String _formatDuration(Timestamp? clockIn, Timestamp? clockOut) {
    if (clockIn == null) return 'N/A';

    final endTime = clockOut?.toDate() ?? DateTime.now();
    final duration = endTime.difference(clockIn.toDate());

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Clock Manager: Building widget, isLoading: $_isLoading, clockStatus: $_clockStatus');
    final colorScheme = AppUtils.getColorScheme(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Clock Manager'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _clockStatus == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  SizedBox(height: 16),
                  Text(
                    'Unable to load clock status',
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _loadClockStatus();
                      _loadRecentActivity();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadClockStatus();
                await _loadRecentActivity();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.primary.withOpacity(0.1), colorScheme.primary.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clock Manager',
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Manage your work hours professionally',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Current Status Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _clockStatus?['is_clocked_in'] == true
                              ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                              : [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _clockStatus?['is_clocked_in'] == true
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _clockStatus?['is_clocked_in'] == true
                                    ? Icons.work
                                    : Icons.work_off,
                                color: _clockStatus?['is_clocked_in'] == true
                                    ? Colors.green
                                    : Colors.orange,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Current Status',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _clockStatus?['is_clocked_in'] == true
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _clockStatus?['is_clocked_in'] == true ? 'CLOCKED IN' : 'CLOCKED OUT',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _clockStatus?['is_clocked_in'] == true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                          if (_clockStatus?['last_clock_in_time'] != null) ...[
                            SizedBox(height: 12),
                            Text(
                              'Clock In: ${_formatTimestamp(_clockStatus!['last_clock_in_time'])}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            if (_clockStatus?['auto_clock_in_reason'] != null) ...[
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Auto clocked in on ${_clockStatus!['auto_clock_in_reason']}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (_clockStatus?['last_clock_out_time'] != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Clock Out: ${_formatTimestamp(_clockStatus!['last_clock_out_time'])}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            if (_clockStatus?['auto_clock_out_reason'] != null) ...[
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Auto clocked out on ${_clockStatus!['auto_clock_out_reason']}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _clockStatus?['is_clocked_in'] == true ? null : _handleClockIn,
                            icon: Icon(Icons.login),
                            label: Text('Clock In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _clockStatus?['is_clocked_in'] == false ? null : _handleClockOut,
                            icon: Icon(Icons.logout),
                            label: Text('Clock Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Recent Activity Section
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Recent Activity',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Activity List
                    if (_recentActivity.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 48,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No recent activity',
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your clock-in and clock-out records will appear here',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._recentActivity.map((activity) {
                        final clockInTime = activity['clock_in_time'] as Timestamp?;
                        final clockOutTime = activity['clock_out_time'] as Timestamp?;
                        final isActive = clockOutTime == null;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? Colors.green.withOpacity(0.3)
                                  : colorScheme.outline.withOpacity(0.2),
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.withOpacity(0.1) : colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isActive ? Icons.work : Icons.work_history,
                                      color: isActive ? Colors.green : colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activity['date'] ?? 'Unknown Date',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        if (isActive)
                                          Container(
                                            margin: EdgeInsets.only(top: 4),
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'ACTIVE',
                                              style: textTheme.labelSmall?.copyWith(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(clockInTime, clockOutTime),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.green : colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              if (clockInTime != null)
                                Padding(
                                  padding: EdgeInsets.only(left: 44),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Clock In: ${_formatTimestamp(clockInTime)}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                      if (clockOutTime != null)
                                        Text(
                                          'Clock Out: ${_formatTimestamp(clockOutTime)}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}