import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver/utils/appRoutes/assets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../../component/other/input_text_fields/text_input.dart';
import '../../../../../utils/app_utils/AppUtils.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {

  // User info variable
  String? _name;
  String? _role;
  String? _password;
  String? _mobileNumber;
  String? _dob;
  String? _profileImageUrl;
  String? _shiftType;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  XFile? _imageFile;
  String? _imageError;

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Check edit button is clicked or not
  bool _isEditing = false;

  // Edit Text Controller
  late TextEditingController _usernameController = TextEditingController();
  late TextEditingController _mobileController = TextEditingController();
  late TextEditingController _dobController = TextEditingController();
  late TextEditingController _emailController = TextEditingController();

  // Get user info
  Future<void> _getUserInfo() async {
    try {
      DocumentSnapshot document = await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          _role = data['role'];
          _password = data['password'];
          _name = data['name'];
          _mobileNumber = data['mobile_number'];
          _dob = data['dob'];
          _profileImageUrl = data['profile_image_url'];
          _shiftType = data['shift_type'] ?? 'Day';
          _usernameController.text = _name ?? '';
          _emailController.text = _auth.currentUser!.email ?? '';
          _mobileController.text = _mobileNumber ?? '';
          _dobController.text = _dob ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  // Pick image from gallery with validation
  Future<void> _pickImage() async {
    if (!_isEditing) return;

    try {
      setState(() {
        _imageError = null;
        _isUploadingImage = true;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Validate file size (max 5MB)
        final bytes = await pickedFile.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          setState(() {
            _imageError = 'Image size must be less than 5MB';
            _isUploadingImage = false;
          });
          return;
        }

        // Validate file type
        final fileName = pickedFile.name.toLowerCase();
        if (!fileName.endsWith('.jpg') &&
            !fileName.endsWith('.jpeg') &&
            !fileName.endsWith('.png')) {
          setState(() {
            _imageError = 'Please select a valid image file (JPG, JPEG, PNG)';
            _isUploadingImage = false;
          });
          return;
        }

        setState(() {
          _imageFile = pickedFile;
          _imageError = null;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image selected successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _imageError = 'Failed to select image. Please try again.';
        _isUploadingImage = false;
      });
      debugPrint("Error picking image: $e");
    }
  }

  // Update user info with enhanced error handling
  Future<void> _updateUserInfo() async {
    // Clear any previous errors
    setState(() {
      _imageError = null;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _imageFile != null ? 'Uploading profile picture...' : 'Updating profile...',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      },
    );

    try {
      String? newImageUrl = _profileImageUrl;

      // Only upload image if a new one was picked
      if (_imageFile != null) {
        try {
          String fileName = 'profile_images/${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          Reference storageRef = _storage.ref().child(fileName);

          UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await _imageFile!.readAsBytes();
            uploadTask = storageRef.putData(
              bytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                cacheControl: 'public, max-age=31536000',
              ),
            );
          } else {
            uploadTask = storageRef.putFile(File(_imageFile!.path));
          }

          // Monitor upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
          });

          TaskSnapshot taskSnapshot = await uploadTask;
          newImageUrl = await taskSnapshot.ref.getDownloadURL();

          debugPrint('✅ Image uploaded successfully: $newImageUrl');
        } catch (uploadError) {
          debugPrint('❌ Image upload failed: $uploadError');
          if (mounted) {
            Navigator.pop(context); // Hide loading dialog
            setState(() {
              _imageError = 'Failed to upload image. Please try again.';
            });
          }
          return;
        }
      }

      // Skip email update for now - requires re-authentication with password
      // TODO: Add password prompt dialog if email needs to be changed
      final user = _auth.currentUser!;

      await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .set({
            'name': _usernameController.text.toString(),
            'mobile_number': _mobileController.text.toString(),
            'dob': _dobController.text.toString(),
            'profile_image_url': newImageUrl,
            // Only store shift type for Caregivers
            if (_role == 'Caregiver' && _shiftType != null) 'shift_type': _shiftType,
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context); // Hide the loading dialog
      setState(() {
        _isEditing = false;
        _profileImageUrl = newImageUrl;
        _imageFile = null;
        _imageError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(_imageFile != null
                  ? "Profile and picture updated successfully"
                  : "Profile updated successfully"),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide the loading dialog
      debugPrint("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _getUserInfo();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            EditProfileAppBar(
              title: 'Edit Profile',
              done: _isEditing ? 'Cancel' : 'Edit',
              onTap: () => setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  // Cancel editing - clear any selected image and errors
                  _imageFile = null;
                  _imageError = null;
                }
              }),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: AppUtils.getScreenSize(context).width >= 600
                      ? AppUtils.getScreenSize(context).width * 0.45
                      : AppUtils.getScreenSize(context).width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        _isLoading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink(),

                        Center(
                          child: GestureDetector(
                            onTap: _isEditing ? _pickImage : null,
                            child: Stack(
                              children: [
                                Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppUtils.getColorScheme(context).primary.withOpacity(0.3),
                                      width: 3,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(60),
                                    child: _isUploadingImage
                                        ? Container(
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        : _imageFile != null
                                            ? kIsWeb
                                                ? FutureBuilder<Uint8List>(
                                                    future: _imageFile!.readAsBytes(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Image.memory(
                                                          snapshot.data!,
                                                          fit: BoxFit.cover,
                                                          height: 120,
                                                          width: 120,
                                                        );
                                                      }
                                                      return const Center(
                                                        child: CircularProgressIndicator(),
                                                      );
                                                    },
                                                  )
                                                : Image.file(
                                                    File(_imageFile!.path),
                                                    fit: BoxFit.cover,
                                                    height: 120,
                                                    width: 120,
                                                  )
                                            : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: _profileImageUrl!,
                                                    fit: BoxFit.cover,
                                                    height: 120,
                                                    width: 120,
                                                    placeholder: (context, url) => Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Container(
                                                      color: Colors.grey.shade200,
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 60,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    color: Colors.grey.shade200,
                                                    child: Icon(
                                                      Icons.person,
                                                      size: 60,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                  ),
                                ),
                                if (_isEditing && !_isUploadingImage)
                                  Positioned(
                                    bottom: 5,
                                    right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppUtils.getColorScheme(context).primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Error message for image selection
                        if (_imageError != null)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _imageError!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Instructions for image upload
                        if (_isEditing)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tap the profile picture to select a new image (JPG, PNG, max 5MB)',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 40),
                        Text(
                          'Full Name',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSurface
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextInput(
                            keyboardType: TextInputType.name,
                            obscureText: false,
                            isEnabled: _isEditing ? false : true,
                            onChanged: (value) {
                              setState(() {});
                            },
                            controller: _usernameController,
                            labelText: 'Full Name',
                            hintText: 'e.g. john doe',
                            errorText: '',
                            prefixIcon: Icon(Icons.person_outline, color: AppUtils.getColorScheme(context).tertiaryContainer),
                            suffixIcon: _usernameController.text.isNotEmpty ?
                            IconButton(
                                onPressed: (){
                                  _isEditing ? _usernameController.clear() : null;
                                  setState(() {});
                                },
                                icon: Icon(
                                    _isEditing ? Icons.clear : null,
                                    color: AppUtils.getColorScheme(context).tertiaryContainer)
                            ) : null
                        ),

                        Text(
                          'Email Address',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSurface
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextInput(
                            keyboardType: TextInputType.emailAddress,
                            obscureText: false,
                            isEnabled: _role == 'Admin' ? _isEditing ? false : true : true,
                            onChanged: (value) {
                              setState(() {});
                            },
                            controller: _emailController,
                            labelText: 'Enter your email',
                            hintText: 'e.g. john@gmail.com',
                            errorText: '',
                            prefixIcon: Icon(Icons.email_outlined, color: AppUtils.getColorScheme(context).tertiaryContainer),
                            suffixIcon: IconButton(
                                onPressed: (){
                                  _isEditing ? _emailController.clear() : null;
                                  setState(() {});
                                },
                                icon: Icon(
                                    _isEditing ? Icons.clear : null,
                                    color: AppUtils.getColorScheme(context).tertiaryContainer)
                            )
                        ),

                        if(_role == 'Admin')
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Address',
                                style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppUtils.getColorScheme(context).onSurface
                                ),
                              ),
                            ],
                          ),

                        Text(
                          'Mobile Number',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSurface
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextInput(
                            keyboardType: TextInputType.phone,
                            obscureText: false,
                            isEnabled: _isEditing ? false : true,
                            onChanged: (value) {
                              setState(() {});
                            },
                            controller: _mobileController,
                            labelText: 'Mobile Number',
                            hintText: 'e.g. 8252141234',
                            errorText: '',
                            prefixIcon: Icon(Icons.call, color: AppUtils.getColorScheme(context).tertiaryContainer),
                            suffixIcon: _mobileController.text.isNotEmpty ?
                            IconButton(
                                onPressed: (){
                                  _isEditing ? _mobileController.clear() : null;
                                  setState(() {});
                                },
                                icon: Icon(
                                    _isEditing ? Icons.clear : null,
                                    color: AppUtils.getColorScheme(context).tertiaryContainer)
                            ) : null
                        ),

                        Text(
                          'Date of Birth',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppUtils.getColorScheme(context).onSurface
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _isEditing
                              ? () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime(2000),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );

                            if (pickedDate != null) {
                              String formattedDate = "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
                              _dobController.text = formattedDate;
                              setState(() {});
                            }
                          }
                              : null,
                          child: AbsorbPointer(
                            absorbing: true,
                            child: TextInput(
                              obscureText: false,
                              controller: _dobController,
                              labelText: 'Date of birth',
                              hintText: 'e.g. 21/04/2003',
                              errorText: '',
                              prefixIcon: Icon(Icons.date_range, color: AppUtils.getColorScheme(context).tertiaryContainer),
                              suffixIcon: _dobController.text.isNotEmpty
                                  ? IconButton(
                                onPressed: () {
                                  _isEditing ? _dobController.clear() : null;
                                  setState(() {});
                                },
                                icon: Icon(
                                  _isEditing ? Icons.clear : null,
                                  color: AppUtils.getColorScheme(context).tertiaryContainer,
                                ),
                              )
                                  : null,
                            ),
                          ),
                        ),

                        // Shift Type - only for Caregivers (not editable by themselves)
                        if (_role == 'Caregiver' && _shiftType != null) ...[
                          Text(
                            'Shift Type',
                            style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppUtils.getColorScheme(context).onSurface
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _shiftType ?? 'Day',
                            decoration: InputDecoration(
                              labelText: 'Shift Type',
                              helperText: 'Night shift caregivers will receive periodic alerts to ensure attentiveness during shift hours',
                              helperMaxLines: 2,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabled: _isEditing,
                            ),
                            items: ['Day', 'Night'].map((String shift) {
                              return DropdownMenuItem(
                                value: shift,
                                child: Text('$shift Shift'),
                              );
                            }).toList(),
                            onChanged: _isEditing ? (value) {
                              setState(() {
                                _shiftType = value;
                              });
                            } : null,
                          ),
                          const SizedBox(height: 14),
                        ],

                        const SizedBox(height: 14),

                        _isEditing ? Center(
                          child: MaterialButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)
                            ),
                            height: 55,
                            onPressed: ()  {
                              _updateUserInfo();
                            },
                            color: AppUtils.getColorScheme(context).tertiaryContainer,
                            child: const Text('Save', style: TextStyle(color: Colors.white)),
                          ),
                        ) : const SizedBox()
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        )
    );
  }
}

class EditProfileAppBar extends StatelessWidget {
  final String title;
  final String done;
  final void Function()? onTap;

  const EditProfileAppBar({
    super.key,
    this.onTap,
    required this.title,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {

    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return SliverAppBar(
      floating: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                      color: AppUtils.getColorScheme(context).onSurface,
                      fontWeight: FontWeight.bold
                  )
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
                done,
                style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue
                )
            ),
          )
        ],
      ),
    );
  }
}