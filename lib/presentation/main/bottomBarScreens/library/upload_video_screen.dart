import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caregiver/component/appBar/settings_app_bar.dart';
import 'package:caregiver/component/other/basic_button.dart';
import 'package:caregiver/component/other/upload_video_dialog.dart';
import 'package:caregiver/services/category_services.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CategoryServices _categoryServices = CategoryServices();

  String? _selectedCategory;
  String? _selectedSubcategory;
  List<Map<String, dynamic>> _categories = [];
  List<String> _subcategories = [];
  bool _isLoading = true;

  // Text controllers
  late TextEditingController _titleController;
  late TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _linkController = TextEditingController();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _categoryServices.getCategories().listen((snapshot) {
        final categories = snapshot.docs.map((doc) => {
          'name': doc.id,
          'data': doc.data(),
        }).toList();

        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadSubcategories(String categoryName) async {
    try {
      _categoryServices.getSubcategories(categoryName).listen((snapshot) {
        final subcategories = snapshot.docs.map((doc) => doc.id).toList();
        setState(() {
          _subcategories = subcategories;
          _selectedSubcategory = null;
        });
      });
    } catch (e) {
      debugPrint('Error loading subcategories: $e');
    }
  }

  Future<void> _uploadYouTubeVideo() async {
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category and subcategory'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty || _linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter video title and YouTube link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _categoryServices.addVideo(
        categoryName: _selectedCategory!,
        subcategoryName: _selectedSubcategory!,
        title: _titleController.text.trim(),
        youtubeLink: _linkController.text.trim(),
        uploadedAt: DateTime.now(),
        isVimeo: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _titleController.clear();
        _linkController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedSubcategory = null;
          _subcategories = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVimeoUploadDialog() {
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category and subcategory first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UploadVideoDialog(
        categoryName: _selectedCategory!,
        subcategoryName: _selectedSubcategory!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SettingsAppBar(title: 'Upload Videos'),

          SliverToBoxAdapter(
            child: Center(
              child: SizedBox(
                width: AppUtils.getScreenSize(context).width >= 600
                    ? AppUtils.getScreenSize(context).width * 0.45
                    : double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Instructions
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Upload Videos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select a category and subcategory, then choose your upload method.',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Category Selection
                            Text(
                              'Select Category',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppUtils.getColorScheme(context).onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  hint: const Text('Choose Category'),
                                  isExpanded: true,
                                  items: _categories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category['name'],
                                      child: Text(category['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _selectedSubcategory = null;
                                      _subcategories = [];
                                    });
                                    if (value != null) {
                                      _loadSubcategories(value);
                                    }
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subcategory Selection
                            Text(
                              'Select Subcategory',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppUtils.getColorScheme(context).onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSubcategory,
                                  hint: const Text('Choose Subcategory'),
                                  isExpanded: true,
                                  items: _subcategories.map((subcategory) {
                                    return DropdownMenuItem<String>(
                                      value: subcategory,
                                      child: Text(subcategory),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSubcategory = value;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Upload Options
                            Text(
                              'Upload Options',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppUtils.getColorScheme(context).onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // YouTube Upload Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.video_library, color: Colors.red.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'YouTube Video',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  TextField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Video Title',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  TextField(
                                    controller: _linkController,
                                    decoration: const InputDecoration(
                                      labelText: 'YouTube Link',
                                      hintText: 'https://youtu.be/...',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _uploadYouTubeVideo,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text(
                                        'Upload YouTube Video',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Vimeo Upload Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.cloud_upload, color: Colors.blue.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Upload Video File',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  const Text(
                                    'Upload video files directly from your device',
                                    style: TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _showVimeoUploadDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text(
                                        'Upload Video File',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}