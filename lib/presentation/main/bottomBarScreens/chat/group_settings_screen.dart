import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/services/chat_services.dart';
import 'package:caregiver/services/super_admin_service.dart';
import 'package:caregiver/services/user_validation_service.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupSettingsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final ChatServices _chatServices = ChatServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> selectedUsers = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    try {
      final userDoc = await _firestore.collection('Users').doc(_auth.currentUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'];
        });
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          if (_userRole == 'Admin')
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmation(),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _chatServices.getGroupInfo(widget.groupId),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) {
            return Center(child: Text('Error: ${groupSnapshot.error}'));
          }

          if (!groupSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          // Check if group still exists
          if (!groupSnapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Group Not Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This group has been deleted.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(); // Go back to chat list
                    },
                    child: Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;

          // Double check for null data
          if (groupData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Group data unavailable'),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final List<String> members = List<String>.from(groupData['members'] ?? []);

          return Column(
            children: [
              // Current Members Section
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Users')
                      .where('uid', whereIn: members)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Members',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ...snapshot.data!.docs.where((doc) {
                          return UserValidationService.isValidUserDocument(doc);
                        }).map((doc) {
                          final displayInfo = UserValidationService.getUserDisplayInfoFromDoc(doc);
                          final isSuperAdmin = displayInfo['email']?.toLowerCase() == SuperAdminService.SUPER_ADMIN_EMAIL.toLowerCase();
                          final subtitleText = isSuperAdmin
                              ? '${displayInfo['email']!}\nSuper Admin - Contact for Technical Support'
                              : '${displayInfo['email']!}\n${displayInfo['role']!}';

                          return ListTile(
                            title: Text(displayInfo['name']!),
                            subtitle: Text(subtitleText),
                            trailing: _userRole == 'Admin' && displayInfo['role'] != 'Admin'
                                ? IconButton(
                                    icon: Icon(Icons.remove_circle_outline),
                                    onPressed: () => _removeMember(doc.id),
                                  )
                                : null,
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),

              // Add Members Button
              if (_userRole == 'Admin' || _userRole == 'Staff')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () => _showAddMembersDialog(),
                    child: Text('Add Members'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Members'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: UserValidationService.getAllValidUsersStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              return StatefulBuilder(
                builder: (context, setState) {
                  final validUsers = snapshot.data!;

                  return ListView(
                    shrinkWrap: true,
                    children: validUsers.map((doc) {
                      final displayInfo = UserValidationService.getUserDisplayInfoFromDoc(doc);
                      final bool isSelected = selectedUsers.contains(doc.id);
                      final isSuperAdmin = displayInfo['email']?.toLowerCase() == SuperAdminService.SUPER_ADMIN_EMAIL.toLowerCase();
                      final subtitleText = isSuperAdmin
                          ? '${displayInfo['email']!}\nSuper Admin - Contact for Technical Support'
                          : '${displayInfo['email']!}\n${displayInfo['role']!}';

                      return CheckboxListTile(
                        title: Text(displayInfo['name']!),
                        subtitle: Text(subtitleText),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedUsers.add(doc.id);
                            } else {
                              selectedUsers.remove(doc.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              selectedUsers.clear();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (selectedUsers.isNotEmpty) {
                await _chatServices.addMembersToGroup(widget.groupId, selectedUsers);
                selectedUsers.clear();
                Navigator.of(context).pop();
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
        content: Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatServices.removeMembersFromGroup(widget.groupId, [userId]);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Group'),
        content: Text('Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _chatServices.deleteGroup(widget.groupId);
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to chat list
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 