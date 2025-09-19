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

                // Apply comprehensive user filtering
                final allUsers = snapshot.data!.docs
                    .map((doc) => {
                          ...doc.data() as Map<String, dynamic>,
                          'uid': doc.id,
                        })
                    .toList();

                debugPrint("Total users found: ${allUsers.length}");

                final validUsers = allUsers.where((user) {
                  try {
                    // Filter out current user
                    if (user["uid"] == _auth.currentUser!.uid) return false;

                    // More robust null/empty checks
                    final name = user["name"];
                    final email = user["email"];
                    final uid = user["uid"];
                    final role = user["role"];

                    // Filter out users with missing or invalid data
                    if (name == null ||
                        name.toString().trim().isEmpty ||
                        name.toString().toLowerCase().trim() == "unknown user" ||
                        email == null ||
                        email.toString().trim().isEmpty ||
                        uid == null ||
                        uid.toString().trim().isEmpty) {
                      debugPrint("Filtering out user with invalid data: name=$name, email=$email, uid=$uid");
                      return false;
                    }

                    // Filter out users without a valid role (likely deleted users)
                    if (role == null || role.toString().trim().isEmpty) {
                      debugPrint("Filtering out user with no role: name=$name, role=$role");
                      return false;
                    }

                    return true;
                  } catch (e) {
                    debugPrint("Error processing user data: $e");
                    return false;
                  }
                }).toList();

                debugPrint("Valid users after filtering: ${validUsers.length}");

                if (validUsers.isEmpty) {
                  return const Center(child: Text('No users available to add to group'));
                }

                return ListView.builder(
                  itemCount: validUsers.length,
                  itemBuilder: (context, index) {
                    var user = validUsers[index];
                    String userId = user['uid'];

                    return CheckboxListTile(
                      title: Text(user['name']?.toString().trim() ?? 'Unknown User'),
                      subtitle: Text('${user['role']?.toString().trim() ?? 'No Role'} • ${user['email']?.toString().trim() ?? 'No Email'}'),
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