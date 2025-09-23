import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoInteractionService {
  static final VideoInteractionService _instance = VideoInteractionService._internal();
  factory VideoInteractionService() => _instance;
  VideoInteractionService._internal();

  // Static reference to active WebView controller
  static InAppWebViewController? _activeWebViewController;

  // Register the active WebView controller
  static void registerWebViewController(InAppWebViewController controller) {
    _activeWebViewController = controller;
    debugPrint('🎬 VideoInteractionService: WebView controller registered');
  }

  // Unregister the WebView controller
  static void unregisterWebViewController() {
    _activeWebViewController = null;
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
            }

            // Method 2: Direct DOM manipulation as fallback
            const iframe = document.getElementById('vimeo-player');
            if (iframe) {
              iframe.classList.add('dialog-active');
              iframe.style.pointerEvents = 'none';
              console.log('🚫 Iframe pointer events disabled');
            }

            // Method 3: Apply to all iframes as final fallback
            const allIframes = document.querySelectorAll('iframe');
            allIframes.forEach(frame => {
              frame.classList.add('dialog-active');
              frame.style.pointerEvents = 'none';
            });

            console.log('🚫 All video interaction disabled');
          """
        );
        debugPrint('🚫 VideoInteractionService: Video interaction disabled');
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
            }

            // Method 2: Direct DOM manipulation as fallback
            const iframe = document.getElementById('vimeo-player');
            if (iframe) {
              iframe.classList.remove('dialog-active');
              iframe.style.pointerEvents = 'auto';
              console.log('✅ Iframe pointer events enabled');
            }

            // Method 3: Apply to all iframes as final fallback
            const allIframes = document.querySelectorAll('iframe');
            allIframes.forEach(frame => {
              frame.classList.remove('dialog-active');
              frame.style.pointerEvents = 'auto';
            });

            console.log('✅ All video interaction enabled');
          """
        );
        debugPrint('✅ VideoInteractionService: Video interaction enabled');
      } catch (e) {
        debugPrint('✅ VideoInteractionService: Error enabling video interaction: $e');
      }
    } else {
      debugPrint('✅ VideoInteractionService: No active WebView controller found');
    }
  }

  // Check if a WebView controller is active
  static bool get hasActiveController => _activeWebViewController != null;
}