import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoInteractionService {
  static final VideoInteractionService _instance = VideoInteractionService._internal();
  factory VideoInteractionService() => _instance;
  VideoInteractionService._internal();

  // Static reference to active WebView controller
  static InAppWebViewController? _activeWebViewController;

  // Callback to set dialog state in video screen
  static Function(bool)? _dialogStateCallback;

  // Register the active WebView controller and dialog state callback
  static void registerWebViewController(InAppWebViewController controller, {Function(bool)? onDialogStateChange}) {
    _activeWebViewController = controller;
    _dialogStateCallback = onDialogStateChange;
    debugPrint('🎬 VideoInteractionService: WebView controller registered');
  }

  // Unregister the WebView controller
  static void unregisterWebViewController() {
    _activeWebViewController = null;
    _dialogStateCallback = null;
    debugPrint('🎬 VideoInteractionService: WebView controller unregistered');
  }

  // Disable video interaction from external services
  static Future<void> disableVideoInteraction() async {
    if (_activeWebViewController != null) {
      try {
        // Use multiple approaches to ensure the iframe gets disabled
        await _activeWebViewController!.evaluateJavascript(
          source: """
            console.log('🚫 Executing disableVideoInteraction...');

            // Method 1: Use existing function if available
            if (window.disableVideoInteraction) {
              window.disableVideoInteraction();
              console.log('🚫 Called window.disableVideoInteraction()');
            } else {
              console.log('⚠️ window.disableVideoInteraction not found!');
            }

            // Method 2: Direct DOM manipulation as fallback
            const iframe = document.getElementById('vimeo-player');
            if (iframe) {
              iframe.classList.add('dialog-active');
              iframe.style.pointerEvents = 'none';
              iframe.style.zIndex = '-1';
              console.log('🚫 Iframe pointer events disabled and z-index lowered');
            }

            // Method 3: Create overlay blocker
            let blocker = document.getElementById('vimeo-blocker');
            if (!blocker) {
              blocker = document.createElement('div');
              blocker.id = 'vimeo-blocker';
              blocker.style.position = 'fixed';
              blocker.style.top = '0';
              blocker.style.left = '0';
              blocker.style.width = '100%';
              blocker.style.height = '100%';
              blocker.style.zIndex = '9998';
              blocker.style.backgroundColor = 'transparent';
              blocker.style.pointerEvents = 'auto';
              document.body.appendChild(blocker);
              console.log('🚫 Created blocker overlay');
            }

            // Method 4: Apply to all iframes as final fallback
            const allIframes = document.querySelectorAll('iframe');
            allIframes.forEach(frame => {
              frame.classList.add('dialog-active');
              frame.style.pointerEvents = 'none';
              frame.style.zIndex = '-1';
            });

            console.log('🚫 All video interaction disabled');
          """
        );
        debugPrint('🚫 VideoInteractionService: Video interaction disabled');

        // Set dialog state to true
        if (_dialogStateCallback != null) {
          _dialogStateCallback!(true);
        }
      } catch (e) {
        debugPrint('🚫 VideoInteractionService: Error disabling video interaction: $e');
      }
    } else {
      debugPrint('🚫 VideoInteractionService: No active WebView controller found');
    }
  }

  // Enable video interaction from external services
  static Future<void> enableVideoInteraction() async {
    if (_activeWebViewController != null) {
      try {
        // Use multiple approaches to ensure the iframe gets re-enabled
        await _activeWebViewController!.evaluateJavascript(
          source: """
            console.log('✅ Executing enableVideoInteraction...');

            // Method 1: Use existing function if available
            if (window.enableVideoInteraction) {
              window.enableVideoInteraction();
              console.log('✅ Called window.enableVideoInteraction()');
            } else {
              console.log('⚠️ window.enableVideoInteraction not found!');
            }

            // Method 2: Direct DOM manipulation as fallback
            const iframe = document.getElementById('vimeo-player');
            if (iframe) {
              iframe.classList.remove('dialog-active');
              iframe.style.pointerEvents = 'auto';
              iframe.style.zIndex = '1';
              console.log('✅ Iframe pointer events enabled and z-index restored');
            }

            // Method 3: Remove overlay blocker
            const blocker = document.getElementById('vimeo-blocker');
            if (blocker) {
              blocker.remove();
              console.log('✅ Removed blocker overlay');
            }

            // Method 4: Apply to all iframes as final fallback
            const allIframes = document.querySelectorAll('iframe');
            allIframes.forEach(frame => {
              frame.classList.remove('dialog-active');
              frame.style.pointerEvents = 'auto';
              frame.style.zIndex = '1';
            });

            console.log('✅ All video interaction enabled');
          """
        );
        debugPrint('✅ VideoInteractionService: Video interaction enabled');

        // Set dialog state to false
        if (_dialogStateCallback != null) {
          _dialogStateCallback!(false);
        }
      } catch (e) {
        debugPrint('✅ VideoInteractionService: Error enabling video interaction: $e');
      }
    } else {
      debugPrint('✅ VideoInteractionService: No active WebView controller found');
    }
  }

  // Check if a WebView controller is active
  static bool get hasActiveController => _activeWebViewController != null;

  // Show HTML dialog directly in webview
  static Future<void> showHtmlDialog(String title, String message, {String dialogType = 'stillWatching'}) async {
    debugPrint('🎯 VideoInteractionService: showHtmlDialog called with type: $dialogType');

    if (_activeWebViewController != null) {
      try {
        debugPrint('🎯 VideoInteractionService: Executing JavaScript to show dialog');
        await _activeWebViewController!.evaluateJavascript(
          source: """
            console.log('🎯 Showing HTML dialog from Flutter, type: $dialogType');
            console.log('🎯 Title: $title');
            console.log('🎯 Message: $message');

            if (window.showHtmlDialog) {
              console.log('🎯 Calling window.showHtmlDialog...');
              window.showHtmlDialog('$title', '$message', null, '$dialogType');
              console.log('🎯 window.showHtmlDialog called successfully');
            } else {
              console.error('❌ showHtmlDialog function not found on window object!');
              console.log('Available window functions:', Object.keys(window).filter(k => k.includes('Dialog')));
            }
          """
        );
        debugPrint('🎯 VideoInteractionService: HTML dialog JavaScript executed successfully');
      } catch (e) {
        debugPrint('❌ VideoInteractionService: Error executing HTML dialog JavaScript: $e');
      }
    } else {
      debugPrint('❌ VideoInteractionService: No active WebView controller for HTML dialog');
    }
  }
}