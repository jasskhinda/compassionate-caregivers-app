import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

import '../../../../../component/other/input_text_fields/password_text_field.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {

  // Firebase Instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Text input controller
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Is password visible bool
  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  bool isLoading = false;

  Future<void> changePassword() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;
      setState(() {
        isLoading = true;
      });

      String email = user.email!;

      // Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      if (newPasswordController.text != confirmPasswordController.text) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')),
        );
        return;
      }

      // Update password in Firebase Auth
      await user.updatePassword(newPasswordController.text);

      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = {
        'wrong-password': 'Current password is incorrect.',
        'weak-password': 'New password is too weak.',
        'requires-recent-login': 'Please re-login to update password.',
      }[e.code] ?? 'Error: ${e.message}';

      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // APP BAR
          const SettingsAppBar(title: 'Change Password'),

          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.45 : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      PasswordTextField(
                          obscureText: !isCurrentPasswordVisible,
                          controller: currentPasswordController,
                          onTextChanged: (value) {
                            setState(() {}); // Call setState to rebuild the widget on text change
                          },
                          labelText: 'Enter your current password',
                          hintText: 'e.g. Password123',
                          prefixIcon: Icons.lock,
                          suffixIcon: isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          errorText: '',
                          onIconPressed: () {
                            setState(() {
                              isCurrentPasswordVisible = !isCurrentPasswordVisible;
                            });
                          }
                      ),

                      // NEW PASSWORD
                      PasswordTextField(
                          obscureText: !isNewPasswordVisible,
                          controller: newPasswordController,
                          onTextChanged: (value) {
                            setState(() {}); // Call setState to rebuild the widget on text change
                          },
                          labelText: 'Enter your new password',
                          hintText: 'e.g. Password123',
                          prefixIcon: Icons.lock,
                          suffixIcon: isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          errorText: '',
                          onIconPressed: () {
                            setState(() {
                              isNewPasswordVisible = !isNewPasswordVisible;
                            });
                          }
                      ),

                      // CONFIRM PASSWORD
                      PasswordTextField(
                          obscureText: !isConfirmPasswordVisible,
                          controller: confirmPasswordController,
                          onTextChanged: (value) {
                            setState(() {}); // Call setState to rebuild the widget on text change
                          },
                          labelText: 'Enter your new password',
                          hintText: 'e.g. Password123',
                          prefixIcon: Icons.lock,
                          suffixIcon: isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          errorText: '',
                          onIconPressed: () {
                            setState(() {
                              isConfirmPasswordVisible = !isConfirmPasswordVisible;
                            });
                          }
                      ),

                      const SizedBox(height: 40),

                      // CHANGE PASSWORD BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 70,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: MaterialButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)
                            ),
                            onPressed: changePassword,
                            color: AppUtils.getColorScheme(context).tertiary,
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : const Text(
                                  'Change Password',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
        ]
      )
    );
  }
}
