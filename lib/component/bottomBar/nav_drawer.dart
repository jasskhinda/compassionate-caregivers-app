import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:caregiver/utils/appRoutes/assets.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:caregiver/services/clock_management_service.dart';
import 'package:provider/provider.dart';

import '../../theme/theme_provider.dart';

class NavDrawer extends StatefulWidget {
  final void Function(int) onTabChange;
  final List<Widget> pages;
  final int selectedIndex;
  const NavDrawer({super.key, required this.onTabChange, required this.pages, required this.selectedIndex});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  String? _userRole;
  bool _isAdmin = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // Check user role
  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final role = userData['role'] ?? '';

          debugPrint('NavDrawer: User role detected: $role');
          setState(() {
            _userRole = role;
            _isAdmin = role == 'Admin';
            _isStaff = role == 'Staff';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
            color: AppUtils.getColorScheme(context).primaryFixed,
            borderRadius: BorderRadius.circular(20)
        ),
        margin: const EdgeInsets.all(15),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              alignment: Alignment.center,
              child: Center(
                // child: Text(
                //   'Healthcare',
                //   maxLines: 1,
                //   overflow: TextOverflow.ellipsis,
                //   style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)
                // ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(Assets.icLauncherIcon, width: 70, height: 70),
                    const SizedBox(height: 7),

                    Text(
                      'Compassionate\nCaregivers\n(Phil 4:6-7)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppUtils.getColorScheme(context).onSurface,
                        fontWeight: FontWeight.bold
                      )
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildListTile(
              index: 0,
              icon: widget.selectedIndex == 0 ? Icons.home : Icons.home_outlined,
              text: 'Home',
              theme: AppUtils.getColorScheme(context),
              textTheme: textTheme,
            ),
            _buildListTile(
              index: 1,
              icon: widget.selectedIndex == 1 ? Icons.message_rounded : Icons.message_outlined,
              text: 'Chat',
              theme: AppUtils.getColorScheme(context),
              textTheme: textTheme,
            ),
            _buildListTile(
              index: 2,
              icon: widget.selectedIndex == 2 ? Icons.video_library : Icons.video_library_outlined,
              text: 'Library',
              theme: AppUtils.getColorScheme(context),
              textTheme: textTheme,
            ),
            _buildListTile(
              index: 3,
              icon: widget.selectedIndex == 3 ? Icons.person : Icons.person_outline,
              text: 'Profile',
              theme: AppUtils.getColorScheme(context),
              textTheme: textTheme,
            ),

            // User Management tab for Admin/Staff only
            if (_isAdmin || _isStaff)
              _buildListTile(
                index: 4,
                icon: widget.selectedIndex == 4 ? Icons.home : Icons.home_outlined,
                text: 'User Management',
                theme: AppUtils.getColorScheme(context),
                textTheme: textTheme,
              ),

            // Clock Manager tab for Night Shift Caregivers
            if (_userRole == 'Caregiver')
              _buildListTile(
                index: 5,
                icon: widget.selectedIndex == 5 ? Icons.schedule : Icons.schedule_outlined,
                text: 'Clock Manager',
                theme: AppUtils.getColorScheme(context),
                textTheme: textTheme,
              ),

            // Preferences
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 20, 0, 0),
              child: Text('Preferences', style: textTheme.titleSmall?.copyWith(color: AppUtils.getColorScheme(context).onSurface.withAlpha(80))),
            ),
            _settingListTile(
                index: 7,
                leadingIcon: Icons.dark_mode_outlined,
                trailIcon: const ThemeButton(),
                text: 'Dark Mode',
                theme: AppUtils.getColorScheme(context),
                textTheme: textTheme
            ),

            // Courses
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 0, 0),
                  child: Text('Account Action', style: textTheme.titleSmall?.copyWith(color: AppUtils.getColorScheme(context).onSurface.withAlpha(80))),
                ),
                _settingListTile(
                  index: 6,
                  leadingIcon: Icons.logout,
                  text: 'Sign Out',
                  theme: AppUtils.getColorScheme(context),
                  textTheme: textTheme
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required int index,
    required IconData icon,
    required String text,
    required ColorScheme theme,
    required TextTheme textTheme,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: isSelected ? theme.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: theme.primary.withOpacity(0.4), width: 1.5) : null,
      ),
      child: ListTile(
        leading: Icon(
            icon,
            color: isSelected ? theme.primary : (theme.onSurface.withOpacity(0.85)),
            size: 26,
        ),
        title: Text(
          text,
          style: textTheme.titleSmall?.copyWith(
            color: isSelected ? theme.primary : theme.onSurface.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        onTap: () {
          widget.onTabChange(index);
        },
      ),
    );
  }

  Widget _settingListTile({
    Widget? trailIcon,
    required int index,
    required IconData leadingIcon,
    required String text,
    required ColorScheme theme,
    required TextTheme textTheme,
  }) {
    final bool isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: isSelected ? theme.primary.withAlpha(80) : Colors.transparent,
          borderRadius: BorderRadius.circular(10)
      ),
      child: ListTile(
        leading: Icon(
            leadingIcon,
            color: theme.onSurface
        ),
        title: Text(
          text,
          style: textTheme.titleSmall?.copyWith(
            color: theme.onSurface
          ),
        ),
        trailing: trailIcon,
        onTap: () {
          // Check if the item is not part of the bottom bar by index
          if (index == 6) { // Sign out
            // Auto clock-out before logout
            ClockManagementService().autoClockOutOnLogout().then((_) {
              FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.loginScreen, (route) => false);
            });
          } else {
            // Use the onTabChange for bottom-bar items to sync selection
            widget.onTabChange(index);
          }
        },
      ),
    );
  }
}

class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Transform.scale(
      scale: 0.7,
      child: Switch(
        value: themeProvider.isDarkMode, // Use isDarkMode directly
        onChanged: (value) {
          themeProvider.toggleTheme(); // Toggle theme on switch change
        },
      ),
    );
  }
}