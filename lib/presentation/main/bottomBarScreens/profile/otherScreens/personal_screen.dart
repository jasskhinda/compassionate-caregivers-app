import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import '../../../../../component/appBar/settings_app_bar.dart';

class PersonalInfo extends StatefulWidget {
  const PersonalInfo({super.key});

  @override
  State<PersonalInfo> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends State<PersonalInfo> {

  Map<String, dynamic>? _arguments;

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user role
  String? _currentRole;
  bool _isSuperAdmin = false;
  bool _isAdmin = false;
  bool _isStaff = false;

  // User info
  String? userName;
  String? email;
  String? role;
  String? mobileNumber;
  String? dob;
  String? password;
  String? shiftType;
  int? assignedVideos;
  int? completedVideos;
  bool isLoading = true; // Loading state

  // Get current user role
  Future<void> _getCurrentUserRole({required String uid}) async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        final role = data['role'] ?? '';
        final email = data['email'] ?? '';
        setState(() {
          _currentRole = role;
          _isAdmin = role == 'Admin';
          _isStaff = role == 'Staff';
          _isSuperAdmin = email.toLowerCase() == 'j.khinda@ccgrhc.com';
        });
      } else {
        debugPrint("No such document!");
      }
    } catch (e) {
      debugPrint("Error fetching document: $e");
    }
  }

  // Get user personal info
  Future<void> getDocument({required String uid}) async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (document.exists) {
        var data = document.data() as Map<String, dynamic>;
        setState(() {
          userName = data['name'];
          email = data['email'];
          role = data['role'];
          mobileNumber = data['mobile_number'];
          assignedVideos = data['assigned_video'];
          completedVideos = data['completed_video'];
          password = data['password'];
          dob = data['dob'];
          shiftType = data['shift_type'];
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        debugPrint("No such document!");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint("Error fetching document: $e");
    }
  }

  // Update shift type function
  Future<void> _updateShiftType(String uid, String newShiftType) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .update({'shift_type': newShiftType});

      setState(() {
        shiftType = newShiftType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shift type updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update shift type: $e')),
      );
      debugPrint("Error updating shift type: $e");
    }
  }

  // Show shift type dialog
  void _showShiftTypeDialog(String uid) {
    String selectedShift = shiftType ?? 'Day';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Change Shift Type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select new shift type for $userName:'),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedShift,
                    decoration: InputDecoration(
                      labelText: 'Shift Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Day', 'Night'].map((String shift) {
                      return DropdownMenuItem(
                        value: shift,
                        child: Text('$shift Shift'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedShift = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateShiftType(uid, selectedShift);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Delay reading arguments until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute
          .of(context)
          ?.settings
          .arguments;
      if (args != null && args is Map<String, dynamic>) {
        setState(() {
          _arguments = args;

          // Optional: If you want to use data directly
          String uid;
          uid = args['userID'] ?? '';
          getDocument(uid: uid);
        });
      }
    });
    _getCurrentUserRole(uid: _auth.currentUser!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          SettingsAppBar(title: 'Personal Info'),
          SliverToBoxAdapter(
            child: isLoading
                ? Center(child: Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: CircularProgressIndicator(),
                )) // Show loading indicator
                : Column(
              children: [
                SizedBox(height: 50),
                PersonalInfoLayout(title: 'Full name', value: userName ?? "N/A"),
                PersonalInfoLayout(title: 'Role', value: role ?? "N/A"),
                if (role == 'Caregiver') PersonalInfoLayoutWithEdit(
                  title: 'Shift Type',
                  value: shiftType != null ? '$shiftType Shift' : "Not Set",
                  canEdit: _isSuperAdmin || _isAdmin || _isStaff,
                  onEdit: () => _showShiftTypeDialog(_arguments?['userID'] ?? ''),
                ),
                PersonalInfoLayout(title: 'Email address', value: email ?? "N/A"),
                PersonalInfoLayout(title: 'Date of birth', value: dob ?? "N/A"),
                PersonalInfoLayout(title: 'Mobile number', value: mobileNumber?.isNotEmpty == true ? mobileNumber! : "N/A"),
                PersonalInfoLayout(title: 'Video Assigned', value: assignedVideos.toString()),
                PersonalInfoLayout(title: 'Video Completed', value: completedVideos.toString(), isLast: _currentRole == 'Admin' ? false : true),
                _currentRole == 'Admin' ? PersonalInfoLayout(title: 'Password', value: password ?? 'N/A', isLast: true) : SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalInfoLayout extends StatelessWidget {
  final String title;
  final String value;
  final bool? isLast;

  const PersonalInfoLayout({
    super.key,
    required this.title,
    required this.value,
    this.isLast = false
  });

  @override
  Widget build(BuildContext context) {

    // Theme
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          height: 1,
          width: double.infinity,
          color: colorScheme.onSurface.withAlpha(80),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.start,
                style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface
                ),
              ),
              SizedBox(
                  width: MediaQuery.of(context).size.width * 0.52,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface
                    ),
                  )
              ),
            ],
          ),
        ),
        isLast == true ? Container(
          height: 1,
          width: double.infinity,
          color: colorScheme.onSurface.withAlpha(80),
        ) : const SizedBox(),
      ],
    );
  }
}

class PersonalInfoLayoutWithEdit extends StatelessWidget {
  final String title;
  final String value;
  final bool canEdit;
  final VoidCallback? onEdit;
  final bool? isLast;

  const PersonalInfoLayoutWithEdit({
    super.key,
    required this.title,
    required this.value,
    required this.canEdit,
    this.onEdit,
    this.isLast = false
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          height: 1,
          width: double.infinity,
          color: colorScheme.onSurface.withAlpha(80),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.start,
                style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface
                        ),
                      ),
                    ),
                    if (canEdit && onEdit != null) ...[
                      SizedBox(width: 8),
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        isLast == true ? Container(
          height: 1,
          width: double.infinity,
          color: colorScheme.onSurface.withAlpha(80),
        ) : const SizedBox(),
      ],
    );
  }
}