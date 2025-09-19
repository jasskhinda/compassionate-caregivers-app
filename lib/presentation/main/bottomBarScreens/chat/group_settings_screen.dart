import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/services/chat_services.dart';
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

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
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
                          try {
                            final data = doc.data();
                            if (data == null) return false;
                            final userData = data as Map<String, dynamic>;
                            final name = userData['name'];
                            final email = userData['email'];
                            final role = userData['role'];

                            // Only include valid users
                            return name != null && name is String && name.trim().isNotEmpty &&
                                   email != null && email is String && email.trim().isNotEmpty &&
                                   role != null && role is String && role.trim().isNotEmpty;
                          } catch (e) {
                            return false;
                          }
                        }).map((doc) {
                          final userData = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(userData['name'] ?? ''),
                            subtitle: Text('${userData['email'] ?? ''}\n${userData['role'] ?? ''}'),
                            trailing: _userRole == 'Admin' && userData['role'] != 'Admin'
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              return StatefulBuilder(
                builder: (context, setState) {
                  // Filter out invalid users
                  final validUsers = <QueryDocumentSnapshot>[];
                  int totalProcessed = 0;
                  int invalidCount = 0;

                  for (final doc in snapshot.data!.docs) {
                    totalProcessed++;
                    try {
                      final data = doc.data();
                      if (data != null) {
                        final userData = data as Map<String, dynamic>;

                        // Check for required fields
                        final name = userData['name'];
                        final email = userData['email'];
                        final role = userData['role'];

                        // Validate name
                        if (name == null || (name is! String) || name.trim().isEmpty) {
                          print('Invalid name: $name for user ${doc.id}');
                          invalidCount++;
                          continue;
                        }

                        // Validate email
                        if (email == null || (email is! String) || email.trim().isEmpty) {
                          print('Invalid email: $email for user ${doc.id}');
                          invalidCount++;
                          continue;
                        }

                        // Validate role
                        if (role == null || (role is! String) || role.trim().isEmpty) {
                          print('Invalid role: $role for user ${doc.id}');
                          invalidCount++;
                          continue;
                        }

                        // All validations passed
                        validUsers.add(doc);
                      } else {
                        print('Null data for user ${doc.id}');
                        invalidCount++;
                      }
                    } catch (e) {
                      print('Error processing user ${doc.id}: $e');
                      invalidCount++;
                    }
                  }

                  print('Total valid documents processed: $totalProcessed');
                  if (invalidCount > 0) {
                    print('Filtered out $invalidCount invalid users');
                  }
                  print('Valid users after filtering: ${validUsers.length}');

                  return ListView(
                    shrinkWrap: true,
                    children: validUsers.map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final bool isSelected = selectedUsers.contains(doc.id);

                      return CheckboxListTile(
                        title: Text(userData['name'] ?? ''),
                        subtitle: Text('${userData['email'] ?? ''}\n${userData['role'] ?? ''}'),
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