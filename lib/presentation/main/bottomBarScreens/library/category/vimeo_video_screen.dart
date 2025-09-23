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

  bool isPlaying = false;
  bool isFullScreen = false;
  bool _isDialogActive = false;

  String _generateHtmlData(String videoUrl) {
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
  </style>
</head>
<body>
  <div class="video-container">
    <iframe id="vimeo-player" src="$videoUrl&title=0&byline=0&portrait=0&badge=0&playsinline=1&gesture=media"
      frameborder="0" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen>
    </iframe>
    <div class="block-top"></div>
    <div class="block-bottom"></div>
    <div class="click-overlay" onclick="simulateTap()"></div>
  </div>
  <div id="dialog-blocker" class="dialog-blocker"></div>

  <script>
    const iframe = document.getElementById('vimeo-player');
    const player = new Vimeo.Player(iframe);

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

    // Wait for player to be ready
    player.ready().then(function() {
      console.log('Vimeo player ready');
      callFlutter('vimeoReady');
    });

    // Track progress updates
    player.on('timeupdate', function(data) {
      console.log('Vimeo timeupdate:', data.seconds, '/', data.duration);
      callFlutter('videoProgress', data.seconds, data.duration);
    });

    // Track play/pause events
    player.on('play', function() {
      console.log('Vimeo play started');
      callFlutter('videoPlay');
    });

    player.on('pause', function() {
      console.log('Vimeo paused');
      callFlutter('videoPause');
    });

    // Functions to disable/enable iframe interaction
    window.disableVideoInteraction = function() {
      console.log('🚫 Disabling video interaction for dialog');
      const iframe = document.getElementById('vimeo-player');
      const blocker = document.getElementById('dialog-blocker');

      if (iframe) {
        iframe.classList.add('dialog-active');
        iframe.style.pointerEvents = 'none';
        iframe.style.zIndex = '-1';
      }

      if (blocker) {
        blocker.classList.add('active');
        console.log('🚫 Dialog blocker activated');
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

      if (iframe) {
        iframe.classList.remove('dialog-active');
        iframe.style.pointerEvents = 'auto';
        iframe.style.zIndex = '1';
      }

      if (blocker) {
        blocker.classList.remove('active');
        console.log('✅ Dialog blocker deactivated');
      }
    };
  </script>
</body>
</html>
''';
  }

  void _startStillWatchingTimer() {
    if (_hasAskedStillWatching || _stillWatchingTimer != null) return;

    final delaySeconds = 10 + (DateTime.now().millisecondsSinceEpoch % 21); // 10-30 sec random

    _stillWatchingTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!mounted) return;

      _hasAskedStillWatching = true;
      _stillWatchingTimer = null;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Pause Vimeo video by sending postMessage to iframe
        const jsCode = "document.querySelector('video').pause();";
        await _webViewController!.evaluateJavascript(source: jsCode);
        setState(() => isPlaying = !isPlaying);

        final result = await showStillWatchingDialog(context);

        // No auto play or pause on dialog buttons
        debugPrint("Still watching dialog closed with result: $result");
      });
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
      debugPrint("Vimeo Video initialized - videoId: $videoId, videoUrl: $videoUrl");
      debugPrint("Vimeo tracking parameters: userId: ${_auth.currentUser?.uid}, role: $_role");

      // Start paused, so no auto-play on load
      isPlaying = false;

      _startTrackingProgress();
    }
  }

  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() => _role = data['role']);
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
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
      appBar: AppBar(title: const Text("Vimeo Player")),
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
      height: AppUtils.getScreenSize(context).width > 1400 ? 450 : 250,
      width: double.infinity,
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(vimeoUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
              supportZoom: false,
              disableContextMenu: true,
              transparentBackground: true,
              useShouldOverrideUrlLoading: true,
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
              final htmlData = _generateHtmlData(videoUrl!);

              await controller.loadData(
                data: htmlData,
                baseUrl: WebUri("about:blank"),
                mimeType: 'text/html',
                encoding: 'utf-8',
              );

              controller.addJavaScriptHandler(
                handlerName: 'vimeoReady',
                callback: (args) {
                  debugPrint("🎬 Vimeo player ready for videoId: $videoId");
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
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.CANCEL;
            },
            onLoadStop: (controller, url) async {
              // No DOM manipulation needed
            },
          ),
          // Flutter-level overlay to block webview when dialogs are active
          if (_isDialogActive)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(),
                ),
              ),
            ),
        ],
      ),
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