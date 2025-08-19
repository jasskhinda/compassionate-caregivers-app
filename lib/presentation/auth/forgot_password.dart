import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../component/other/basic_button.dart';
import '../../component/other/input_text_fields/input_text_field.dart';
import '../../utils/app_utils/AppUtils.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({Key? key}) : super(key: key);

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final emailController = TextEditingController();

  void sendPasswordResetEmail() async {
    try {
      await _auth.sendPasswordResetEmail(email: emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Center(
          child: SizedBox(
            width: AppUtils.getScreenSize(context).width >= 600 ? AppUtils.getScreenSize(context).width * 0.45 : double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                InputTextField(
                    controller: emailController,
                    onTextChanged: (value) {
                      setState(() {}); // Call setState to rebuild the widget on text change
                    },
                    labelText: 'Enter your email',
                    hintText: 'e.g. john@gmail.com',
                    prefixIcon: Icons.email,
                    suffixIcon: Icons.clear,
                    errorText: '',
                    onIconPressed: () {
                      setState(() {
                        emailController.clear(); // Clear text field on tap
                      });
                    }
                ),

                // SEND RESET LINK BUTTON
                BasicButton(
                    onPressed: sendPasswordResetEmail,
                    text: 'Send Reset Link',
                    textColor: Colors.white,
                    buttonColor: AppUtils.getColorScheme(context).tertiary
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
