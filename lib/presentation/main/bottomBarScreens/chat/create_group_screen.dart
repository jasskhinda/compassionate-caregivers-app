import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/services/chat_services.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final ChatServices _chatServices = ChatServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _selectedUsers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty || _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name and select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String groupId = await _chatServices.createGroupChat(
        groupName: _groupNameController.text,
        memberIds: _selectedUsers,
        createdBy: _auth.currentUser!.uid,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
            settings: RouteSettings(
              arguments: {
                'userName': _groupNameController.text,
                'isGroupChat': true,
                'groupId': groupId,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _createGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Apply comprehensive user filtering with null safety
                final allUsers = <Map<String, dynamic>>[];

                for (var doc in snapshot.data!.docs) {
                  try {
                    final data = doc.data();
                    if (data != null) {
                      final userData = Map<String, dynamic>.from(data as Map<String, dynamic>);
                      userData['uid'] = doc.id;
                      allUsers.add(userData);
                    } else {
                      debugPrint("Skipping document ${doc.id} with null data");
                    }
                  } catch (e) {
                    debugPrint("Error processing document ${doc.id}: $e");
                  }
                }

                debugPrint("Total valid documents processed: ${allUsers.length}");

                final validUsers = <Map<String, dynamic>>[];

                for (var user in allUsers) {
                  try {
                    // Filter out current user
                    if (user["uid"] == _auth.currentUser!.uid) continue;

                    // Strict validation of required fields
                    final name = user["name"];
                    final email = user["email"];
                    final uid = user["uid"];
                    final role = user["role"];

                    // Check if name is valid
                    if (name == null ||
                        name is! String ||
                        name.trim().isEmpty ||
                        name.toLowerCase().trim() == "unknown user") {
                      debugPrint("Invalid name: $name for user $uid");
                      continue;
                    }

                    // Check if email is valid
                    if (email == null ||
                        email is! String ||
                        email.trim().isEmpty ||
                        !email.contains('@')) {
                      debugPrint("Invalid email: $email for user $uid");
                      continue;
                    }

                    // Check if uid is valid
                    if (uid == null ||
                        uid is! String ||
                        uid.trim().isEmpty) {
                      debugPrint("Invalid uid: $uid");
                      continue;
                    }

                    // Check if role is valid
                    if (role == null ||
                        role is! String ||
                        role.trim().isEmpty) {
                      debugPrint("Invalid role: $role for user $name");
                      continue;
                    }

                    // User passed all validations
                    validUsers.add(user);
                  } catch (e) {
                    debugPrint("Error validating user data: $e");
                  }
                }

                debugPrint("Valid users after filtering: ${validUsers.length}");

                if (validUsers.isEmpty) {
                  return const Center(child: Text('No users available to add to group'));
                }

                return ListView.builder(
                  itemCount: validUsers.length,
                  itemBuilder: (context, index) {
                    try {
                      if (index >= validUsers.length) {
                        return const SizedBox.shrink();
                      }

                      var user = validUsers[index];
                      String userId = user['uid'] as String;
                      String userName = user['name'] as String;
                      String userEmail = user['email'] as String;
                      String userRole = user['role'] as String;

                      return CheckboxListTile(
                        title: Text(userName),
                        subtitle: Text('$userRole • $userEmail'),
                        value: _selectedUsers.contains(userId),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedUsers.add(userId);
                            } else {
                              _selectedUsers.remove(userId);
                            }
                          });
                        },
                      );
                    } catch (e) {
                      debugPrint("Error building list item at index $index: $e");
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 