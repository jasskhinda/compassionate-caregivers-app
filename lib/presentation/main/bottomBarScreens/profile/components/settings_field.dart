import 'package:flutter/material.dart';

import '../../../../../utils/app_utils/AppUtils.dart';

class SettingsField extends StatelessWidget {
  final Widget? leadingIcon;
  final Widget? trailing;
  final String title;
  final bool? bottomLine;
  final void Function()? onTap;

  const SettingsField({
    super.key,
    this.leadingIcon,
    required this.title,
    this.trailing,
    this.bottomLine = true,
    this.onTap
  });

  @override
  Widget build(BuildContext context) {

    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: ListTile(
              leading: leadingIcon,
              title: Text(title),
              iconColor: AppUtils.getColorScheme(context).onSecondary,
              textColor: AppUtils.getColorScheme(context).onSecondary,
              titleTextStyle: textTheme.bodyMedium,
              trailing: trailing,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            width: double.infinity,
            height: 1,
            color: bottomLine == true ? AppUtils.getColorScheme(context).onSecondary.withAlpha(80) : Colors.transparent,
          )
        ],
      ),
    );
  }
}