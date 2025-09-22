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

                      // Professional Dashboard Stats
                      _buildStatsOverview(),
                      const SizedBox(height: 20),

                      // Filter tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppUtils.getColorScheme(context).surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppUtils.getColorScheme(context).outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildFilterTab('All', 'All Activity'),
                            ),
                            Expanded(
                              child: _buildFilterTab('Responded', 'Responded'),
                            ),
                            Expanded(
                              child: _buildFilterTab('NoResponse', 'No Response'),
                            ),
                            Expanded(
                              child: _buildFilterTab('ClockIn', 'Clock-ins'),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppUtils.getColorScheme(context).primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppUtils.getColorScheme(context).primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppUtils.getColorScheme(context).onSurface.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
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

          // Show all night shift related alerts
          final nightShiftTypes = ['night_shift_no_response', 'night_shift_response', 'night_shift_clock_in', 'night_shift_clock_out'];
          if (!nightShiftTypes.contains(data['type'])) {
            return false;
          }

          // Apply selected filter
          if (_selectedFilter == 'Responded') {
            return data['type'] == 'night_shift_response';
          } else if (_selectedFilter == 'NoResponse') {
            return data['type'] == 'night_shift_no_response';
          } else if (_selectedFilter == 'ClockIn') {
            return data['type'] == 'night_shift_clock_in';
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
    final type = alertData['type'] ?? '';
    final responseTime = alertData['response_time_seconds'];

    final formattedTime = timestamp != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate())
        : 'Unknown time';

    // Get activity-specific styling
    Color iconColor;
    Color backgroundColor;
    Color borderColor;
    IconData icon;
    String title;

    switch (type) {
      case 'night_shift_response':
        iconColor = Colors.green.shade700;
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        icon = Icons.check_circle;
        title = 'Alert Response';
        break;
      case 'night_shift_clock_in':
        iconColor = Colors.blue.shade700;
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        icon = Icons.login;
        title = 'Night Shift Clock-in';
        break;
      case 'night_shift_clock_out':
        iconColor = Colors.orange.shade700;
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        icon = Icons.logout;
        title = 'Night Shift Clock-out';
        break;
      case 'night_shift_no_response':
      default:
        iconColor = Colors.red.shade700;
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        icon = Icons.warning;
        title = 'Alert - No Response';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isRead ? 1 : 8,
        shadowColor: isRead ? Colors.grey.withOpacity(0.1) : iconColor.withOpacity(0.2),
        color: isRead
            ? Colors.grey.shade50
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isRead ? Colors.grey.shade300 : borderColor.withOpacity(0.3),
            width: isRead ? 1 : 2,
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.grey.shade200
                            : iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead
                              ? Colors.grey.shade400
                              : iconColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isRead
                            ? Colors.grey.shade600
                            : iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 18,
                              color: isRead
                                  ? Colors.grey.shade700
                                  : AppUtils.getColorScheme(context).onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                caregiverName,
                                style: TextStyle(
                                  color: isRead
                                      ? Colors.grey.shade600
                                      : iconColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (responseTime != null) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${responseTime}s',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    if (isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'READ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.grey.shade100
                        : AppUtils.getColorScheme(context).surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isRead
                          ? Colors.grey.shade700
                          : AppUtils.getColorScheme(context).onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatsOverview() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('admin_alerts')
          .where('type', whereIn: ['night_shift_no_response', 'night_shift_response', 'night_shift_clock_in', 'night_shift_clock_out'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data?.docs ?? [];
        final today = DateTime.now();
        final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        // Count today's activities
        int todayClockIns = 0;
        int todayResponses = 0;
        int todayNoResponses = 0;
        Set<String> activeCaregivers = {};

        for (final alert in alerts) {
          final data = alert.data();
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final alertDate = timestamp.toDate();
            final alertDateStr = "${alertDate.year}-${alertDate.month.toString().padLeft(2, '0')}-${alertDate.day.toString().padLeft(2, '0')}";

            if (alertDateStr == todayStr) {
              switch (data['type']) {
                case 'night_shift_clock_in':
                  todayClockIns++;
                  activeCaregivers.add(data['caregiver_name'] ?? 'Unknown');
                  break;
                case 'night_shift_response':
                  todayResponses++;
                  break;
                case 'night_shift_no_response':
                  todayNoResponses++;
                  break;
              }
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppUtils.getColorScheme(context).primaryContainer.withOpacity(0.15),
                AppUtils.getColorScheme(context).primary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppUtils.getColorScheme(context).primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppUtils.getColorScheme(context).primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    color: AppUtils.getColorScheme(context).primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Night Shift Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppUtils.getColorScheme(context).onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppUtils.getColorScheme(context).primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppUtils.getColorScheme(context).primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.login,
                      label: 'Clock-ins',
                      value: todayClockIns.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle,
                      label: 'Responded',
                      value: todayResponses.toString(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.warning,
                      label: 'No Response',
                      value: todayNoResponses.toString(),
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.people,
                      label: 'Active Staff',
                      value: activeCaregivers.length.toString(),
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppUtils.getColorScheme(context).onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}