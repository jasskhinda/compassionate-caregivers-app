import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class SettingsAppBar extends StatelessWidget {
  final String title;
  const SettingsAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {

    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return SliverAppBar(
      floating: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppUtils.getScreenSize(context).width * 0.6,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold
              )
          )
          )
        ],
      ),
    );
  }
}