import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import '../../../component/listLayout/user_layout.dart';
import '../../../component/other/input_text_fields/text_input.dart';
import '../../../services/user_services.dart';
import '../../../services/super_admin_service.dart';
import '../../../utils/appRoutes/app_routes.dart';

class AllCaregiverUserScreen extends StatefulWidget {
  const AllCaregiverUserScreen({super.key});

  @override
  State<AllCaregiverUserScreen> createState() => _AllCaregiverUserScreenState();
}

class _AllCaregiverUserScreenState extends State<AllCaregiverUserScreen> {

  late TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAdmin = false;
  bool _isStaff = false;
  bool _isSuperAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
          final email = userData['email'] ?? '';

          setState(() {
            _isAdmin = role == 'Admin';
            _isStaff = role == 'Staff';
            _isSuperAdmin = email.toLowerCase() == 'j.khinda@ccgrhc.com';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: AppUtils.getScreenSize(context).width >= 600
                  ? AppUtils.getScreenSize(context).width * 0.2
                  : AppUtils.getScreenSize(context).width * 0.45,
              height: 70,
              child: MaterialButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.createUserScreen),
                color: AppUtils.getColorScheme(context).tertiaryContainer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    Text(
                      'Add users',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SettingsAppBar(title: 'Caregivers'),

          // Rest UI
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 15),
                      TextInput(
                        obscureText: false,
                        onChanged: (value) {
                          setState(() {});
                        },
                        controller: _searchController,
                        labelText: 'Search',
                        hintText: 'e.g. john doe, smith...',
                        errorText: '',
                        prefixIcon: Icon(Icons.search, color: AppUtils.getColorScheme(context).tertiaryContainer),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.clear, color: AppUtils.getColorScheme(context).tertiaryContainer),
                        )
                            : null,
                      ),

                      const SizedBox(height: 10),
                      _caregiverList(),
                      const SizedBox(height: 120)
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _caregiverList() {
    final UserServices userServices = UserServices();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: userServices.getCaregiverStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final caregivers = snapshot.data;

        if (caregivers == null || caregivers.isEmpty) {
          return Center(child: Text("No caregivers found."));
        }

        // Filter the list based on the search input
        final filteredCaregivers = caregivers.where((caregiver) {
          final name = caregiver['name'].toLowerCase() ?? '';
          final email = caregiver['email'].toLowerCase() ?? '';
          final query = _searchController.text.toLowerCase();

          return name.contains(query) || email.contains(query);
        }).toList();

        if (filteredCaregivers.isEmpty) {
          return Center(child: Text("No caregivers match your search."));
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filteredCaregivers.length,
          itemBuilder: (context, index) {
            final caregiver = filteredCaregivers[index];
            final caregiverName = caregiver['name'] ?? '';
            final caregiverEmail = caregiver['email'] ?? '';
            final caregiverUid = caregiver['uid'] ?? '';
            final caregiverRole = caregiver['role'] ?? '';
            final profileImageUrl = caregiver['profile_image_url'];
            final shiftType = caregiver['shift_type'];

            // Create description with shift type if available
            String description = caregiverEmail;
            if (shiftType != null) {
              description = '$caregiverEmail • $shiftType Shift';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: UserLayout(
                title: caregiverName,
                description: description,
                profileImageUrl: profileImageUrl,
                onTap: () => Navigator.pushNamed(context, AppRoutes.personalInfoScreen, arguments: {'userID': caregiverUid}),
                trailing: (_isAdmin || _isStaff) ? IconButton(
                  icon: Icon(Icons.delete, color: AppUtils.getColorScheme(context).onSurface),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete User'),
                        content: Text('Are you sure you want to delete this caregiver?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await SuperAdminService.deleteUser(caregiverUid, caregiverRole);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Caregiver deleted successfully')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete caregiver: $e')),
                        );
                      }
                    }
                  },
                ) : Container(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
