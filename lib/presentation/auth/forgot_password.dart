import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../component/other/basic_button.dart';
import '../../component/other/input_text_fields/input_text_field.dart';
import '../../services/email_service.dart';
import '../../utils/app_utils/AppUtils.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({Key? key}) : super(key: key);

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final emailController = TextEditingController();
  bool _isLoading = false;
  String _errorText = '';

  void sendPasswordResetEmail() async {
    final email = emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email address';
      });
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorText = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      // Check if user exists in Firestore
      final userQuery = await _firestore
          .collection('Users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorText = 'No account found with this email address';
        });
        return;
      }

      final userData = userQuery.docs.first.data();
      final userName = userData['name'] ?? 'User';

      // Send Firebase Auth password reset email
      await _auth.sendPasswordResetEmail(email: email);

      // Send additional custom notification email
      try {
        await sendPasswordResetNotificationEmail(
          recipientEmail: email,
          userName: userName,
        );
        print('✅ Custom password reset notification sent');
      } catch (emailError) {
        print('⚠️ Custom email notification failed: $emailError');
        // Don't fail the whole process if custom email fails
      }

      setState(() {
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog(email);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later';
          break;
        default:
          errorMessage = 'Error sending reset email: ${e.message}';
      }

      setState(() {
        _errorText = errorMessage;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'An unexpected error occurred. Please try again';
      });
      print('Password reset error: $e');
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Email Sent'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Password reset instructions have been sent to:'),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Please check your email and follow the instructions to reset your password.'),
            const SizedBox(height: 8),
            const Text(
              'Note: The email may take a few minutes to arrive. Don\'t forget to check your spam folder.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to login
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                      setState(() {
                        _errorText = ''; // Clear error when user types
                      });
                    },
                    labelText: 'Enter your email',
                    hintText: 'e.g. john@gmail.com',
                    prefixIcon: Icons.email,
                    suffixIcon: Icons.clear,
                    errorText: _errorText,
                    onIconPressed: () {
                      setState(() {
                        emailController.clear();
                        _errorText = '';
                      });
                    }
                ),

                const SizedBox(height: 20),

                // SEND RESET LINK BUTTON
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : BasicButton(
                        onPressed: sendPasswordResetEmail,
                        text: 'Send Reset Link',
                        textColor: Colors.white,
                        buttonColor: AppUtils.getColorScheme(context).tertiary
                      ),

                const SizedBox(height: 20),

                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppUtils.getColorScheme(context).secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                            color: AppUtils.getColorScheme(context).primary,
                            size: 20
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Enter your registered email address\n'
                        '2. Check your email for reset instructions\n'
                        '3. Click the link in the email to reset your password\n'
                        '4. Create a new password and sign in',
                        style: TextStyle(
                          color: AppUtils.getColorScheme(context).onSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
