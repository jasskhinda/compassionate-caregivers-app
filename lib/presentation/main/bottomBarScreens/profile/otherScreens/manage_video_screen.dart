import 'package:flutter/material.dart';
import 'package:healthcare/component/appBar/settings_app_bar.dart';
import 'package:healthcare/presentation/main/manageUser/caregiver_list.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class ManageVideoScreen extends StatelessWidget {
  const ManageVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SettingsAppBar(title: 'Manage learning content'),

          // Rest ui
          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CaregiverList(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
