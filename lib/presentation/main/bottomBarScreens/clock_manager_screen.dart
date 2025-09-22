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
      final status = await _clockService.getCurrentClockStatus();
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

      // Simple query without orderBy to avoid index requirement
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('user_id', isEqualTo: user.uid)
          .limit(5)
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

      // Sort by clock_in_time in descending order (most recent first)
      activity.sort((a, b) {
        final aTime = a['clock_in_time'] as Timestamp?;
        final bTime = b['clock_in_time'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

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
    final colorScheme = AppUtils.getColorScheme(context);
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_clockStatus == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              SizedBox(height: 16),
              Text('Unable to load clock status', style: textTheme.titleMedium),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadClockStatus,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadClockStatus();
          await _loadRecentActivity();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Clock Management',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track your work hours',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Status Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _clockStatus!['is_clocked_in'] == true
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _clockStatus!['is_clocked_in'] == true
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _clockStatus!['is_clocked_in'] == true
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _clockStatus!['is_clocked_in'] == true
                                  ? Icons.check_circle
                                  : Icons.schedule,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _clockStatus!['is_clocked_in'] == true
                                  ? 'CLOCKED IN'
                                  : 'CLOCKED OUT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // User Info
                      _buildInfoRow(Icons.person, 'Name', _clockStatus!['name'] ?? 'Unknown'),
                      SizedBox(height: 12),
                      _buildInfoRow(Icons.work, 'Role', _clockStatus!['role'] ?? 'Unknown'),
                      if (_clockStatus!['shift_type'] != null) ...[
                        SizedBox(height: 12),
                        _buildInfoRow(Icons.nightlight_round, 'Shift', _clockStatus!['shift_type']),
                      ],

                      if (_clockStatus!['last_clock_in_time'] != null) ...[
                        SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.login,
                          'Last Clock In',
                          _formatTimestamp(_clockStatus!['last_clock_in_time']),
                        ),
                      ],

                      if (_clockStatus!['last_clock_out_time'] != null) ...[
                        SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.logout,
                          'Last Clock Out',
                          _formatTimestamp(_clockStatus!['last_clock_out_time']),
                        ),
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
                        onPressed: _clockStatus!['is_clocked_in'] == true
                            ? null
                            : _handleClockIn,
                        icon: Icon(Icons.login),
                        label: Text('Clock In', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
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
                        onPressed: _clockStatus!['is_clocked_in'] == false
                            ? null
                            : _handleClockOut,
                        icon: Icon(Icons.logout),
                        label: Text('Clock Out', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
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

                if (_recentActivity.isNotEmpty) ...[
                  SizedBox(height: 32),

                  // Recent Activity Header
                  Row(
                    children: [
                      Icon(Icons.history, color: colorScheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Recent Activity',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Activity List
                  ..._recentActivity.map((activity) {
                    final clockIn = activity['clock_in_time'] as Timestamp?;
                    final clockOut = activity['clock_out_time'] as Timestamp?;
                    final isActive = clockOut == null && clockIn != null;

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
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isActive ? Icons.timer : Icons.check_circle_outline,
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
                                  ),
                                ),
                                if (clockIn != null)
                                  Text(
                                    'In: ${_formatTimestamp(clockIn)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                if (clockOut != null)
                                  Text(
                                    'Out: ${_formatTimestamp(clockOut)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isActive && clockIn != null)
                            Text(
                              _formatDuration(clockIn, clockOut),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          if (isActive)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}