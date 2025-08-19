import 'package:flutter/material.dart';
import 'package:caregiver/utils/appRoutes/assets.dart';

class NotFoundDialog extends StatelessWidget {
  final String title;
  final String description;

  const NotFoundDialog({
    super.key,
    required this.title,
    required this.description
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Image.asset(Assets.notFound, width: 300, height: 180),
        Text(
            title,
            style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold
            )
        ),

        SizedBox(
          width: 170,
          child: Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.withAlpha(200),
                fontSize: 12,
              )
          ),
        )
      ],
    );
  }
}
