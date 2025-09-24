import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/category_services.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class UploadVideoDialog extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;
  const UploadVideoDialog({
    Key? key,
    required this.categoryName,
    required this.subcategoryName,
  }) : super(key: key);

  @override
  State<UploadVideoDialog> createState() => _UploadVideoDialogState();
}

class _UploadVideoDialogState extends State<UploadVideoDialog> {
  XFile? _pickedVideo;
  bool _isUploading = false;
  String _statusText = '';
  final ImagePicker _picker = ImagePicker();
  late TextEditingController titleController = TextEditingController();
  final firestore = CategoryServices();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _pickedVideo = video;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_pickedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a video first!')),
      );
      return;
    }

    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter title first")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _statusText = 'Preparing upload...';
    });

    try {
      const String accessToken = 'f40be83da238cc225057b64716aae8e2';  // Replace with your token
      final Dio dio = Dio()
        ..options.headers['Authorization'] = 'Bearer $accessToken'
        ..options.headers['Accept'] = 'application/vnd.vimeo.*+json;version=3.4';

      // Step 1: Create upload ticket
      final int videoSize = await _pickedVideo!.length();
      final createVideoResponse = await dio.post(
        'https://api.vimeo.com/me/videos',
        data: {
          'upload': {
            'approach': 'tus',
            'size': videoSize,
          },
          'name': titleController.text.trim(),
          'privacy': {'view': 'unlisted'},
          'download': true,
        },
      );

      final String uploadLink = createVideoResponse.data['upload']['upload_link'];
      final String videoUri = createVideoResponse.data['uri'];
      final String videoId = videoUri.split('/').last;

      setState(() {
        _statusText = 'Uploading video...';
      });

      final bytes = await _pickedVideo!.readAsBytes();
      final stream = Stream.fromIterable([bytes]);

      // Step 2: Upload video bytes
      await dio.patch(
        uploadLink,
        data: stream,
        options: Options(
          headers: {
            'Tus-Resumable': '1.0.0',
            'Upload-Offset': '0',
            'Content-Type': 'application/offset+octet-stream',
          },
          maxRedirects: 0,
          receiveTimeout: Duration.zero,
          sendTimeout: Duration.zero,
        ),
      );

      setState(() {
        _statusText = 'Processing video...';
      });

      // Step 3: Wait for Vimeo to finish processing
      String? mp4Link;
      const maxRetries = 15;
      int retries = 0;
      Response? lastResponse;

      while (retries < maxRetries) {
        final response = await dio.get('https://api.vimeo.com/videos/$videoId');
        lastResponse = response;

        final transcodeStatus = response.data['transcode']['status'] ?? '';
        print("Video status: $transcodeStatus");

        if (transcodeStatus == 'complete') {
          final files = response.data['files'];
          if (files != null && files is List) {
            for (var file in files) {
              if (file['quality'] == 'hd' && file['mime_type'] == 'video/mp4') {
                mp4Link = file['link'];
                break;
              }
            }
            if (mp4Link == null) {
              for (var file in files) {
                if (file['mime_type'] == 'video/mp4') {
                  mp4Link = file['link'];
                  break;
                }
              }
            }
          }
          break;
        } else if (transcodeStatus == 'error') {
          throw Exception('Video processing failed on Vimeo');
        }

        await Future.delayed(const Duration(seconds: 5));
        retries++;
      }

      // Step 4: Fallback if direct mp4 link not found
      if (mp4Link == null && lastResponse != null) {
        final playerUrl = lastResponse.data['player_embed_url'];
        final uri = Uri.tryParse(playerUrl ?? '');
        final hash = uri?.queryParameters['h'];

        if (hash != null && hash.isNotEmpty) {
          mp4Link = "https://player.vimeo.com/video/$videoId?h=$hash";
        } else {
          mp4Link = "https://player.vimeo.com/video/$videoId";
        }
      }

      setState(() {
        _statusText = 'Saving video link to Firestore...';
      });

      // Step 5: Save video info
      await firestore.addVideo(
        categoryName: widget.categoryName,
        subcategoryName: widget.subcategoryName,
        title: titleController.text.trim(),
        youtubeLink: mp4Link.toString(),
        uploadedAt: DateTime.now(),
        isVimeo: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded and processed!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      print('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Private Video',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _pickedVideo != null
                  ? Text('Selected: ${_pickedVideo!.path.split('/').last}')
                  : const Text('No video selected'),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Video Title"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Pick Video'),
              ),
              const SizedBox(height: 10),
              _isUploading
                  ? Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(_statusText),
                ],
              )
                  : ElevatedButton.icon(
                onPressed: _uploadVideo,
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text('Upload private video',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppUtils.getColorScheme(context)
                      .tertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}