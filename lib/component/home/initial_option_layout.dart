import 'package:flutter/material.dart';
import 'package:caregiver/component/home/user_count_layout.dart';

import '../../utils/app_utils/AppUtils.dart';

class InitialOptionLayout extends StatelessWidget {
  final String title;
  final String optionOneTitle;
  final String optionOneCount;
  final IconData optionOneIcon;
  final String optionTwoTitle;
  final String optionTwoCount;
  final IconData optionTwoIcon;
  final void Function()? optionOneOnTap;
  final void Function()? optionTwoOnTap;

  const InitialOptionLayout({
    super.key,
    required this.title,
    required this.optionOneTitle,
    required this.optionOneIcon,
    required this.optionTwoTitle,
    required this.optionTwoIcon,
    required this.optionOneCount,
    required this.optionTwoCount,
    this.optionOneOnTap,
    this.optionTwoOnTap
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppUtils.getColorScheme(context).onSurface
          )
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: optionOneOnTap,
                child: UserCountLayout(
                  title: optionOneTitle,
                  count: optionOneCount,
                  icon: optionOneIcon
                ),
              )
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: optionTwoOnTap,
                child: UserCountLayout(
                  title: optionTwoTitle,
                  count: optionTwoCount,
                  icon: optionTwoIcon
                ),
              )
            ),
          ],
        ),
      ],
    );
  }
}
