import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/component/other/alert_dialog.dart';
import '../../../component/other/basic_button.dart';
import '../../../component/other/input_text_fields/input_text_field.dart';
import '../../../component/other/input_text_fields/password_text_field.dart';
import '../../../utils/appRoutes/app_routes.dart';
import '../../../utils/app_utils/AppUtils.dart';
import 'dart:async';

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

    // Show loading circle
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator())
    );

    // Set a timer to dismiss the loading dialog after 3 seconds
    Timer? loadingTimer;
    loadingTimer = Timer(const Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      // Check Firestore if user is disabled
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        alertDialog(context, 'Your account has been disabled. Please contact support.');
        return;
      }

      // 🔥 Get FCM token and update Firestore
      final fcmToken = await FirebaseMessaging.instance.getToken();

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({'fcmtoken': fcmToken}, SetOptions(merge: true));

      // Then proceed to main screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.mainScreen,
              (Route<dynamic> route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print("FirebaseAuthException Code: ${e.code}");

      String errorMessage = {
        'user-not-found': 'No user found for that email.',
        'wrong-password': 'Wrong password provided.',
        'invalid-email': 'Invalid email address.',
        'user-disabled': 'This account has been disabled.',
        'too-many-requests': 'Too many unsuccessful attempts.',
        'invalid-credential': 'Invalid email or password. Please try again.',
      }[e.code] ?? 'An error occurred. Please try again.';

      alertDialog(context, errorMessage);
    } catch (e) {
      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

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

        const SizedBox(height: 7),

        Center(
          child: Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppUtils.getScreenSize(context).width < 1000 ? Colors.white : AppUtils.getColorScheme(context).onSurface,)
          ),
        ),

        const SizedBox(height: 50),

        // Sign In Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: BasicButton(
              text: 'Sign in',
              fontSize: 18,
              textColor: Colors.white,
              buttonColor: AppUtils.getColorScheme(context).tertiary,
              onPressed: () {
                signUserIn();
              }
          ),
        )
      ],
    );
  }
}
