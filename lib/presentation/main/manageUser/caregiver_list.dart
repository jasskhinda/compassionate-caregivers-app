import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../component/listLayout/user_layout.dart';
import '../../../services/user_services.dart';
import '../../../utils/appRoutes/app_routes.dart';
import '../../../utils/appRoutes/assets.dart';

class CaregiverList extends StatefulWidget {
  const CaregiverList({super.key});

  @override
  State<CaregiverList> createState() => _CaregiverListState();
}

class _CaregiverListState extends State<CaregiverList> {
  final UserServices userServices = UserServices();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: userServices.getCaregiverStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final caregivers = snapshot.data;

        if (caregivers == null || caregivers.isEmpty) {
          return Center(child: Text("No caregivers found."));
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: caregivers.length,
          itemBuilder: (context, index) {
            final caregiver = caregivers[index];
            final caregiverName = caregiver['name'] ?? '';
            final caregiverUid = caregiver['uid'] ?? '';
            final caregiverEmail = caregiver['email'] ?? '';
            final profileImageUrl = caregiver['profile_image_url'];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: UserLayout(
                title: caregiverName,
                description: caregiverEmail,
                profileImageUrl: profileImageUrl,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.assignedVideoScreen,
                    arguments: {
                      'userID': caregiverUid
                    }
                  );
                }
              ),
            );
          },
        );
      },
    );
  }
}
