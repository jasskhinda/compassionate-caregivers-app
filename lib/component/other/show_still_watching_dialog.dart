import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

Future<bool?> showStillWatchingDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Are you still watching?"),
        content: const Text("We noticed inactivity. Are you still watching this video?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),  // return false
            child: Text("No", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),  // return true
            child: Text("Yes", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
          ),
        ],
      );
    },
  );
}