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
    barrierColor: Colors.black.withOpacity(0.8), // Strong barrier
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: false,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Material(
                  elevation: 24,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                              child: TextButton(
                                onPressed: () async {
                                  await _enableVideoInteraction();
                                  Navigator.of(dialogContext).pop(false);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.grey[200],
                                  foregroundColor: Colors.black87,
                                ),
                                child: const Text("No"),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  await _enableVideoInteraction();
                                  Navigator.of(dialogContext).pop(true);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: AppUtils.getColorScheme(context).primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Yes"),
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