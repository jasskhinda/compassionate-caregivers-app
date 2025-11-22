import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caregiver/component/other/show_still_watching_dialog.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/user_video_services.dart';
import '../../../../services/video_interaction_service.dart';
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
        _controller.pause();
        _stillWatchingTimer?.cancel(); // Stop timer when video is paused
      } else {
        _controller.play();
        _startStillWatchingTimer(); // Start timer when play is pressed
      }
      isPlaying = !isPlaying;
    });
  }
  void _toggleFullScreen() {
    _controller.toggleFullScreenMode();
  }

  void _startStillWatchingTimer() {
    if (_hasAskedStillWatching || _stillWatchingTimer != null) return;

    // Professional adaptive timing based on video duration
    final duration = _controller.metadata.duration.inSeconds;
    int delaySeconds;
    if (duration <= 30) {
      // Very short videos: 8-12 seconds
      delaySeconds = 8 + (DateTime.now().millisecondsSinceEpoch % 5);
    } else if (duration <= 120) {
      // Short videos (up to 2 mins): 15-25 seconds
      delaySeconds = 15 + (DateTime.now().millisecondsSinceEpoch % 11);
    } else if (duration <= 300) {
      // Medium videos (up to 5 mins): 25-35 seconds
      delaySeconds = 25 + (DateTime.now().millisecondsSinceEpoch % 11);
    } else {
      // Long videos: 30-45 seconds
      delaySeconds = 30 + (DateTime.now().millisecondsSinceEpoch % 16);
    }

    _stillWatchingTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_controller.value.isPlaying) {
        _controller.pause();
        isPlaying = false;
        setState(() {}); // Update play/pause button UI

        final result = await showStillWatchingDialog(context);
        if (result == true) {
          _controller.play();
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

      // Debug: Log video initialization
      debugPrint("Video initialized - ID: [PROTECTED] (${videoUrl?.isNotEmpty == true ? 'URL provided' : 'No URL'})");
      debugPrint("Video tracking parameters: userId: ${_auth.currentUser?.uid}, role: $_role");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (videoUrl != null && videoUrl!.isNotEmpty) {
          _initializePlayer();
        }
      });
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

  String? _extractYoutubeId(String url) {
    // Handle various YouTube URL formats
    final regexPatterns = [
      RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})'),  // youtu.be/VIDEO_ID or youtu.be/VIDEO_ID?params
      RegExp(r'youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11})'),  // youtube.com/watch?v=VIDEO_ID
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),  // youtube.com/embed/VIDEO_ID
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),  // youtube.com/v/VIDEO_ID
    ];

    for (final pattern in regexPatterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        final videoId = match.group(1);
        debugPrint("Regex matched! Extracted ID: $videoId from URL: $url");
        return videoId;
      }
    }

    // If no pattern matches, assume it's already a video ID (11 characters)
    if (!url.contains('/') && !url.contains('?') && url.length == 11) {
      debugPrint("URL appears to be a video ID already: $url");
      return url;
    }

    debugPrint("Failed to extract video ID from: $url");
    return null;
  }

  void _initializePlayer() {
    _hasAskedStillWatching = false;
    _stillWatchingTimer?.cancel();
    if (videoUrl == null || videoUrl!.isEmpty) return;

    // Extract YouTube video ID from URL
    final extractedId = _extractYoutubeId(videoUrl!);
    if (extractedId == null) {
      debugPrint("Failed to extract YouTube video ID from: $videoUrl");
      return;
    }

    debugPrint("Extracted YouTube ID: $extractedId from URL: $videoUrl");

    try {
      _controller = YoutubePlayerController(
        initialVideoId: extractedId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          controlsVisibleAtStart: true,
          hideControls: false,
        ),
      );
    } catch (e) {
      debugPrint("Error initializing YouTube player: $e");
      return;
    }

    _startStillWatchingTimer();

    // Track progress every second
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.value.isReady) {
        final duration = _controller.metadata.duration.inSeconds.toDouble();
        final currentPosition = _controller.value.position.inSeconds.toDouble();

        if (duration > 0) {
          double percent = (currentPosition / duration) * 100;
          watchedPercentage = percent.clamp(0, 100);
          setState(() {});
        }
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
      if (videoId == null || videoId!.isEmpty) {
        debugPrint("Video progress: videoId is null or empty");
        return;
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint("Video progress: User not authenticated");
        return;
      }

      debugPrint("Video progress: Updating progress for videoId: $videoId, percentage: ${percentage.toStringAsFixed(2)}%");

      final docRef = FirebaseFirestore.instance
          .collection('caregiver_videos')
          .doc(userId)
          .collection('videos')
          .doc(videoId);

      final docSnapshot = await docRef.get();
      final existingProgress = docSnapshot.data()?['progress'] ?? 0.0;

      debugPrint("Video progress: Existing progress: ${existingProgress.toStringAsFixed(2)}%");

      // Only update if the new progress is higher
      if (percentage > existingProgress) {
        await docRef.set({
          'progress': percentage,
          'lastUpdated': FieldValue.serverTimestamp(),
          'videoTitle': args?['videoTitle'] ?? 'Unknown',
          'videoUrl': videoUrl ?? '',
          'userId': userId,
          'lastWatchSession': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("Video progress: Successfully updated to ${percentage.toStringAsFixed(2)}%");
      } else {
        debugPrint("Video progress: No update needed (${percentage.toStringAsFixed(2)}% <= ${existingProgress.toStringAsFixed(2)}%)");
      }
    } catch (e) {
      debugPrint("Video progress: Error updating progress: $e");
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _updateTimer?.cancel();
    _stillWatchingTimer?.cancel();
    _controller.dispose();
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: _isPlayerReady
          ? YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppUtils.getColorScheme(context).primary,
              progressColors: ProgressBarColors(
                playedColor: AppUtils.getColorScheme(context).primary,
                handleColor: AppUtils.getColorScheme(context).primary,
              ),
              aspectRatio: 16 / 9,
            )
          : videoUrl != null && videoUrl!.isNotEmpty && _extractYoutubeId(videoUrl!) == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Invalid YouTube URL format.\nPlease use format like:\nhttps://youtu.be/VIDEO_ID\nor\nhttps://youtube.com/watch?v=VIDEO_ID',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
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