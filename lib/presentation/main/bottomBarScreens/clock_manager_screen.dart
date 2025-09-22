import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caregiver/services/clock_management_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

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

  @override
  Widget build(BuildContext context) {
    debugPrint('Clock Manager: Building widget, isLoading: $_isLoading, clockStatus: $_clockStatus');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Clock Manager - Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Clock Manager Debug Screen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 20),
                    if (_isLoading)
                      Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Loading...'),
                        ],
                      )
                    else if (_clockStatus == null)
                      Column(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 50),
                          SizedBox(height: 10),
                          Text('No clock status data'),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _loadClockStatus,
                            child: Text('Retry'),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Text(
                            'Status: ${_clockStatus!['is_clocked_in'] == true ? 'CLOCKED IN' : 'CLOCKED OUT'}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _clockStatus!['is_clocked_in'] == true ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text('User: ${_clockStatus!['name'] ?? 'Unknown'}'),
                          Text('Role: ${_clockStatus!['role'] ?? 'Unknown'}'),
                          if (_clockStatus!['shift_type'] != null)
                            Text('Shift: ${_clockStatus!['shift_type']}'),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _clockStatus!['is_clocked_in'] == true ? null : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Clock In clicked')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: Text('Clock In'),
                              ),
                              ElevatedButton(
                                onPressed: _clockStatus!['is_clocked_in'] == false ? null : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Clock Out clicked')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('Clock Out'),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}