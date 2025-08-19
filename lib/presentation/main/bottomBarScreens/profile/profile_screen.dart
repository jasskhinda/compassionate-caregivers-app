import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:provider/provider.dart';
import '../../../../component/appBar/main_app_bar.dart';
import '../../../../theme/theme_provider.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'components/edit_profile_layout.dart';
import 'components/settings_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User info
  String? _role;
  String? _userName;

  Future<void> getDocument() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
          _userName = data['name'];
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
    getDocument();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await getDocument();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // App Bar
            const MainAppBar(title: 'Settings'),

            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EditProfileLayout(name: _userName ?? 'N/A', email: _auth.currentUser!.email ?? 'N/A'),

                        // Accounts
                        const SizedBox(height: 30),
                        Text('Accounts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                        const SizedBox(height: 10),
                        Container(
                            decoration: BoxDecoration(
                                color: AppUtils.getColorScheme(context).secondary,
                                borderRadius: BorderRadius.circular(20)
                            ),
                            child: Column(
                              children: [
                                SettingsField(title: 'Personal Info', leadingIcon: const Icon(Icons.person_outline), trailing: const Icon(Icons.navigate_next), onTap: () { Navigator.pushNamed(context, AppRoutes.personalInfoScreen, arguments: {'userID' : _auth.currentUser!.uid}); }, bottomLine: false),
                              ],
                            )
                        ),

                        // SECURITY (CHANGE PASSWORD)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Text('Security', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                            const SizedBox(height: 10),
                            Container(
                                decoration: BoxDecoration(
                                    color: AppUtils.getColorScheme(context).secondary,
                                    borderRadius: BorderRadius.circular(20)
                                ),
                                child: Column(
                                    children: [
                                      SettingsField(
                                        title: 'Change Password',
                                        leadingIcon: const Icon(Icons.lock_outline),
                                        trailing: const Icon(Icons.navigate_next),
                                        bottomLine: false,
                                        onTap: () => Navigator.pushNamed(context, AppRoutes.changePasswordScreen),
                                      )
                                    ]
                                )
                            ),
                          ],
                        ),

                        // Accessibility & Advanced(for admins)
                        if (_role != 'Caregiver')
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text('User & Video Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                              const SizedBox(height: 10),
                              Container(
                                  decoration: BoxDecoration(

                                      color: AppUtils.getColorScheme(context).secondary,
                                      borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Column(
                                      children: [
                                        SettingsField(title: 'Manage & Add Users', leadingIcon: const Icon(Icons.group_outlined), trailing: const Icon(Icons.navigate_next), onTap: () => Navigator.pushNamed(context, AppRoutes.manageUserScreen)),
                                        // SettingsField(title: 'Assign Videos', leadingIcon: Icon(Icons.video_library_outlined), trailing: Icon(Icons.navigate_next), onTap: () => Navigator.pushNamed(context, AppRoutes.assignVideoScreen)),
                                        SettingsField(title: 'Manage Learning Content', leadingIcon: const Icon(Icons.edit_outlined), trailing: const Icon(Icons.navigate_next), onTap: () => Navigator.pushNamed(context, AppRoutes.manageVideoScreen), bottomLine: false)
                                      ]
                                  )
                              ),
                            ]
                          ),

                        // Assigned Learning (For Caretakers & Nurses)
                        if (_role == 'Caregiver')
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text('Assigned Learning', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                              const SizedBox(height: 10),
                              Container(
                                  decoration: BoxDecoration(

                                      color: AppUtils.getColorScheme(context).secondary,
                                      borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Column(
                                    children: [
                                      SettingsField(
                                        title: 'Videos Assigned',
                                        leadingIcon: const Icon(Icons.playlist_play_outlined),
                                        trailing: const Icon(Icons.navigate_next),
                                        bottomLine: false,
                                        onTap: () => Navigator.pushNamed(context, AppRoutes.assignedVideoScreen),
                                      )
                                    ]
                                  )
                              ),
                            ],
                          ),

                        // Preferences
                        const SizedBox(height: 20),
                        Text('Preferences', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                        const SizedBox(height: 10),
                        Container(
                            decoration: BoxDecoration(
                              color: AppUtils.getColorScheme(context).secondary,
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: const Column(
                              children: [
                                SettingsField(title: 'Dark Mode', leadingIcon: Icon(Icons.dark_mode_outlined), trailing: ThemeButton(), bottomLine: false),
                              ],
                            )
                        ),

                        // Legal
                        const SizedBox(height: 20),
                        Text('Legal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                        const SizedBox(height: 10),
                        Container(
                            decoration: BoxDecoration(

                                color: AppUtils.getColorScheme(context).secondary,
                                borderRadius: BorderRadius.circular(20)
                            ),
                            child: Column(
                              children: [
                                SettingsField(title: 'Terms & Services', leadingIcon: const Icon(Icons.article_outlined), trailing: const Icon(Icons.navigate_next), onTap: () => Navigator.pushNamed(context, AppRoutes.termsAndConditionScreen)),
                                SettingsField(title: 'Privacy Policy', leadingIcon: Icon(Icons.policy_outlined), trailing: Icon(Icons.navigate_next), bottomLine: false, onTap: () => Navigator.pushNamed(context, AppRoutes.privacyAndPolicyScreen)),
                              ],
                            )
                        ),

                        // Account Action
                        const SizedBox(height: 20),
                        Text('Account Action', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
                        const SizedBox(height: 10),
                        Container(
                            decoration: BoxDecoration(
                                color: AppUtils.getColorScheme(context).secondary,
                                borderRadius: BorderRadius.circular(20)
                            ),
                            child: Column(
                              children: [
                                SettingsField(
                                  title: 'Sign Out',
                                  leadingIcon: const Icon(Icons.logout),
                                  trailing: const Icon(Icons.navigate_next),
                                  bottomLine: false,
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('Sign Out'),
                                          content: const Text('Are you sure you want to sign out?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                FirebaseAuth.instance.signOut();
                                                Navigator.pushNamedAndRemoveUntil(
                                                  context,
                                                  AppRoutes.loginScreen,
                                                  (route) => false
                                                );
                                              },
                                              child: const Text(
                                                'Sign Out',
                                                style: TextStyle(color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            )
                        ),

                        // Add extra space at the bottom to ensure scrolling works
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ]
      ),
    )
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