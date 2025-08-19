import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:caregiver/component/other/show_still_watching_dialog.dart';
import '../../../../../services/user_video_services.dart';
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

  <script>
    const iframe = document.getElementById('vimeo-player');
    const player = new Vimeo.Player(iframe);

    window.flutter_inappwebview.callHandler('vimeoReady');

    player.on('timeupdate', function(data) {
      window.flutter_inappwebview.callHandler('videoProgress', data.seconds, data.duration);
    });
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
      if (videoId == null || videoId!.isEmpty) return;

      final docRef = FirebaseFirestore.instance
          .collection('caregiver_videos')
          .doc(_auth.currentUser!.uid)
          .collection('videos')
          .doc(videoId);

      final docSnapshot = await docRef.get();
      final existingProgress = docSnapshot.data()?['progress'] ?? 0.0;

      if (percentage > existingProgress) {
        await docRef.set({
          'progress': percentage,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error updating progress: $e");
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _updateTimer?.cancel();
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
                  if (_role == 'Admin' && videoUrl != null && _categoryName != null && _subCategoryName != null)
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
              final htmlData = _generateHtmlData(videoUrl!);

              await controller.loadData(
                data: htmlData,
                baseUrl: WebUri("about:blank"),
                mimeType: 'text/html',
                encoding: 'utf-8',
              );

              controller.addJavaScriptHandler(
                handlerName: 'videoProgress',
                callback: (args) {
                  final seconds = args[0] as double;
                  final duration = args[1] as double;
                  if (duration > 0) {
                    final percent = (seconds / duration) * 100;
                    if (mounted) {
                      setState(() {
                        watchedPercentage = percent.clamp(0, 100);
                      });
                    }
                  }
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

                    // Show the dialog
                    final result = await showStillWatchingDialog(context);

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
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.CANCEL;
            },
            onLoadStop: (controller, url) async {
              // No DOM manipulation needed
            },
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