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

  @override
  void initState() {
    super.initState();
    _loadClockStatus();
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

  @override
  Widget build(BuildContext context) {
    debugPrint('Clock Manager: Building widget, isLoading: $_isLoading, clockStatus: $_clockStatus');
    final colorScheme = AppUtils.getColorScheme(context);
    final textTheme = Theme.of(context).textTheme;

    // Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text('Clock Manager'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading clock status...'),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_clockStatus == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text('Clock Manager'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              SizedBox(height: 16),
              Text('Unable to load clock status'),
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

    // Main content
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Clock Manager'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadClockStatus,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          physics: AlwaysScrollableScrollPhysics(),
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
                      Icons.schedule,
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
                    colors: _clockStatus!['is_clocked_in'] == true
                        ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                        : [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _clockStatus!['is_clocked_in'] == true
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
                          _clockStatus!['is_clocked_in'] == true
                              ? Icons.work
                              : Icons.work_off,
                          color: _clockStatus!['is_clocked_in'] == true
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
                        color: _clockStatus!['is_clocked_in'] == true
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _clockStatus!['is_clocked_in'] == true ? 'CLOCKED IN' : 'CLOCKED OUT',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _clockStatus!['is_clocked_in'] == true
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('User: ${_clockStatus!['name'] ?? 'Unknown'}'),
                    Text('Role: ${_clockStatus!['role'] ?? 'Unknown'}'),
                    if (_clockStatus!['shift_type'] != null)
                      Text('Shift Type: ${_clockStatus!['shift_type']}'),
                    if (_clockStatus!['last_clock_in_time'] != null) ...[
                      SizedBox(height: 12),
                      Text('Last Clock In: ${_formatTimestamp(_clockStatus!['last_clock_in_time'])}'),
                    ],
                    if (_clockStatus!['last_clock_out_time'] != null) ...[
                      SizedBox(height: 4),
                      Text('Last Clock Out: ${_formatTimestamp(_clockStatus!['last_clock_out_time'])}'),
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
                      onPressed: _clockStatus!['is_clocked_in'] == true ? null : _handleClockIn,
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
                      onPressed: _clockStatus!['is_clocked_in'] == false ? null : _handleClockOut,
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

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}