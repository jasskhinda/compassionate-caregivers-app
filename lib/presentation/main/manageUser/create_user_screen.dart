import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/component/appBar/settings_app_bar.dart';
import 'package:healthcare/utils/app_utils/AppUtils.dart';

import '../../../component/other/alert_dialog.dart';
import '../../../component/other/basic_button.dart';
import '../../../component/other/input_text_fields/input_text_field.dart';
import '../../../component/other/input_text_fields/password_text_field.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {

  // Instance of auth & firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  // Dropdown selection
  String selectedRole = 'Nurse';

  // User info
  String? _role;
  String? _password;

  // Get user video details
  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
          _password = data['password'];
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
    nameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    _getUserInfo();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> incrementRoleCount() async {
    await _firestore
        .collection('users_count')
        .doc('Ki8jsRs1u9Mk05F0g1UL')
        .update({selectedRole.toLowerCase(): FieldValue.increment(1)});
  }

  void signUpUser() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Store current user before creating new one
      User? originalUser = FirebaseAuth.instance.currentUser;

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      String newUserId = userCredential.user!.uid;

      // Sign out the newly created user
      await FirebaseAuth.instance.signOut();

      // Re-authenticate the original user (if exists)
      if (originalUser != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: originalUser.email!,
          password: _password.toString(), // You need to store this securely
        );
      }

      // Save user info
      _firestore.collection("Users").doc(userCredential.user!.uid).set({
        'uid': newUserId,
        'email': emailController.text,
        'role': selectedRole,
        'name': nameController.text,
        'password': passwordController.text,
        'assigned_video': 0,
        'completed_video': 0,
        'mobile_number': '',
      });

      // After saving user info
      await incrementRoleCount();

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      alertDialog(context, 'User has been created successfully!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      String errorMessage = {
        'email-already-in-use': 'This email is already registered. Please log in instead.',
        'invalid-email': 'Invalid email address. Please enter a valid email.',
        'weak-password': 'Your password is too weak. Use a stronger password.',
        'operation-not-allowed': 'Sign-up is disabled for this project.',
        'network-request-failed': 'Network error. Please check your internet connection.',
        'user-not-found': 'No user found for that email.',
        'wrong-password': 'Wrong password provided.',
        'user-disabled': 'This account has been disabled.',
        'too-many-requests': 'Too many unsuccessful attempts. Try again later.',
        'invalid-credential': 'Invalid credentials, please try again.',
      }[e.code] ?? 'An error occurred. Please try again.';

      alertDialog(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SettingsAppBar(title: 'Add User'),
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      InputTextField(
                        controller: nameController,
                        onTextChanged: (value) => setState(() {}),
                        labelText: 'Full Name',
                        hintText: 'e.g. John Doe',
                        prefixIcon: Icons.person,
                        suffixIcon: Icons.clear,
                        onIconPressed: () => setState(() => nameController.clear()),
                      ),
                      const SizedBox(height: 12),
                      InputTextField(
                        controller: emailController,
                        onTextChanged: (value) => setState(() {}),
                        labelText: 'Email Address',
                        hintText: 'e.g. john@gmail.com',
                        prefixIcon: Icons.email,
                        suffixIcon: Icons.clear,
                        onIconPressed: () => setState(() => emailController.clear()),
                      ),
                      const SizedBox(height: 12),
                      PasswordTextField(
                        obscureText: !isPasswordVisible,
                        controller: passwordController,
                        onTextChanged: (value) => setState(() {}),
                        labelText: 'Password',
                        hintText: 'e.g. Password123',
                        prefixIcon: Icons.lock,
                        suffixIcon: isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        onIconPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                      ),
                      const SizedBox(height: 12),
                      PasswordTextField(
                        obscureText: !isConfirmPasswordVisible,
                        controller: confirmPasswordController,
                        onTextChanged: (value) => setState(() {}),
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: Icons.lock,
                        suffixIcon: isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        onIconPressed: () => setState(() => isConfirmPasswordVisible = !isConfirmPasswordVisible),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['Nurse', 'Caregiver'].map((String role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: BasicButton(
                          text: 'Create user',
                          fontSize: 18,
                          textColor: Colors.white,
                          buttonColor: AppUtils.getColorScheme(context).tertiaryContainer,
                          onPressed: signUpUser,
                        ),
                      )
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
}