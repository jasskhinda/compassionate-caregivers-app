import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';

class NightShiftAlertsScreen extends StatefulWidget {
  const NightShiftAlertsScreen({super.key});

  @override
  State<NightShiftAlertsScreen> createState() => _NightShiftAlertsScreenState();
}

class _NightShiftAlertsScreenState extends State<NightShiftAlertsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _userRole;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('Users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final role = userData['role'] ?? '';

          setState(() {
            _userRole = role;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error checking user role: $e');
    }
  }

  // Mark alert as read
  Future<void> _markAsRead(String alertId) async {
    try {
      await _firestore.collection('admin_alerts').doc(alertId).set({
        'read': true,
        'read_at': FieldValue.serverTimestamp(),
        'read_by': _auth.currentUser?.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking alert as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Only Admin and Staff can view alerts
    if (_userRole != 'Admin' && _userRole != 'Staff') {
      return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: const Center(
          child: Text(
            'Access Denied',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SettingsAppBar(title: 'Night Shift Alerts'),
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),

                      // Filter tabs
                      Container(
                        decoration: BoxDecoration(
                          color: AppUtils.getColorScheme(context).surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildFilterTab('All', 'All Alerts'),
                            ),
                            Expanded(
                              child: _buildFilterTab('Unread', 'Unread'),
                            ),
                            Expanded(
                              child: _buildFilterTab('NoResponse', 'No Response'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildAlertsList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppUtils.getColorScheme(context).primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppUtils.getColorScheme(context).onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAlertsList() {
    // Simplified query to avoid index requirements
    Query<Map<String, dynamic>> query = _firestore
        .collection('admin_alerts')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading alerts: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final alerts = snapshot.data?.docs ?? [];

        // Filter alerts based on type and selected filter
        final filteredAlerts = alerts.where((doc) {
          final data = doc.data();

          // Only show night shift alerts
          if (data['type'] != 'night_shift_no_response') {
            return false;
          }

          // Apply selected filter
          if (_selectedFilter == 'Unread') {
            return data['read'] != true;
          } else if (_selectedFilter == 'NoResponse') {
            return data['type'] == 'night_shift_no_response';
          }

          return true; // Show all for 'All' filter
        }).toList();

        if (filteredAlerts.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFilter == 'All'
                      ? 'No alerts yet'
                      : _selectedFilter == 'Unread'
                          ? 'No unread alerts'
                          : 'No response alerts',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filteredAlerts.length,
          itemBuilder: (context, index) {
            final alert = filteredAlerts[index];
            final alertData = alert.data();
            final alertId = alert.id;

            return _buildAlertCard(alertId, alertData);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(String alertId, Map<String, dynamic> alertData) {
    final caregiverName = alertData['caregiver_name'] ?? 'Unknown';
    final message = alertData['message'] ?? '';
    final timestamp = alertData['timestamp'] as Timestamp?;
    final alertTime = alertData['alert_time'] as Timestamp?;
    final isRead = alertData['read'] ?? false;

    final formattedTime = timestamp != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate())
        : 'Unknown time';

    final formattedAlertTime = alertTime != null
        ? DateFormat('hh:mm a').format(alertTime.toDate())
        : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isRead ? 1 : 3,
        color: isRead
            ? AppUtils.getColorScheme(context).surface
            : AppUtils.getColorScheme(context).errorContainer.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead
                ? Colors.grey.shade300
                : Colors.red.shade300,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () async {
            if (!isRead) {
              await _markAsRead(alertId);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Night Shift Alert',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppUtils.getColorScheme(context).onSurface,
                            ),
                          ),
                          Text(
                            caregiverName,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppUtils.getColorScheme(context).onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Alert at $formattedAlertTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}