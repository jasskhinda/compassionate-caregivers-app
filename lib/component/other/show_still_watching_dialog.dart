import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

Future<bool?> showStillWatchingDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true, // Show above all content including video players
    builder: (BuildContext context) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7), // Stronger overlay
          ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: AlertDialog(
                elevation: 24, // Higher elevation to ensure it's on top
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
              ),
            ),
          ),
        ),
      );
    },
  );
}