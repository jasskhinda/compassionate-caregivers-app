import 'package:flutter/material.dart';

import '../../utils/appRoutes/assets.dart';
import '../../utils/app_utils/AppUtils.dart';

class ManageUserLayout extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ManageUserLayout({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.all(10),
      tileColor: Theme.of(context).colorScheme.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: ClipRRect(borderRadius: BorderRadius.circular(100), child: Image.asset(Assets.loginBack, width: 50, height: 50, fit: BoxFit.cover)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
      trailing: trailing,
    );
  }
}
