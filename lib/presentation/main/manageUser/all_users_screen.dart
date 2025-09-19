import 'package:flutter/material.dart';
import '../../../component/appBar/settings_app_bar.dart';
import '../../../component/listLayout/user_layout.dart';
import '../../../component/other/input_text_fields/text_input.dart';
import '../../../services/super_admin_service.dart';
import '../../../utils/appRoutes/app_routes.dart';
import '../../../utils/app_utils/AppUtils.dart';

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  late TextEditingController _searchController = TextEditingController();
  bool _isSuperAdmin = false;
  String _selectedFilter = 'All';

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
            content: Text('Access Denied: Only Super Admin can access this page'),
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
                    Icon(Icons.add, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add User',
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
                const Text('Super Admin - All Users'),
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
                                    'You can view and delete ANY user including admins. Use this power responsibly.',
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

                      // Filter buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFilterButton('All'),
                          _buildFilterButton('Admin'),
                          _buildFilterButton('Staff'),
                          _buildFilterButton('Caregiver'),
                        ],
                      ),
                      const SizedBox(height: 15),

                      TextInput(
                        obscureText: false,
                        onChanged: (value) {
                          setState(() {});
                        },
                        controller: _searchController,
                        labelText: 'Search Users',
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
                      _allUsersList(),
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

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: MaterialButton(
          onPressed: () {
            setState(() {
              _selectedFilter = filter;
            });
          },
          color: isSelected
              ? AppUtils.getColorScheme(context).tertiaryContainer
              : AppUtils.getColorScheme(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: AppUtils.getColorScheme(context).tertiaryContainer,
            ),
          ),
          child: Text(
            filter,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AppUtils.getColorScheme(context).tertiaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _allUsersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SuperAdminService.getAllUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final allUsers = snapshot.data;

        if (allUsers == null || allUsers.isEmpty) {
          return Center(child: Text("No users found."));
        }

        // Apply role filter
        List<Map<String, dynamic>> filteredUsers = allUsers;
        if (_selectedFilter != 'All') {
          filteredUsers = allUsers.where((user) {
            final role = user['role']?.toString() ?? '';
            // For Staff filter, include Staff role only
            if (_selectedFilter == 'Staff') {
              return role == 'Staff';
            }
            return role == _selectedFilter;
          }).toList();
        }

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          filteredUsers = filteredUsers.where((user) {
            final name = user['name']?.toLowerCase() ?? '';
            final email = user['email']?.toLowerCase() ?? '';
            final query = _searchController.text.toLowerCase();

            return name.contains(query) || email.contains(query);
          }).toList();
        }

        if (filteredUsers.isEmpty) {
          return Center(child: Text("No users match your criteria."));
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final userName = user['name'] ?? '';
            final userEmail = user['email'] ?? '';
            final userUid = user['uid'] ?? '';
            final userRole = user['role'] ?? '';
            final profileImageUrl = user['profile_image_url'];
            final isSuperAdminUser = userEmail.toLowerCase() == SuperAdminService.SUPER_ADMIN_EMAIL.toLowerCase();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: UserLayout(
                title: userName,
                description: '$userEmail\n$userRole',
                profileImageUrl: profileImageUrl,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.personalInfoScreen,
                  arguments: {'userID': userUid},
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _getRoleColor(userRole),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        userRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

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
                          'SUPER',
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
                            title: Text('Delete ${userRole} User'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text('Are you sure you want to delete this user?'),
                                const SizedBox(height: 8),
                                Text(
                                  'Name: $userName\nEmail: $userEmail\nRole: $userRole',
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
                                child: Text(
                                  'Delete ${userRole}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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

                            await SuperAdminService.deleteUser(userUid, userRole);

                            // Log the operation
                            await SuperAdminService.logSuperAdminOperation(
                              'DELETE_USER',
                              'Deleted ${userRole.toLowerCase()} user: $userName ($userEmail)',
                            );

                            Navigator.of(context).pop(); // Dismiss loading

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${userRole} user deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            Navigator.of(context).pop(); // Dismiss loading

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete ${userRole.toLowerCase()} user: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      tooltip: isSuperAdminUser ? 'Cannot delete your own account' : 'Delete ${userRole}',
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red.shade600;
      case 'staff':
        return Colors.blue.shade600;
      case 'caregiver':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}