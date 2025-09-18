import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caregiver/component/other/show_still_watching_dialog.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/user_video_services.dart';
import '../../../../utils/app_utils/AppUtils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // Instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _stillWatchingTimer;
  bool _hasAskedStillWatching = false;

  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
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

  // Track whether the video
  bool isPlaying = true;
  bool isFullScreen = false;
  void _togglePlayPause() {
    setState(() {
      if (isPlaying) {
        _controller.pauseVideo();
        _stillWatchingTimer?.cancel(); // Stop timer when video is paused
      } else {
        _controller.playVideo();
        _startStillWatchingTimer(); // Start timer when play is pressed
      }
      isPlaying = !isPlaying;
    });
  }
  void _toggleFullScreen() {
    isFullScreen = !isFullScreen;
  }

  void _startStillWatchingTimer() {
    if (_hasAskedStillWatching || _stillWatchingTimer != null) return;

    // Pick random delay between 10 to 30 seconds
    final int delaySeconds = 10 + (DateTime.now().millisecondsSinceEpoch % 21);

    _stillWatchingTimer = Timer(Duration(seconds: delaySeconds), () async {
      final playerState = await _controller.playerState;

      if (playerState == PlayerState.playing) {
        _controller.pauseVideo();
        isPlaying = false;
        setState(() {}); // Update play/pause button UI

        final result = await showStillWatchingDialog(context);
        if (result == true) {
          _controller.playVideo();
          isPlaying = true;
        } else {
          // Explicitly keep it paused
          isPlaying = false;
        }
        setState(() {});
      }

      _hasAskedStillWatching = true; // Only ask once
      _stillWatchingTimer = null;
    });
  }
  // Future<void> rewind() async {
  //   final currentTime = await _controller.currentTime;  // Get current time as double
  //   final newTime = (currentTime - 10).clamp(0.0, currentTime);  // Ensure time doesn't go negative
  //
  //   // Seek to the new time, and make sure to start playing if it was paused
  //   _controller.seekTo(seconds: newTime);
  //   _controller.playVideo();  // Explicitly start playing
  // }
  // Future<void> forward() async {
  //   final currentTime = await _controller.currentTime;  // Get current time as double
  //   final newTime = currentTime + 10;  // Add 10 seconds
  //
  //   // Seek to the new time
  //   _controller.seekTo(seconds: newTime);
  //   _controller.playVideo();  // Explicitly start playing
  // }

  @override
  void initState() {
    super.initState();
    _getUserInfo();
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (videoUrl != null && videoUrl!.isNotEmpty) {
          _initializePlayer();
        }
      });
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
        setState(() {
          _role = data['role'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
    }
  }

  void _initializePlayer() {
    _hasAskedStillWatching = false;
    _stillWatchingTimer?.cancel();
    if (videoUrl == null || videoUrl!.isEmpty) return;

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        mute: false,                     // Keep sound on
        showControls: false,             // Hides play/pause, volume, etc.
        showFullscreenButton: false,     // Disables fullscreen button
        showVideoAnnotations: false,     // Disables video annotations
        pointerEvents: PointerEvents.none, // Disables all interaction
        loop: false,                     // No loop
        playsInline: true,               // Plays inline, not fullscreen
        strictRelatedVideos: true,      // Reduces related videos showing after playback
        enableJavaScript: false,         // Disables JavaScript interaction
        enableCaption: false,            // Disables captions
        captionLanguage: 'en',           // Set caption language (if enabled)
      ),
    )..loadVideoById(videoId: videoUrl!);

    _startStillWatchingTimer();

    // Track progress every second
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final duration = await _controller.duration;
      final currentPosition = await _controller.currentTime;

      if (duration > 0) {
        double percent = (currentPosition / duration) * 100;
        watchedPercentage = percent.clamp(0, 100);
        setState(() {});
      }
    });

    // Update Firestore every 5 seconds to reduce writes
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_role == "Caregiver") {
        _updateProgressInFirestore(watchedPercentage);
      }
    });

    setState(() {
      _isPlayerReady = true;
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

      // Only update if the new progress is higher
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
    _stillWatchingTimer?.cancel();
    try {
      _controller.close();
    } catch (e) {
      debugPrint('Error closing controller: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoTitle = args?['videoTitle'] ?? 'Default Video Title';
    final date = args?['date'] ?? 'Default Date';
    final adminName = args?['adminName'] ?? '';
    final categoryName = args?['categoryName'] ?? '';
    final subcategoryName = args?['subcategoryName'] ?? '';
    final videoID = args?['videoId'] ?? '';
    final progress = args?['progress'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("YouTube Player")),
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: AppUtils.getScreenSize(context).width >= 600
                ? isFullScreen ? double.infinity : AppUtils.getScreenSize(context).width * 0.45
                : double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoPlayer(),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ElevatedButton(
                      //   onPressed: rewind,
                      //   style: ElevatedButton.styleFrom(
                      //       padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      //       backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
                      //   ),
                      //   child: const Icon(Icons.replay_10, color: Colors.white),
                      // ),
                      // const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _togglePlayPause,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                          backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
                        ),
                        child: Text(isPlaying ? 'Pause Video' : 'Play Video', style: const TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _toggleFullScreen,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                            backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
                        ),
                        child: const Text('Full Screen', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                      // const SizedBox(width: 10),
                      // ElevatedButton(
                      //   onPressed: forward,
                      //   style: ElevatedButton.styleFrom(
                      //       padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      //       backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer
                      //   ),
                      //   child: const Icon(Icons.forward_10_rounded, color: Colors.white),
                      // ),
                    ],
                  ),
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

  Widget _buildVideoPlayer() {
    return SizedBox(
      height: AppUtils.getScreenSize(context).width >= 600
          ? isFullScreen ? AppUtils.getScreenSize(context).height * 0.8 : 350
          : isFullScreen ? AppUtils.getScreenSize(context).height * 0.8 : 250,
      width: AppUtils.getScreenSize(context).width >= 600
          ? isFullScreen ? double.infinity : AppUtils.getScreenSize(context).width * 0.45
          : double.infinity,
      child: _isPlayerReady
          ? ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Transform.rotate(
                  angle: AppUtils.getScreenSize(context).width <= 600 ? isFullScreen ? 90 * 3.14159 / 180 : 0 : 0,  // Rotate to 90 degrees when fullscreen
                  child: YoutubePlayer(controller: _controller,),
                ),
          )
          : const Center(child: CircularProgressIndicator()),
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
              "No caregiver has watched this video.",
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
              'Video Insights',
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