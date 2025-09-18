import 'package:flutter/material.dart';
import '../../../component/appBar/settings_app_bar.dart';
import '../../../component/listLayout/user_layout.dart';
import '../../../component/other/input_text_fields/text_input.dart';
import '../../../services/super_admin_service.dart';
import '../../../utils/appRoutes/app_routes.dart';
import '../../../utils/app_utils/AppUtils.dart';

class AllAdminUserScreen extends StatefulWidget {
  const AllAdminUserScreen({super.key});

  @override
  State<AllAdminUserScreen> createState() => _AllAdminUserScreenState();
}

class _AllAdminUserScreenState extends State<AllAdminUserScreen> {
  late TextEditingController _searchController = TextEditingController();
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _checkSuperAdminStatus();
  }

  Future<void> _checkSuperAdminStatus() async {
    final isSuperAdmin = await SuperAdminService.isSuperAdmin();
    setState(() {
      _isSuperAdmin = isSuperAdmin;
    });

    // If not super admin, show error and go back
    if (!isSuperAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Only Super Admin can manage admin users'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperAdmin) {
      return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                    Icon(Icons.admin_panel_settings, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add Admin',
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
          // App bar with Super Admin indicator
          SliverAppBar(
            backgroundColor: AppUtils.getColorScheme(context).surface,
            pinned: true,
            title: Row(
              children: [
                Icon(Icons.security, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Super Admin - Manage Admins'),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

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

                      // Super Admin Warning
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Super Admin Access',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    'You can delete any admin user. Use this power responsibly.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextInput(
                        obscureText: false,
                        onChanged: (value) {
                          setState(() {});
                        },
                        controller: _searchController,
                        labelText: 'Search Admins',
                        hintText: 'e.g. john doe, admin@example.com...',
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
                      _adminList(),
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

  Widget _adminList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SuperAdminService.getAdminsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final admins = snapshot.data;

        if (admins == null || admins.isEmpty) {
          return Center(child: Text("No admin users found."));
        }

        // Filter the list based on the search input
        final filteredAdmins = admins.where((admin) {
          final name = admin['name']?.toLowerCase() ?? '';
          final email = admin['email']?.toLowerCase() ?? '';
          final query = _searchController.text.toLowerCase();

          return name.contains(query) || email.contains(query);
        }).toList();

        if (filteredAdmins.isEmpty) {
          return Center(child: Text("No admin found with that name or email."));
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filteredAdmins.length,
          itemBuilder: (context, index) {
            final admin = filteredAdmins[index];
            final adminName = admin['name'] ?? '';
            final adminEmail = admin['email'] ?? '';
            final adminUid = admin['uid'] ?? '';
            final profileImageUrl = admin['profile_image_url'];
            final isSuperAdminUser = adminEmail.toLowerCase() == SuperAdminService.SUPER_ADMIN_EMAIL.toLowerCase();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: UserLayout(
                title: adminName,
                description: adminEmail,
                profileImageUrl: profileImageUrl,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.personalInfoScreen,
                  arguments: {'userID': adminUid},
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Super Admin Badge
                    if (isSuperAdminUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SUPER ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),

                    // Delete Button (disabled for Super Admin's own account)
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: isSuperAdminUser
                            ? Colors.grey.shade400
                            : AppUtils.getColorScheme(context).onSurface,
                      ),
                      onPressed: isSuperAdminUser ? null : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Admin User'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text('Are you sure you want to delete this admin user?'),
                                const SizedBox(height: 8),
                                Text(
                                  'Name: $adminName\nEmail: $adminEmail',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This action cannot be undone!',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Delete Admin',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            // Show loading
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            await SuperAdminService.deleteUser(adminUid, 'Admin');

                            // Log the operation
                            await SuperAdminService.logSuperAdminOperation(
                              'DELETE_ADMIN',
                              'Deleted admin user: $adminName ($adminEmail)',
                            );

                            Navigator.of(context).pop(); // Dismiss loading

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Admin user deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            Navigator.of(context).pop(); // Dismiss loading

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete admin user: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      tooltip: isSuperAdminUser ? 'Cannot delete your own account' : 'Delete Admin',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}