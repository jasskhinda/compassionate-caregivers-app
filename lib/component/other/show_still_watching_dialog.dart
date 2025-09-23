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
    barrierColor: Colors.black.withOpacity(0.9), // Very strong barrier
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.9),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Material(
                  elevation: 50, // Even higher elevation
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Are you still watching?",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "We noticed inactivity. Are you still watching this video?",
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  print('No button tapped!');
                                  await _enableVideoInteraction();
                                  Navigator.of(dialogContext).pop(false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[400]!, width: 2),
                                  ),
                                  child: const Text(
                                    "No",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  print('Yes button tapped!');
                                  await _enableVideoInteraction();
                                  Navigator.of(dialogContext).pop(true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppUtils.getColorScheme(context).primary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppUtils.getColorScheme(context).primary, width: 2),
                                  ),
                                  child: const Text(
                                    "Yes",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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