import 'package:flutter/material.dart';

import '../../utils/app_utils/AppUtils.dart';

class UserCountLayout extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  const UserCountLayout({super.key, required this.title, required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          color: AppUtils.getColorScheme(context).secondary,
          borderRadius: BorderRadius.circular(10)
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 95, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppUtils.getColorScheme(context).onSurface))),
              Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}
