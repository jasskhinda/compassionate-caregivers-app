import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import '../../services/video_interaction_service.dart';

Future<bool?> showStillWatchingDialog(BuildContext context) async {
  // Disable video interaction when showing dialog
  await _disableVideoInteraction();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true, // Show above all content including video players
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Stack(
          children: [
            // Full screen barrier with high z-index
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Capture all taps
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                ),
              ),
            ),
            // Dialog with explicit z-index positioning
            Positioned.fill(
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: AlertDialog(
                      elevation: 1000, // Very high elevation
                      backgroundColor: Theme.of(context).dialogBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Are you still watching?"),
                      content: const Text("We noticed inactivity. Are you still watching this video?"),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop(false);
                            await _enableVideoInteraction();
                          },
                          child: Text("No", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop(true);
                            await _enableVideoInteraction();
                          },
                          child: Text("Yes", style: TextStyle(color: AppUtils.getColorScheme(context).tertiaryContainer)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  // Re-enable video interaction after dialog closes (in case of any edge cases)
  _enableVideoInteraction();

  return result;
}

// JavaScript communication functions to disable/enable video interaction
Future<void> _disableVideoInteraction() async {
  try {
    // Use the VideoInteractionService to disable interaction
    await VideoInteractionService.disableVideoInteraction();
    debugPrint('StillWatching: Disabling video interaction for dialog');
  } catch (e) {
    debugPrint('StillWatching: Error disabling video interaction: $e');
  }
}

Future<void> _enableVideoInteraction() async {
  try {
    // Use the VideoInteractionService to enable interaction
    await VideoInteractionService.enableVideoInteraction();
    debugPrint('StillWatching: Enabling video interaction after dialog');
  } catch (e) {
    debugPrint('StillWatching: Error enabling video interaction: $e');
  }
}