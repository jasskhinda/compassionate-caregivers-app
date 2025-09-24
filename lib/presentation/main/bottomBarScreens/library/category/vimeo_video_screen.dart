import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:caregiver/component/other/show_still_watching_dialog.dart';
import '../../../../../services/user_video_services.dart';
import '../../../../../services/video_interaction_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../utils/app_utils/AppUtils.dart';

class VimeoVideoScreen extends StatefulWidget {
  const VimeoVideoScreen({super.key});

  @override
  State<VimeoVideoScreen> createState() => _VimeoVideoScreenState();
}

class _VimeoVideoScreenState extends State<VimeoVideoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  InAppWebViewController? _webViewController;

  Timer? _stillWatchingTimer;
  bool _hasAskedStillWatching = false;

  double watchedPercentage = 0.0;
  Timer? _progressTimer;
  Timer? _updateTimer;

  String? videoId;
  String? videoUrl;
  String? caregiver;
  String? _role;
  String? _categoryName;
  String? _subCategoryName;
  Map<String, dynamic>? args;

  bool isPlaying = true; // Start as playing (similar to public videos)
  bool isFullScreen = false;
  bool _isDialogActive = false;

  String _generateHtmlData(String videoUrl) {
    // Convert Vimeo URL to embed format
    String embedUrl = videoUrl;

    debugPrint("🎬 Original video URL: $videoUrl");

    // Parse the URL to properly handle parameters
    if (videoUrl.contains('vimeo.com/') || videoUrl.contains('player.vimeo.com/')) {
      final uri = Uri.parse(videoUrl);

      // Check if URL needs conversion to embed format
      if (!videoUrl.contains('player.vimeo.com/')) {
        // Extract video ID from regular Vimeo URL
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final videoId = pathSegments.last;
          // Include hash parameter if present for private videos
          final hashParam = uri.queryParameters['h'];
          embedUrl = 'https://player.vimeo.com/video/$videoId${hashParam != null ? '?h=$hashParam' : ''}';
        }
      } else {
        // Already in player format - extract video ID and hash
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          final videoId = pathSegments.last;
          final hashParam = uri.queryParameters['h'];
          // Rebuild URL to ensure it's clean
          embedUrl = 'https://player.vimeo.com/video/$videoId${hashParam != null ? '?h=$hashParam' : ''}';
        }
      }

      // Add additional parameters using proper separator
      final separator = embedUrl.contains('?') ? '&' : '?';
      embedUrl = '$embedUrl${separator}title=0&byline=0&portrait=0&badge=0&autopause=0&playsinline=1';
    }

    debugPrint("🎬 Final Vimeo embed URL: $embedUrl");

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://player.vimeo.com/api/player.js"></script>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background-color: black;
      height: 100%;
      overflow: hidden;
      /* Security: Disable text selection and interactions */
      -webkit-user-select: none;
      -moz-user-select: none;
      -ms-user-select: none;
      user-select: none;
      -webkit-touch-callout: none;
      -webkit-tap-highlight-color: transparent;
      -webkit-user-drag: none;
      -khtml-user-drag: none;
      -moz-user-drag: none;
      -o-user-drag: none;
      user-drag: none;
    }

    .video-container {
      position: relative;
      width: 100%;
      height: 100%;
    }

    #vimeo-player {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }

    iframe {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      border: none;
      z-index: 1;
      transition: pointer-events 0.1s ease;
    }

    iframe.dialog-active {
      pointer-events: none !important;
    }

    .block-top {
      position: absolute;
      top: 0;
      left: 0;
      height: 90px;
      width: 100%;
      background-color: rgba(0, 0, 0, 0);
      z-index: 2;
      pointer-events: auto;
    }

    .block-bottom {
      position: absolute;
      bottom: 0;
      right: 0;
      height: 80px;
      left: 40vw;
      background-color: rgba(0, 0, 0, 0);
      z-index: 2;
      pointer-events: auto;
    }

    .click-overlay {
      position: absolute;
      top: 50%;
      left: 50%;
      width: 120px;
      height: 120px;
      transform: translate(-50%, -50%);
      z-index: 3;
      background-color: transparent;
    }

    .dialog-blocker {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: 9999;
      background-color: transparent;
      pointer-events: auto;
      display: none;
    }

    .dialog-blocker.active {
      display: block;
    }

    /* Enhanced blocking for larger screens >1400px */
    @media (min-width: 1400px) {
      .dialog-blocker.active {
        z-index: 99999;
        background-color: rgba(0, 0, 0, 0.01);
      }

      iframe.dialog-active {
        pointer-events: none !important;
        z-index: -10 !important;
      }

      #vimeo-player.dialog-active {
        pointer-events: none !important;
        z-index: -10 !important;
      }
    }

    .flutter-dialog {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0, 0, 0, 0.8);
      z-index: 10000;
      display: none;
      justify-content: center;
      align-items: center;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }

    .flutter-dialog.active {
      display: flex;
    }

    .dialog-content {
      background: white;
      border-radius: 12px;
      padding: 24px;
      max-width: 400px;
      width: 90%;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
      text-align: center;
    }

    .dialog-title {
      font-size: 20px;
      font-weight: bold;
      margin-bottom: 16px;
      color: #333;
    }

    .dialog-message {
      font-size: 16px;
      margin-bottom: 24px;
      color: #666;
      line-height: 1.4;
    }

    .dialog-buttons {
      display: flex;
      gap: 16px;
    }

    .dialog-button {
      flex: 1;
      padding: 12px 16px;
      border: none;
      border-radius: 8px;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      transition: all 0.2s;
      user-select: none;
      -webkit-user-select: none;
      -moz-user-select: none;
      -ms-user-select: none;
      touch-action: manipulation;
      position: relative;
      z-index: 10001;
    }

    .dialog-button:hover {
      transform: translateY(-1px);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    }

    .dialog-button:active {
      transform: translateY(0);
      box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
    }

    /* Desktop-specific styles */
    @media (min-width: 768px) {
      .flutter-dialog {
        z-index: 999999 !important;
      }

      .dialog-content {
        z-index: 999999 !important;
        position: relative;
      }

      .dialog-button {
        z-index: 999999 !important;
        min-height: 44px;
        font-size: 18px;
        padding: 16px 24px;
      }
    }

    .dialog-button.secondary {
      background-color: #f5f5f5;
      color: #333;
      border: 2px solid #ddd;
    }

    .dialog-button.primary {
      background-color: #007bff;
      color: white;
      border: 2px solid #007bff;
    }

    .dialog-button.primary:hover {
      background-color: #0056b3;
    }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe id="vimeo-player" src="$embedUrl"
      frameborder="0" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen>
    </iframe>
    <div class="block-top"></div>
    <div class="block-bottom"></div>
    <div class="click-overlay" onclick="simulateTap()"></div>
  </div>
  <div id="dialog-blocker" class="dialog-blocker"></div>

  <!-- HTML Dialog for direct interaction -->
  <div id="html-dialog" class="flutter-dialog">
    <div class="dialog-content">
      <div id="dialog-title" class="dialog-title">Are you still watching?</div>
      <div id="dialog-message" class="dialog-message">We noticed inactivity. Are you still watching this video?</div>
      <div class="dialog-buttons">
        <button id="dialog-no" class="dialog-button secondary">No</button>
        <button id="dialog-yes" class="dialog-button primary">Yes</button>
      </div>
    </div>
  </div>

  <script>
    let player = null;

    // Safe communication with Flutter
    function callFlutter(method, ...args) {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler(method, ...args);
        } else {
          console.log('Flutter WebView not ready, method:', method, 'args:', args);
        }
      } catch (error) {
        console.error('Error calling Flutter:', error);
      }
    }

    // Wait for iframe to load first
    window.addEventListener('load', function() {
      console.log('🎬 Page loaded, initializing Vimeo player...');

      const iframe = document.getElementById('vimeo-player');
      if (!iframe) {
        console.error('❌ Vimeo iframe not found!');
        return;
      }

      console.log('✅ Iframe found, src:', iframe.src);

      try {
        player = new Vimeo.Player(iframe);
        window.player = player; // Make player globally accessible

        // Wait for player to be ready
        player.ready().then(function() {
          console.log('✅ Video player ready');
          callFlutter('vimeoReady');
        }).catch(function(error) {
          console.error('❌ Player ready error:', error);
        });

        // Track progress updates
        player.on('timeupdate', function(data) {
          console.log('Video progress:', data.seconds, '/', data.duration);
          callFlutter('videoProgress', data.seconds, data.duration);
        });

        // Track play/pause events
        player.on('play', function() {
          console.log('Video play started');
          callFlutter('videoPlay');
        });

        player.on('pause', function() {
          console.log('Video paused');
          callFlutter('videoPause');
        });
      } catch (error) {
        console.error('❌ Error creating Vimeo player:', error);
      }
    });

    // Functions to disable/enable iframe interaction
    window.disableVideoInteraction = function() {
      console.log('🚫 Disabling video interaction for dialog');
      const iframe = document.getElementById('vimeo-player');
      const blocker = document.getElementById('dialog-blocker');

      if (iframe) {
        iframe.classList.add('dialog-active');
        iframe.style.pointerEvents = 'none !important';
        iframe.style.zIndex = '-999';
        iframe.style.position = 'relative';
        // Additional desktop-specific blocking
        iframe.style.visibility = 'hidden';
        iframe.style.display = 'none';
      }

      if (blocker) {
        blocker.classList.add('active');
        blocker.style.zIndex = '9998';
        blocker.style.pointerEvents = 'auto';
        console.log('🚫 Dialog blocker activated');
      }

      // Create additional overlay for desktop
      let desktopBlocker = document.getElementById('desktop-blocker');
      if (!desktopBlocker) {
        desktopBlocker = document.createElement('div');
        desktopBlocker.id = 'desktop-blocker';
        desktopBlocker.style.cssText = `
          position: fixed !important;
          top: 0 !important;
          left: 0 !important;
          width: 100% !important;
          height: 100% !important;
          z-index: 9999 !important;
          background: transparent !important;
          pointer-events: none !important;
        `;
        document.body.appendChild(desktopBlocker);
      }

      // Additional method: try to pause video
      try {
        if (player) {
          player.pause();
        }
      } catch (e) {
        console.log('Could not pause video:', e);
      }
    };

    window.enableVideoInteraction = function() {
      console.log('✅ Enabling video interaction after dialog');
      const iframe = document.getElementById('vimeo-player');
      const blocker = document.getElementById('dialog-blocker');
      const htmlDialog = document.getElementById('html-dialog');
      const desktopBlocker = document.getElementById('desktop-blocker');

      if (iframe) {
        iframe.classList.remove('dialog-active');
        iframe.style.pointerEvents = 'auto';
        iframe.style.zIndex = '1';
        iframe.style.position = 'absolute';
        iframe.style.visibility = 'visible';
        iframe.style.display = 'block';
      }

      if (blocker) {
        blocker.classList.remove('active');
        console.log('✅ Dialog blocker deactivated');
      }

      if (htmlDialog) {
        htmlDialog.classList.remove('active');
        console.log('✅ HTML dialog hidden');
      }

      if (desktopBlocker) {
        desktopBlocker.remove();
        console.log('✅ Desktop blocker removed');
      }
    };

    // NEW: Direct HTML dialog functions
    window.showHtmlDialog = function(title, message, callback, dialogType = 'stillWatching') {
      console.log('🚀 Showing HTML dialog directly, type:', dialogType);

      const htmlDialog = document.getElementById('html-dialog');
      const titleEl = document.getElementById('dialog-title');
      const messageEl = document.getElementById('dialog-message');
      const noBtn = document.getElementById('dialog-no');
      const yesBtn = document.getElementById('dialog-yes');

      if (titleEl) titleEl.textContent = title;
      if (messageEl) messageEl.textContent = message;

      // Update button text based on dialog type
      if (dialogType === 'nightShift') {
        noBtn.textContent = 'I am Alert';
        noBtn.className = 'dialog-button primary'; // Make it primary style
        yesBtn.style.display = 'none'; // Hide Yes button for night shift
      } else {
        noBtn.textContent = 'No';
        noBtn.className = 'dialog-button secondary';
        yesBtn.textContent = 'Yes';
        yesBtn.style.display = 'block';
      }

      // Remove existing event listeners
      const newNoBtn = noBtn.cloneNode(true);
      const newYesBtn = yesBtn.cloneNode(true);
      noBtn.parentNode.replaceChild(newNoBtn, noBtn);
      yesBtn.parentNode.replaceChild(newYesBtn, yesBtn);

      // Add multiple event listeners for desktop/mobile compatibility
      function handleNoClick(e) {
        e.preventDefault();
        e.stopPropagation();

        if (dialogType === 'nightShift') {
          console.log('🌙 I am Alert button clicked via HTML (desktop)');
          htmlDialog.classList.remove('active');
          window.enableVideoInteraction();
          if (callback) callback(true);
          callFlutter('dialogResult', true, dialogType);
        } else {
          console.log('🔴 NO button clicked via HTML (desktop)');
          htmlDialog.classList.remove('active');
          window.enableVideoInteraction();
          if (callback) callback(false);
          callFlutter('dialogResult', false, dialogType);
        }
      }

      function handleYesClick(e) {
        e.preventDefault();
        e.stopPropagation();
        console.log('🟢 YES button clicked via HTML (desktop)');
        htmlDialog.classList.remove('active');
        window.enableVideoInteraction();
        if (callback) callback(true);
        callFlutter('dialogResult', true, dialogType);
      }

      // Add multiple event types for maximum compatibility
      ['click', 'mouseup', 'touchend'].forEach(eventType => {
        newNoBtn.addEventListener(eventType, handleNoClick, { passive: false });
        newYesBtn.addEventListener(eventType, handleYesClick, { passive: false });
      });

      // Show dialog
      htmlDialog.classList.add('active');
      window.disableVideoInteraction();
    };

    window.hideHtmlDialog = function() {
      const htmlDialog = document.getElementById('html-dialog');
      if (htmlDialog) {
        htmlDialog.classList.remove('active');
        window.enableVideoInteraction();
      }
    };

    // Security measures to prevent URL access

    // Disable right-click context menu
    document.addEventListener('contextmenu', function(e) {
      e.preventDefault();
      return false;
    });

    // Disable developer tools keyboard shortcuts
    document.addEventListener('keydown', function(e) {
      // F12, Ctrl+Shift+I, Ctrl+Shift+J, Ctrl+U, Ctrl+Shift+C, Ctrl+A
      if (e.key === 'F12' ||
          (e.ctrlKey && e.shiftKey && (e.key === 'I' || e.key === 'J' || e.key === 'C')) ||
          (e.ctrlKey && (e.key === 'u' || e.key === 'U' || e.key === 'a' || e.key === 'A' ||
                         e.key === 's' || e.key === 'S'))) {
        e.preventDefault();
        return false;
      }
    });

    // Disable text selection and drag
    document.addEventListener('selectstart', function(e) {
      e.preventDefault();
      return false;
    });

    document.addEventListener('dragstart', function(e) {
      e.preventDefault();
      return false;
    });

    // Clear console periodically (minimal impact on performance)
    setInterval(function() {
      if (typeof console !== 'undefined' && console.clear) {
        try { console.clear(); } catch(e) {}
      }
    }, 5000);

  </script>
</body>
</html>
''';
  }

  void _startStillWatchingTimer() {
    if (_stillWatchingTimer != null) {
      _stillWatchingTimer?.cancel();
    }

    // Get video duration first, then calculate smart timing
    _webViewController?.evaluateJavascript(source: '''
      try {
        var video = document.querySelector('video');
        if (video && video.duration && video.duration > 0) {
          window.flutter_inappwebview.callHandler('videoDurationDetected', video.duration);
        } else {
          // Fallback for when duration isn't available yet
          setTimeout(function() {
            var video = document.querySelector('video');
            if (video && video.duration && video.duration > 0) {
              window.flutter_inappwebview.callHandler('videoDurationDetected', video.duration);
            } else {
              // Ultimate fallback - assume medium video
              window.flutter_inappwebview.callHandler('videoDurationDetected', 180);
            }
          }, 2000);
        }
      } catch(e) {
        // Fallback timing
        window.flutter_inappwebview.callHandler('videoDurationDetected', 180);
      }
    ''');
  }

  void _startSmartStillWatchingTimer(double videoDurationSeconds) {
    if (_stillWatchingTimer != null) {
      _stillWatchingTimer?.cancel();
    }

    List<int> alertTimes = _calculateSmartAlertTimes(videoDurationSeconds);
    int currentAlertIndex = 0;

    void scheduleNextAlert() {
      if (currentAlertIndex >= alertTimes.length || !mounted) return;

      int delaySeconds = alertTimes[currentAlertIndex];
      debugPrint("🕐 Scheduling 'Are you still watching?' alert #${currentAlertIndex + 1} at ${delaySeconds}s for ${videoDurationSeconds.toInt()}s video");

      _stillWatchingTimer = Timer(Duration(seconds: delaySeconds), () async {
        if (!mounted) return;

        debugPrint("🎯 Showing 'Are you still watching?' alert #${currentAlertIndex + 1}");

        WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Pause Vimeo video using direct iframe access
        debugPrint("🛑 Pausing Vimeo video for 'Are you still watching?' dialog");
        setState(() {
          isPlaying = false; // Update button state
        });
        await _webViewController?.evaluateJavascript(source: '''
          try {
            // Try multiple methods to pause the video
            var iframe = document.querySelector('iframe');
            if (iframe && iframe.contentWindow) {
              iframe.contentWindow.postMessage('{"method":"pause"}', '*');
            }

            // Also try if there's a Vimeo player object
            if (typeof Vimeo !== 'undefined' && iframe) {
              var player = new Vimeo.Player(iframe);
              player.pause();
            }

            console.log('✅ Video pause attempted');
          } catch(e) {
            console.log('❌ Error pausing video:', e);
          }
        ''');

        // Disable video interaction before showing dialog
        await VideoInteractionService.disableVideoInteraction();

        final result = await showStillWatchingDialog(context);

        // Re-enable video interaction after dialog
        await VideoInteractionService.enableVideoInteraction();

        if (result == true) {
          // Resume playing if user clicked Yes
          debugPrint("▶️ Resuming Vimeo video after 'Yes' response");
          setState(() {
            isPlaying = true; // Update button state
          });
          await _webViewController?.evaluateJavascript(source: '''
            try {
              // Try multiple methods to play the video
              var iframe = document.querySelector('iframe');
              if (iframe && iframe.contentWindow) {
                iframe.contentWindow.postMessage('{"method":"play"}', '*');
              }

              // Also try if there's a Vimeo player object
              if (typeof Vimeo !== 'undefined' && iframe) {
                var player = new Vimeo.Player(iframe);
                player.play();
              }

              console.log('✅ Video play attempted');
            } catch(e) {
              console.log('❌ Error playing video:', e);
            }
          ''');
        } else {
          debugPrint("⏹️ Video remains paused after 'No' response");
          // Keep isPlaying = false (already set above)
        }

        debugPrint("Still watching dialog closed with result: $result");

        // Schedule next alert if user clicked Yes and there are more alerts
        if (result == true) {
          currentAlertIndex++;
          scheduleNextAlert();
        }
      });
      });
    }

    // Start with the first alert
    scheduleNextAlert();
  }

  List<int> _calculateSmartAlertTimes(double videoDurationSeconds) {
    final duration = videoDurationSeconds.toInt();
    List<int> alertTimes = [];
    final random = DateTime.now().millisecondsSinceEpoch;

    if (duration <= 10) {
      // Very short videos (≤10s): Single alert at 40-60%
      int alertAt = (duration * 0.4 + (random % (duration * 0.2).ceil()).abs()).toInt();
      alertTimes.add(alertAt.clamp(2, duration - 1));

    } else if (duration <= 30) {
      // Short videos (≤30s): Single alert at 50-70%
      int alertAt = (duration * 0.5 + (random % (duration * 0.2).ceil()).abs()).toInt();
      alertTimes.add(alertAt.clamp(3, duration - 2));

    } else if (duration <= 120) {
      // Medium videos (≤2min): Single alert at 60-80%
      int alertAt = (duration * 0.6 + (random % (duration * 0.2).ceil()).abs()).toInt();
      alertTimes.add(alertAt.clamp(5, duration - 5));

    } else if (duration <= 300) {
      // Medium-long videos (≤5min): Two alerts at 50-60% and 80-90%
      int firstAlert = (duration * 0.5 + (random % (duration * 0.1).ceil()).abs()).toInt();
      int secondAlert = (duration * 0.8 + (random % (duration * 0.1).ceil()).abs()).toInt();

      alertTimes.add(firstAlert.clamp(15, duration - 30));
      alertTimes.add(secondAlert.clamp(firstAlert + 20, duration - 10));

    } else if (duration <= 600) {
      // Long videos (≤10min): Three alerts at 40-50%, 65-75%, 85-95%
      int firstAlert = (duration * 0.4 + (random % (duration * 0.1).ceil()).abs()).toInt();
      int secondAlert = (duration * 0.65 + (random % (duration * 0.1).ceil()).abs()).toInt();
      int thirdAlert = (duration * 0.85 + (random % (duration * 0.1).ceil()).abs()).toInt();

      alertTimes.add(firstAlert.clamp(30, duration - 60));
      alertTimes.add(secondAlert.clamp(firstAlert + 30, duration - 30));
      alertTimes.add(thirdAlert.clamp(secondAlert + 20, duration - 15));

    } else {
      // Very long videos (>10min): Four alerts at 30-40%, 55-65%, 75-80%, 90-95%
      int firstAlert = (duration * 0.3 + (random % (duration * 0.1).ceil()).abs()).toInt();
      int secondAlert = (duration * 0.55 + (random % (duration * 0.1).ceil()).abs()).toInt();
      int thirdAlert = (duration * 0.75 + (random % (duration * 0.05).ceil()).abs()).toInt();
      int fourthAlert = (duration * 0.9 + (random % (duration * 0.05).ceil()).abs()).toInt();

      alertTimes.add(firstAlert.clamp(45, duration - 120));
      alertTimes.add(secondAlert.clamp(firstAlert + 45, duration - 60));
      alertTimes.add(thirdAlert.clamp(secondAlert + 30, duration - 30));
      alertTimes.add(fourthAlert.clamp(thirdAlert + 20, duration - 15));
    }

    debugPrint("📊 Smart timing for ${duration}s video: alerts at ${alertTimes.join('s, ')}s");
    return alertTimes;
  }

  // Video control functions
  void _togglePlayPause() {
    if (isPlaying) {
      // Pause video
      _webViewController?.evaluateJavascript(source: '''
        try {
          // Method 1: Direct postMessage to Vimeo player
          var vimeoFrame = document.querySelector('iframe[src*="player.vimeo.com"]');
          if (vimeoFrame) {
            vimeoFrame.contentWindow.postMessage('{"method":"pause"}', 'https://player.vimeo.com');
            console.log('🎵 Pause message sent to Vimeo iframe');
          }

          // Method 2: Try accessing video element directly
          var video = document.querySelector('video');
          if (video) {
            video.pause();
            console.log('🎵 Video element paused directly');
          }

          // Method 3: If this page IS the Vimeo player
          if (window.location.href.includes('player.vimeo.com')) {
            document.dispatchEvent(new KeyboardEvent('keydown', {'key': ' ', 'code': 'Space'}));
            console.log('🎵 Space key dispatched for pause');
          }

        } catch(e) {
          console.log('❌ Error pausing video:', e);
        }
      ''');
      _stillWatchingTimer?.cancel(); // Stop timer when video is paused
    } else {
      // Play video
      _webViewController?.evaluateJavascript(source: '''
        try {
          // Method 1: Direct postMessage to Vimeo player
          var vimeoFrame = document.querySelector('iframe[src*="player.vimeo.com"]');
          if (vimeoFrame) {
            vimeoFrame.contentWindow.postMessage('{"method":"play"}', 'https://player.vimeo.com');
            console.log('▶️ Play message sent to Vimeo iframe');
          }

          // Method 2: Try accessing video element directly
          var video = document.querySelector('video');
          if (video) {
            video.play();
            console.log('▶️ Video element played directly');
          }

          // Method 3: If this page IS the Vimeo player
          if (window.location.href.includes('player.vimeo.com')) {
            document.dispatchEvent(new KeyboardEvent('keydown', {'key': ' ', 'code': 'Space'}));
            console.log('▶️ Space key dispatched for play');
          }

        } catch(e) {
          console.log('❌ Error playing video:', e);
        }
      ''');
      // Restart smart timer when play is pressed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startStillWatchingTimer();
      });
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  void _toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _startStillWatchingTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (args == null) {
      args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      videoUrl = args?['videoUrl'];
      videoId = args?['videoId'];
      caregiver = args?['caregiver'];
      _categoryName = args?['categoryName'];
      _subCategoryName = args?['subcategoryName'];

      // Debug: Log video initialization
      debugPrint("Video initialized - ID: [PROTECTED] (${videoUrl?.isNotEmpty == true ? 'URL provided' : 'No URL'})");
      debugPrint("Video tracking parameters: userId: [PROTECTED], role: $_role");

      // Start paused, so no auto-play on load
      isPlaying = false;

      _startTrackingProgress();
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("No authenticated user found");
        return;
      }

      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _role = data['role'] ?? 'Caregiver'; // Default to Caregiver if role is missing
          });
        } else {
          debugPrint("User document exists but data is null");
          setState(() => _role = 'Caregiver');
        }
      } else {
        debugPrint("User document does not exist, creating with default role");
        // Create user document with default role
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set({
          'role': 'Caregiver',
          'name': user.email?.split('@')[0] ?? 'Unknown',
          'email': user.email,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        setState(() => _role = 'Caregiver');
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      // Set default role on error
      setState(() => _role = 'Caregiver');
    }
  }

  void _startTrackingProgress() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_webViewController != null) {
        try {
          var durationStr = await _webViewController!.evaluateJavascript(source: "document.querySelector('video').duration.toString();");
          var currentStr = await _webViewController!.evaluateJavascript(source: "document.querySelector('video').currentTime.toString();");
          double duration = double.tryParse(durationStr ?? '') ?? 0;
          double current = double.tryParse(currentStr ?? '') ?? 0;
          if (duration > 0) {
            double percent = (current / duration) * 100;
            setState(() => watchedPercentage = percent.clamp(0, 100));
          }
        } catch (_) {}
      }
    });

    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_role == "Caregiver") {
        _updateProgressInFirestore(watchedPercentage);
      }
    });
  }

  Future<void> _updateProgressInFirestore(double percentage) async {
    try {
      if (videoId == null || videoId!.isEmpty) {
        debugPrint("Vimeo progress: videoId is null or empty");
        return;
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint("Vimeo progress: User not authenticated");
        return;
      }

      debugPrint("Vimeo progress: Updating progress for videoId: $videoId, percentage: ${percentage.toStringAsFixed(2)}%");

      final docRef = FirebaseFirestore.instance
          .collection('caregiver_videos')
          .doc(userId)
          .collection('videos')
          .doc(videoId);

      final docSnapshot = await docRef.get();
      final existingProgress = docSnapshot.data()?['progress'] ?? 0.0;

      debugPrint("Vimeo progress: Existing progress: ${existingProgress.toStringAsFixed(2)}%");

      if (percentage > existingProgress) {
        await docRef.set({
          'progress': percentage,
          'lastUpdated': FieldValue.serverTimestamp(),
          'videoTitle': args?['videoTitle'] ?? 'Unknown',
          'videoUrl': videoUrl ?? '',
          'userId': userId,
          'lastWatchSession': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("Vimeo progress: Successfully updated to ${percentage.toStringAsFixed(2)}%");
      } else {
        debugPrint("Vimeo progress: No update needed (${percentage.toStringAsFixed(2)}% <= ${existingProgress.toStringAsFixed(2)}%)");
      }
    } catch (e) {
      debugPrint("Vimeo progress: Error updating progress: $e");
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _updateTimer?.cancel();
    VideoInteractionService.unregisterWebViewController(); // Unregister from service
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoTitle = args?['videoTitle'] ?? 'Default Video Title';
    final date = args?['date'] ?? 'Default Date';
    final adminName = args?['adminName'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Video Player")),
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoWebView(),
                  const SizedBox(height: 15),
                  _buildVideoControls(),
                  const SizedBox(height: 15),
                  _buildVideoInfo(videoTitle, adminName, date),
                  if ((_role == 'Admin' || _role == 'Staff') && videoUrl != null && _categoryName != null && _subCategoryName != null)
                    _AssignedCaregiverList(
                      categoryName: _categoryName!,
                      subCategoryName: _subCategoryName!,
                      videoId: videoId!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoWebView() {
    final vimeoUrl = videoUrl ?? '';

    return SizedBox(
      height: AppUtils.getScreenSize(context).width >= 600
          ? isFullScreen ? AppUtils.getScreenSize(context).height * 0.8 : (AppUtils.getScreenSize(context).width > 1400 ? 450 : 350)
          : isFullScreen ? AppUtils.getScreenSize(context).height * 0.8 : 250,
      width: AppUtils.getScreenSize(context).width >= 600
          ? isFullScreen ? double.infinity : AppUtils.getScreenSize(context).width * 0.45
          : double.infinity,
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri("about:blank")),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
              supportZoom: false,
              disableContextMenu: true,
              transparentBackground: false,
              useShouldOverrideUrlLoading: false, // Allow navigation for iframe loading
              allowsInlineMediaPlayback: true,
              // iOS-specific settings for cross-origin content
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              clearCache: true,
            ),
            onWebViewCreated: (controller) async {
              _webViewController = controller;
              VideoInteractionService.registerWebViewController(
                controller,
                onDialogStateChange: (isActive) {
                  if (mounted) {
                    setState(() {
                      _isDialogActive = isActive;
                    });
                  }
                }
              ); // Register with service

              // Create proper embed URL
              String embedUrl = videoUrl!;
              debugPrint("🎬 Original video URL: $videoUrl");

              if (videoUrl!.contains('player.vimeo.com')) {
                final uri = Uri.parse(videoUrl!);
                final pathSegments = uri.pathSegments;
                if (pathSegments.length >= 2) {
                  final videoId = pathSegments.last;
                  final hashParam = uri.queryParameters['h'];
                  embedUrl = 'https://player.vimeo.com/video/$videoId${hashParam != null ? '?h=$hashParam' : ''}';

                  // Add parameters for iOS compatibility
                  final separator = embedUrl.contains('?') ? '&' : '?';
                  embedUrl = '$embedUrl${separator}title=0&byline=0&portrait=0&badge=0&autopause=0';
                }
              }

              debugPrint("🎬 Final embed URL: $embedUrl");

              debugPrint("🎬 Loading Vimeo URL directly for iOS: $embedUrl");

              // Load the Vimeo embed URL directly - this should work on iOS
              await controller.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(embedUrl),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
                    'Referer': 'https://vimeo.com/'
                  }
                )
              );

              controller.addJavaScriptHandler(
                handlerName: 'vimeoReady',
                callback: (args) {
                  debugPrint("🎬 Vimeo player ready for videoId: $videoId");
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'videoDurationDetected',
                callback: (args) {
                  final duration = args[0] as double;
                  debugPrint("📏 Video duration detected: ${duration.toInt()}s");
                  _startSmartStillWatchingTimer(duration);
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'videoProgress',
                callback: (args) {
                  final seconds = args[0] as double;
                  final duration = args[1] as double;
                  if (duration > 0) {
                    final percent = (seconds / duration) * 100;
                    debugPrint("🎬 Vimeo progress update: ${percent.toStringAsFixed(2)}% ($seconds/$duration seconds)");
                    if (mounted) {
                      setState(() {
                        watchedPercentage = percent.clamp(0, 100);
                      });
                    }
                  }
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'videoPlay',
                callback: (args) {
                  debugPrint("🎬 Vimeo video started playing");
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'videoPause',
                callback: (args) {
                  debugPrint("🎬 Vimeo video paused");
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'checkPaused',
                callback: (args) async {
                  final isPaused = args.first == true;

                  if (!isPaused) {
                    // Pause the video
                    await controller.evaluateJavascript(source: "player.pause();");
                    setState(() => isPlaying = false);

                    // Disable video interaction before showing dialog
                    await VideoInteractionService.disableVideoInteraction();

                    // Show the dialog
                    final result = await showStillWatchingDialog(context);

                    // Re-enable video interaction after dialog
                    await VideoInteractionService.enableVideoInteraction();

                    if (result == true) {
                      await controller.evaluateJavascript(source: "player.play();");
                      setState(() => isPlaying = true);
                    }

                    _hasAskedStillWatching = true;
                    _stillWatchingTimer = null;
                  } else {
                    // Video already paused — skip dialog
                    _stillWatchingTimer = null;
                  }
                },
              );

              // Add JavaScript handlers for external dialog control
              controller.addJavaScriptHandler(
                handlerName: 'disableVideoInteraction',
                callback: (args) async {
                  await controller.evaluateJavascript(source: "window.disableVideoInteraction && window.disableVideoInteraction();");
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'enableVideoInteraction',
                callback: (args) async {
                  await controller.evaluateJavascript(source: "window.enableVideoInteraction && window.enableVideoInteraction();");
                },
              );

              // Handler for HTML dialog results
              controller.addJavaScriptHandler(
                handlerName: 'dialogResult',
                callback: (args) async {
                  final result = args.isNotEmpty ? args[0] as bool : false;
                  final dialogType = args.length > 1 ? args[1] as String : 'stillWatching';
                  debugPrint("🎯 HTML Dialog result received: $result, type: $dialogType");

                  if (dialogType == 'nightShift') {
                    // Handle night shift dialog - result is always true for "I am Alert"
                    debugPrint("🌙 Night Shift: User confirmed alert status");
                    // Night shift service will handle the response via its own logic
                  } else {
                    // Handle still watching dialog
                    if (result) {
                      debugPrint("📺 Still Watching: User clicked YES - continue watching");
                    } else {
                      debugPrint("📺 Still Watching: User clicked NO - stop watching");
                    }
                  }
                },
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.CANCEL;
            },
            onLoadStop: (controller, url) async {
              // Hide Vimeo interface elements after page loads
              await Future.delayed(const Duration(milliseconds: 1000)); // Wait for Vimeo to load

              debugPrint("🚫 Hiding Vimeo interface elements");
              await controller.evaluateJavascript(source: '''
                try {
                  // Hide Vimeo header elements
                  var headerElements = [
                    '.topbar', '.header', '.vp-topbar', '.vp-title',
                    '[class*="topbar"]', '[class*="header"]', '[data-testid*="header"]',
                    '.vp-overlay-cell-title', '.vp-overlay-cell-byline',
                    '[aria-label*="Vimeo"]', '[title*="Vimeo"]',
                    '.vp-overlay-cell', '.vp-controls-wrapper .vp-controls',
                    'button[aria-label*="more"]', 'button[aria-label*="menu"]',
                    '.vp-button-more', '.vp-button-settings',
                    '.vp-controls .vp-controls-right .vp-button'
                  ];

                  headerElements.forEach(selector => {
                    var elements = document.querySelectorAll(selector);
                    elements.forEach(el => {
                      el.style.display = 'none !important';
                      el.style.visibility = 'hidden !important';
                      el.style.opacity = '0 !important';
                      el.style.pointerEvents = 'none !important';
                    });
                  });

                  // Add CSS to aggressively block Vimeo interface
                  var style = document.createElement('style');
                  style.textContent = \`
                    /* Completely hide ALL Vimeo branding and interface elements */
                    .topbar, .header, .vp-topbar, .vp-title, .vp-byline,
                    [class*="topbar"], [class*="header"], [class*="title"], [class*="byline"],
                    [data-testid*="header"], [data-testid*="title"], [data-testid*="overlay"],
                    .vp-overlay, .vp-overlay-cell, .vp-overlay-cell-title, .vp-overlay-cell-byline,
                    [aria-label*="Vimeo"], [title*="Vimeo"], [alt*="Vimeo"],
                    .vp-controls-wrapper .vp-controls, .vp-controls-right,
                    button[aria-label*="more"], button[aria-label*="menu"], button[aria-label*="settings"],
                    .vp-button-more, .vp-button-settings, .vp-button-prefs,
                    .vp-logo, .vp-badge, .vp-title-overlay,
                    a[href*="vimeo.com"], a[target="_blank"],
                    .vp-controls .vp-controls-right .vp-button:not(.vp-button-play):not(.vp-button-volume):not(.vp-button-fullscreen),
                    /* Hide login/signup prompts */
                    [class*="login"], [class*="signup"], [class*="join"],
                    /* Hide all overlay text and links */
                    .vp-text-tracks, .vp-captions, .vp-chapters,
                    /* Hide context menus */
                    .vp-menu, .vp-context-menu, .vp-dropdown {
                      display: none !important;
                      visibility: hidden !important;
                      opacity: 0 !important;
                      pointer-events: none !important;
                      position: absolute !important;
                      left: -9999px !important;
                      top: -9999px !important;
                      width: 0 !important;
                      height: 0 !important;
                    }

                    /* Aggressively block interaction areas */
                    .vp-player {
                      position: relative !important;
                    }

                    /* Block entire top area */
                    .vp-player::before {
                      content: '';
                      position: absolute !important;
                      top: 0 !important;
                      left: 0 !important;
                      width: 100% !important;
                      height: 80px !important;
                      background: transparent !important;
                      z-index: 99999 !important;
                      pointer-events: auto !important;
                      cursor: default !important;
                    }

                    /* Block entire right side */
                    .vp-player::after {
                      content: '';
                      position: absolute !important;
                      top: 0 !important;
                      right: 0 !important;
                      width: 100px !important;
                      height: 100% !important;
                      background: transparent !important;
                      z-index: 99999 !important;
                      pointer-events: auto !important;
                      cursor: default !important;
                    }

                    /* Block bottom-right area for logo */
                    body::after {
                      content: '';
                      position: fixed !important;
                      bottom: 10px !important;
                      right: 10px !important;
                      width: 80px !important;
                      height: 50px !important;
                      background: transparent !important;
                      z-index: 999999 !important;
                      pointer-events: auto !important;
                      cursor: default !important;
                    }
                  \`;
                  document.head.appendChild(style);

                  console.log('✅ Vimeo interface elements blocked');

                } catch(e) {
                  console.log('❌ Error blocking Vimeo interface:', e);
                }
              ''');
            },
          ),
          // Physical overlay to block Vimeo interface elements
          Positioned.fill(
            child: Stack(
              children: [
                // Block top area (Vimeo header, logo, login buttons)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    color: Colors.transparent,
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.transparent, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                // Block right side (3-dot menu, settings)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 80,
                  child: Container(
                    color: Colors.transparent,
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.transparent, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                // Block bottom-right corner (Vimeo logo)
                Positioned(
                  bottom: 10,
                  right: 10,
                  width: 60,
                  height: 40,
                  child: Container(
                    color: Colors.transparent,
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.transparent, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Enhanced Flutter-level overlay to block webview when dialogs are active
          // Especially important for screens >1400px where video height is 450px
          if (_isDialogActive)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.01), // Slight tint to ensure it's rendered
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      // Add a subtle border to help with rendering on larger screens
                      border: Border.all(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _togglePlayPause,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
          ),
          child: Text(
            isPlaying ? 'Pause Video' : 'Play Video',
            style: const TextStyle(fontSize: 16, color: Colors.white)
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _toggleFullScreen,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
          ),
          child: const Text(
            'Full Screen',
            style: TextStyle(fontSize: 16, color: Colors.white)
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfo(String videoTitle, String adminName, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          videoTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppUtils.getColorScheme(context).onSurface,
          ),
        ),
        const SizedBox(height: 5),
        if (adminName.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned by $adminName',
                style: TextStyle(
                  color: AppUtils.getColorScheme(context).onSurface.withAlpha(150),
                  fontSize: 10,
                ),
              ),
              Text(
                'Assigned on $date',
                style: TextStyle(
                  color: AppUtils.getColorScheme(context).onSurface.withAlpha(150),
                  fontSize: 10,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _AssignedCaregiverList extends StatefulWidget {
  final String categoryName;
  final String subCategoryName;
  final String videoId;

  const _AssignedCaregiverList({
    required this.categoryName,
    required this.subCategoryName,
    required this.videoId,
  });

  @override
  State<_AssignedCaregiverList> createState() => _AssignedCaregiverListState();
}

class _AssignedCaregiverListState extends State<_AssignedCaregiverList> {
  late Future<List<Map<String, dynamic>>> _caregiversFuture;
  final UserVideoServices _userVideoServices = UserVideoServices();

  @override
  void initState() {
    super.initState();
    _caregiversFuture = _userVideoServices.getAssignedCaregiverVideos(
      widget.categoryName,
      widget.subCategoryName,
      widget.videoId,
    ).first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _caregiversFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "No caregivers assigned to this video.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final caregivers = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Assigned Caregivers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppUtils.getColorScheme(context).onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: caregivers.length,
              itemBuilder: (context, index) {
                final caregiver = caregivers[index];
                return _CaregiverProgressCard(caregiver: caregiver);
              },
            ),
          ],
        );
      },
    );
  }
}

class _CaregiverProgressCard extends StatelessWidget {
  final Map<String, dynamic> caregiver;

  const _CaregiverProgressCard({required this.caregiver});

  @override
  Widget build(BuildContext context) {
    final progress = (caregiver['progress'] ?? 0.0).toDouble();
    final safeProgress = progress.clamp(0.0, 100.0);
    final profilePicture = caregiver['profilePicture'] ?? '';
    final caregiverName = caregiver['caregiverName'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUtils.getColorScheme(context).secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (profilePicture.isNotEmpty)
            CircleAvatar(
              radius: 25,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: profilePicture,
                  fit: BoxFit.cover,
                  width: 50,
                  height: 50,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.person,
                    size: 30,
                  ),
                ),
              ),
            )
          else
            CircleAvatar(
              radius: 25,
              backgroundColor: AppUtils.getColorScheme(context).primary,
              child: Text(
                caregiverName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiverName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: safeProgress / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppUtils.getColorScheme(context).primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Progress: ${safeProgress.toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}