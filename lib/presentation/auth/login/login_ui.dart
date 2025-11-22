import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/component/other/alert_dialog.dart';
import 'package:caregiver/presentation/auth/forgot_password.dart';
import 'package:caregiver/services/user_document_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../../component/other/basic_button.dart';
import '../../../component/other/input_text_fields/input_text_field.dart';
import '../../../component/other/input_text_fields/password_text_field.dart';
import '../../../utils/appRoutes/app_routes.dart';
import '../../../utils/app_utils/AppUtils.dart';

class LoginUi extends StatefulWidget {
  const LoginUi({super.key});

  @override
  State<LoginUi> createState() => _LoginUiState();
}

class _LoginUiState extends State<LoginUi> {

  // Use this controller to get what the user typed
  late TextEditingController emailController;
  late TextEditingController passwordController;
  bool isPasswordVisible = false;
  bool isLoading = false;

  String? emailErrorText;
  String? passwordErrorText;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Sign user in method
  void signUserIn() async {
    // showDialog(
    //   barrierDismissible: false,
    //   context: context,
    //   builder: (context) => const Center(child: CircularProgressIndicator()),
    // );
    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      // Check if user exists in Firestore, create if missing
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      debugPrint('🔍 Login: User document exists: ${userDoc.exists}');
      if (userDoc.exists) {
        final data = userDoc.data();
        debugPrint('🔍 Login: User data fields: ${data?.keys.toList()}');
        debugPrint('🔍 Login: Role: ${data?['role']}');
        debugPrint('🔍 Login: Name: ${data?['name']}');
        debugPrint('🔍 Login: Shift Type: ${data?['shift_type']}');

        // Auto-update specific users to Admin role
        final adminEmails = [
          'j.khinda@ccgrhc.com',
          // Only j.khinda is super admin, others can be regular admins
          // Add more admin emails here if needed
        ];

        if (adminEmails.contains(user.email) && data?['role'] != 'Admin') {
          debugPrint('🔧 Updating ${user.email} to Admin role...');
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .update({
                'role': 'Admin',
                'name': data?['name'] ?? (user.email == 'j.khinda@ccgrhc.com' ? 'Jass Khinda' : data?['name']),
              });
          debugPrint('✅ User role updated to Admin');
        }
      }

      if (!userDoc.exists) {
        debugPrint('🔧 Login: User document missing, creating...');
        
        // Create user document instead of signing out
        final documentCreated = await UserDocumentService.ensureUserDocumentExists(
          customRole: user.email == 'j.khinda@ccgrhc.com' ? 'Admin' : 'Caregiver',
          customName: user.email == 'j.khinda@ccgrhc.com' ? 'Jass Khinda' : null,
        );
        
        if (!documentCreated) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() {
            isLoading = false;
          });
          alertDialog(context, 'Failed to set up your account. Please contact support.');
          return;
        }
        
        debugPrint('✅ Login: User document created successfully');
      }

      // Save OneSignal Player ID and FCM token
      try {
        // Get OneSignal Player ID (Subscription ID)
        final playerId = OneSignal.User.pushSubscription.id;

        // Get FCM token (backup)
        final fcmToken = await FirebaseMessaging.instance.getToken();

        // Prepare update data
        Map<String, dynamic> updateData = {};

        if (playerId != null) {
          updateData['oneSignalPlayerId'] = playerId;
          debugPrint('✅ OneSignal Player ID: $playerId');
        } else {
          debugPrint('⚠️ OneSignal Player ID is null');
        }

        if (fcmToken != null) {
          updateData['fcmToken'] = fcmToken;
          debugPrint('✅ FCM token: $fcmToken');
        } else {
          debugPrint('⚠️ FCM token is null (normal on iOS simulator)');
        }

        // Save to Firestore
        if (updateData.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .set(updateData, SetOptions(merge: true));
          debugPrint('✅ Notification tokens saved successfully');
        }
      } catch (e) {
        debugPrint('⚠️ Could not save notification tokens: $e');
        // Continue without tokens - it's not critical for login
      }

      // Check if user is a night shift caregiver and auto clock-in if within time window
      try {
        final userDocSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        final userDocData = userDocSnapshot.data();
        debugPrint('🔍 Login: Checking night shift for user...');
        debugPrint('🔍 Login: User data is null? ${userDocData == null}');

        if (userDocData != null) {
          final role = userDocData['role'] as String?;
          final shiftType = userDocData['shift_type'] as String?;

          debugPrint('🔍 Login: Role type: ${role.runtimeType}, value: $role');
          debugPrint('🔍 Login: Shift type: ${shiftType.runtimeType}, value: $shiftType');

          if (role == 'Caregiver' && shiftType == 'Night') {
            // Check if current time is between 8pm-1am
            final now = DateTime.now();
            final hour = now.hour;

            // 8pm (20:00) to midnight OR midnight to 1am (01:00)
            if ((hour >= 20 && hour <= 23) || (hour >= 0 && hour <= 1)) {
              // Auto clock-in the night shift caregiver
              await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .set({
                    'is_clocked_in': true,
                    'last_clock_in_time': FieldValue.serverTimestamp(),
                    'auto_clocked_in': true,
                  }, SetOptions(merge: true));

              // Get user name safely with fallback
              final userName = userDocData['name'] ?? user.email?.split('@')[0] ?? 'Unknown';

              // Create attendance record
              await FirebaseFirestore.instance
                  .collection('attendance')
                  .add({
                    'user_id': user.uid,
                    'user_name': userName,
                    'clock_in_time': FieldValue.serverTimestamp(),
                    'type': 'auto_night_shift',
                    'date': DateTime.now().toIso8601String().split('T')[0],
                  });

              // Create admin notification for clock-in
              await FirebaseFirestore.instance
                  .collection('admin_alerts')
                  .add({
                    'type': 'night_shift_clock_in',
                    'caregiver_id': user.uid,
                    'caregiver_name': userName,
                    'message': '$userName clocked in for night shift',
                    'timestamp': FieldValue.serverTimestamp(),
                    'read': false,
                    'status': 'clocked_in',
                    'clock_in_time': FieldValue.serverTimestamp(),
                  });

              debugPrint('✅ Night shift caregiver auto-clocked in');
            }
          }
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Login: Error during night shift check: $e');
        debugPrint('❌ Login: Stack trace: $stackTrace');
        // Continue with login even if night shift check fails
      }

      if (!mounted) return;
      // Navigator.pop(context); // dismiss loading
      setState(() {
        isLoading = false;
      });
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.mainScreen,
            (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // if (Navigator.canPop(context)) {
      //   Navigator.pop(context);
      // }
      setState(() {
        isLoading = false;
      });

      String errorMessage = {
        'user-not-found': 'No user found for that email.',
        'wrong-password': 'Wrong password provided.',
        'invalid-email': 'Invalid email address.',
        'user-disabled': 'This account has been disabled.',
        'too-many-requests': 'Too many unsuccessful attempts.',
        'invalid-credential': 'Invalid email or password. Please try again.',
      }[e.code] ?? 'An error occurred. Please try again.';

      print(e.code);

      alertDialog(context, errorMessage);
    } catch (e) {
      if (!mounted) return;
      // if (Navigator.canPop(context)) {
      //   Navigator.pop(context);
      // }
      setState(() {
        isLoading = false;
      });
      alertDialog(context, 'Something went wrong. Please try again.');
      print('Login Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: AppUtils.getScreenSize(context).width >= 600 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'Sign In',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppUtils.getScreenSize(context).width < 1000 ? Colors.white : AppUtils.getColorScheme(context).onTertiary
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'Glad to see you back!',
          style: TextStyle(
              color: AppUtils.getScreenSize(context).width < 1000 ? Colors.white : AppUtils.getColorScheme(context).onTertiary.withAlpha(150)
          ),
        ),

        const SizedBox(height: 70),

        InputTextField(
            controller: emailController,
            onTextChanged: (value) {
              setState(() {}); // Call setState to rebuild the widget on text change
            },
            labelText: 'Enter your email',
            hintText: 'e.g. john@gmail.com',
            prefixIcon: Icons.email,
            suffixIcon: Icons.clear,
            errorText: emailErrorText,
            onIconPressed: () {
              setState(() {
                emailController.clear(); // Clear text field on tap
              });
            }
        ),

        const SizedBox(height: 10),

        PasswordTextField(
            obscureText: !isPasswordVisible,
            controller: passwordController,
            onTextChanged: (value) {
              setState(() {}); // Call setState to rebuild the widget on text change
            },
            labelText: 'Enter your password',
            hintText: 'e.g. Password123',
            prefixIcon: Icons.lock,
            suffixIcon: isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            errorText: passwordErrorText,
            onIconPressed: () {
              setState(() {
                isPasswordVisible = !isPasswordVisible;
              });
            }
        ),

        const SizedBox(height: 4),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.forgotPasswordScreen);
            },
            child: Text(
              'Forgot Password?',
              style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer, fontWeight: FontWeight.bold)
            )
          ),
        ),

        const SizedBox(height: 7),

        // Center(
        //   child: RichText(
        //     textAlign: TextAlign.center,
        //     text: TextSpan(
        //       style: TextStyle(
        //         color: AppUtils.getColorScheme(context).onSurface,
        //       ),
        //       children: [
        //         const TextSpan(text: 'By continuing, you agree to our '),
        //         TextSpan(
        //           text: 'Terms and conditions',
        //           style: TextStyle(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).tertiary),
        //           recognizer: TapGestureRecognizer()
        //             ..onTap = () {
        //               Navigator.pushNamed(context, AppRoutes.termsAndConditionScreen);
        //             },
        //         ),
        //         const TextSpan(text: ' and '),
        //         TextSpan(
        //           text: 'Privacy Policy',
        //           style: TextStyle(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).tertiary),
        //           recognizer: TapGestureRecognizer()
        //             ..onTap = () {
        //               Navigator.pushNamed(context, AppRoutes.termsAndConditionScreen);
        //             },
        //         ),
        //         const TextSpan(text: '.'),
        //       ],
        //     ),
        //   ),
        // ),

        const SizedBox(height: 30),

        // Sign In Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: isLoading == false ? BasicButton(
              text: 'Sign in',
              fontSize: 18,
              textColor: Colors.white,
              buttonColor: AppUtils.getColorScheme(context).tertiary,
              onPressed: () {
                signUserIn();
              }
          ) : const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.termsAndConditionScreen);
              },
              child: Text(
                'Terms and conditions',
                style: TextStyle(
                  color: AppUtils.getColorScheme(context).tertiary,
                  fontWeight: FontWeight.bold
                )
              ),
            ),

            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.privacyAndPolicyScreen);
              },
              child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                      color: AppUtils.getColorScheme(context).tertiary,
                      fontWeight: FontWeight.bold
                  )
              ),
            )
          ],
        )
      ],
    );
  }
}
