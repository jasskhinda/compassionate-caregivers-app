import 'package:flutter/material.dart';

Future<bool?> showStillWatchingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text("Are you still watching?"),
      content: const Text("We noticed inactivity. Are you still watching this video?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("No"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Yes"),
        ),
      ],
    ),
  );
}
