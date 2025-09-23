import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/video_interaction_service.dart';

Future<bool?> showStillWatchingDialog(BuildContext context) async {
  // Disable video interaction when showing dialog
  _disableVideoInteraction();

  final result = await showDialog<bool>(
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
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      _enableVideoInteraction();
                    },
                    child: Text("No", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      _enableVideoInteraction();
                    },
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

  // Re-enable video interaction after dialog closes (in case of any edge cases)
  _enableVideoInteraction();

  return result;
}

// JavaScript communication functions to disable/enable video interaction
void _disableVideoInteraction() {
  try {
    // Use the VideoInteractionService to disable interaction
    VideoInteractionService.disableVideoInteraction();
    debugPrint('StillWatching: Disabling video interaction for dialog');
  } catch (e) {
    debugPrint('StillWatching: Error disabling video interaction: $e');
  }
}

void _enableVideoInteraction() {
  try {
    // Use the VideoInteractionService to enable interaction
    VideoInteractionService.enableVideoInteraction();
    debugPrint('StillWatching: Enabling video interaction after dialog');
  } catch (e) {
    debugPrint('StillWatching: Error enabling video interaction: $e');
  }
}