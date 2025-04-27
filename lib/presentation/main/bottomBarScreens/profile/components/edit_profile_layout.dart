import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/component/other/name_image_layout.dart';
import 'package:healthcare/utils/appRoutes/app_routes.dart';
import 'package:healthcare/utils/appRoutes/assets.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class EditProfileLayout extends StatefulWidget {
  final String name;
  final String email;
  const EditProfileLayout({super.key, required this.name, required this.email});

  @override
  State<EditProfileLayout> createState() => _EditProfileLayoutState();
}

class _EditProfileLayoutState extends State<EditProfileLayout> {
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _getProfileImage();
  }

  Future<void> _getProfileImage() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _profileImageUrl = data['profile_image_url'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.editProfileScreen);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppUtils.getColorScheme(context).secondary,
            borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NameImageLayout(
              title: widget.name,
              description: widget.email,
              image: Assets.loginBack,
              profileImageUrl: _profileImageUrl
            ),
            const Icon(Icons.navigate_next),
          ],
        ),
      ),
    );
  }
}