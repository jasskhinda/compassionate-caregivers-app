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
        await _activeWebViewController!.evaluateJavascript(
          source: "window.disableVideoInteraction && window.disableVideoInteraction();"
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
        await _activeWebViewController!.evaluateJavascript(
          source: "window.enableVideoInteraction && window.enableVideoInteraction();"
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