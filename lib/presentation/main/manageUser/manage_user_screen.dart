import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:caregiver/services/super_admin_service.dart';
import '../../../component/home/user_count_layout.dart';

class ManageUserScreen extends StatefulWidget {
  const ManageUserScreen({super.key});

  @override
  State<ManageUserScreen> createState() => _ManageUserScreenState();
}

class _ManageUserScreenState extends State<ManageUserScreen> {

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User info
  String? _role;
  int? nurse;
  int? caregiver;
  bool isLoading = true; // Loading state
  bool _isSuperAdmin = false;

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    await Future.wait([
      getDocument(),
      _getUserInfo(),
      _checkSuperAdminStatus(),
    ]);
  }

  Future<void> getDocument() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('users_count')
          .doc('Ki8jsRs1u9Mk05F0g1UL')
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          nurse = data['nurse'];
          caregiver = data['caregiver'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  // Check if user is Super Admin
  Future<void> _checkSuperAdminStatus() async {
    try {
      final isSuperAdmin = await SuperAdminService.isSuperAdmin();
      setState(() {
        _isSuperAdmin = isSuperAdmin;
      });
    } catch (e) {
      debugPrint("Error checking super admin status: $e");
    }
  }

  // Get user video details
  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
        });
      } else {
        debugPrint("No such document!");
      }
    } catch (e) {
      debugPrint("Error fetching document: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar
            const SettingsAppBar(title: 'Manage & Add Users'),

            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        IconBasicButton(text: 'Add new users', buttonColor: AppUtils.getColorScheme(context).tertiaryContainer, textColor: Colors.white, icon: Icons.add, onPressed: () => Navigator.pushNamed(context, AppRoutes.createUserScreen)),
                        const SizedBox(height: 20),
                        Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _role ==  'Admin' ? Navigator.pushNamed(context, AppRoutes.allNurseUserScreen) : {},
                                child: UserCountLayout(title: 'Nurse', count: nurse.toString(), icon: Icons.health_and_safety)
                              )
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _role ==  'Admin' ? Navigator.pushNamed(context, AppRoutes.allCaregiverUserScreen) : {},
                                child: UserCountLayout(title: 'Caregiver', count: caregiver.toString(), icon: Icons.person)
                              )
                            ),
                          ],
                        ),

                        // Super Admin section
                        if (_isSuperAdmin) ...[
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.security, color: Colors.red.shade600),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Super Admin Controls',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                IconBasicButton(
                                  text: 'Manage Admin Users',
                                  buttonColor: Colors.red.shade600,
                                  textColor: Colors.white,
                                  icon: Icons.admin_panel_settings,
                                  onPressed: () => Navigator.pushNamed(context, AppRoutes.allAdminUserScreen),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Add extra space at the bottom to ensure scrolling works
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
