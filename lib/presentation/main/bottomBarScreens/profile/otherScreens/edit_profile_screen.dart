import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:healthcare/utils/appRoutes/assets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../../component/other/input_text_fields/text_input.dart';
import '../../../../../utils/app_utils/AppUtils.dart';
import 'dart:io';
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
  bool _isLoading = false;
  XFile? _imageFile;

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Check edit button is clicked or not
  bool _isEditing = false;
  bool isPasswordVisible = false;

  // Edit Text Controller
  late TextEditingController _usernameController = TextEditingController();
  late TextEditingController _mobileController = TextEditingController();
  late TextEditingController _dobController = TextEditingController();
  late TextEditingController _emailController = TextEditingController();
  late TextEditingController _passwordController = TextEditingController();

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
          _usernameController.text = _name ?? '';
          _emailController.text = _auth.currentUser!.email ?? '';
          _passwordController.text = _password ?? '';
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

  // Pick image from gallery
  Future<void> _pickImage() async {
    if (!_isEditing) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // Get user info
  Future<void> _updateUserInfo() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      String? newImageUrl = _profileImageUrl;

      // Only upload image if a new one was picked
      if (_imageFile != null) {
        String fileName = 'profile_images/${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = _storage.ref().child(fileName);

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await _imageFile!.readAsBytes();
          uploadTask = storageRef.putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
            ),
          );
        } else {
          uploadTask = storageRef.putFile(File(_imageFile!.path));
        }

        TaskSnapshot taskSnapshot = await uploadTask;
        newImageUrl = await taskSnapshot.ref.getDownloadURL();
      }

      // 🌟 NEW: Re-authenticate user before updating sensitive info
      final user = _auth.currentUser!;
      if (_passwordController.text.isNotEmpty && (_emailController.text.isNotEmpty || _passwordController.text.isNotEmpty)) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _password.toString(),
        );

        await user.reauthenticateWithCredential(credential);

        // Update Email if changed
        if (_emailController.text.isNotEmpty && _emailController.text != user.email) {
          await user.verifyBeforeUpdateEmail(_emailController.text.trim());

          // Show SnackBar saying email verification email is sent
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification email sent to your new email address.")),
          );
        }

        // Update Password if changed
        if (_passwordController.text.isNotEmpty) {
          await user.updatePassword(_passwordController.text.trim());
        }
      }

      await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid.toString())
          .set({
            'name': _usernameController.text.toString(),
            'mobile_number': _mobileController.text.toString(),
            'dob': _dobController.text.toString(),
            'profile_image_url': newImageUrl,
            if (_emailController.text.isNotEmpty) 'email': user.email!,
            if (_passwordController.text.isNotEmpty) 'password': _passwordController.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context); // Hide the loading dialog
      setState(() {
        _isEditing = false;
        _profileImageUrl = newImageUrl;
        _imageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
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
    _passwordController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _getUserInfo();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
            EditProfileAppBar(title: 'Edit Profile', done: _isEditing ? 'Cancel' : 'Edit', onTap: () => setState(() { _isEditing = !_isEditing; })),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(500),
                                  child: _imageFile != null
                                      ? kIsWeb
                                      ? Image.network(
                                    _imageFile!.path,
                                    fit: BoxFit.cover,
                                    height: 80,
                                    width: 80,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        Assets.loginBack,
                                        fit: BoxFit.cover,
                                        height: 80,
                                        width: 80,
                                      );
                                    },
                                  )
                                      : Image.file(
                                    File(_imageFile!.path),
                                    fit: BoxFit.cover,
                                    height: 80,
                                    width: 80,
                                  )
                                      : _profileImageUrl != null
                                      ? CachedNetworkImage(
                                    imageUrl: _profileImageUrl!,  // Error updating profile: Unsupported operation: _Namespace
                                    fit: BoxFit.cover,
                                    height: 80,
                                    width: 80,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      Assets.loginBack,
                                      fit: BoxFit.cover,
                                      height: 80,
                                      width: 80,
                                    ),
                                  )
                                      : Image.asset(
                                    Assets.loginBack,
                                    fit: BoxFit.cover,
                                    height: 80,
                                    width: 80,
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppUtils.getColorScheme(context).primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: AppUtils.getColorScheme(context).onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                              const SizedBox(height: 4),
                              TextInput(
                                  keyboardType: TextInputType.text,
                                  obscureText: !isPasswordVisible,
                                  isEnabled: _role == 'Admin' ? _isEditing ? false : true : true,
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                  controller: _passwordController,
                                  labelText: 'Enter your password',
                                  hintText: 'e.g. Password123',
                                  errorText: '',
                                  prefixIcon: Icon(Icons.lock_outline, color: AppUtils.getColorScheme(context).tertiaryContainer),
                                  suffixIcon: IconButton(
                                      onPressed: (){
                                        isPasswordVisible = !isPasswordVisible;
                                        setState(() {});
                                      },
                                      icon: Icon(
                                          isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: AppUtils.getColorScheme(context).tertiaryContainer)
                                  )
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