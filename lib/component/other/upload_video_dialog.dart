import 'dart:io';
import 'package:flutter/material.dart';
import 'package:healthcare/utils/app_utils/AppUtils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../services/category_services.dart';

class UploadVideoDialog extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;
  const UploadVideoDialog({Key? key, required this.categoryName, required this.subcategoryName}) : super(key: key);

  @override
  State<UploadVideoDialog> createState() => _UploadVideoDialogState();
}

class _UploadVideoDialogState extends State<UploadVideoDialog> {
  File? _pickedVideo;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  // Text editing controller
  late TextEditingController titleController = TextEditingController();

  // Instance
  final firestore = CategoryServices();

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _pickedVideo = File(video.path);
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
    });

    try {
      const String accessToken = '3d0f74456105a59c9acc288773ddbc70'; // <-- Add your token here

      final Dio dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $accessToken';
      dio.options.headers['Accept'] = 'application/vnd.vimeo.*+json;version=3.4';

      // 1. Create an upload ticket
      final uploadTicketResponse = await dio.post(
        'https://api.vimeo.com/me/videos',
        data: {
          'upload': {
            'approach': 'tus',
            'size': _pickedVideo!.lengthSync().toString(),
          }
        },
      );

      final String uploadLink = uploadTicketResponse.data['upload']['upload_link'];
      final String videoUri = uploadTicketResponse.data['uri']; // Will be like '/videos/123456789'

      // 2. Upload the file using TUS protocol
      await dio.patch(
        uploadLink,
        data: _pickedVideo!.openRead(),
        options: Options(
          headers: {
            'Tus-Resumable': '1.0.0',
            'Upload-Offset': '0',
            'Content-Type': 'application/offset+octet-stream',
          },
        ),
      );

      // 3. Extract the video id
      final String videoId = videoUri.split('/').last;
      final String vimeoLink = "https://vimeo.com/$videoId";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video uploaded successfully! Vimeo link: $vimeoLink')),
      );

      firestore.addVideo(
          categoryName: widget.categoryName,
          subcategoryName: widget.subcategoryName,
          title: titleController.text.trim(),
          youtubeLink: vimeoLink,
          uploadedAt: DateTime.now(),
          isVimeo: false
      );

      Navigator.pop(context); // Close the dialog after upload

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
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
                'Upload Video',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),

              _pickedVideo != null
                  ? Text(
                'Selected: ${_pickedVideo!.path.split('/').last}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              )
                  : const Text(
                'No video selected',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
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
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: _uploadVideo,
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text('Upload to Vimeo', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
