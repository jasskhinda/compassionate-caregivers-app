import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:caregiver/services/chat_services.dart';
import 'package:caregiver/services/user_validation_service.dart';
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
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: UserValidationService.getAllValidUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Get valid users and filter out current user
                final validUserDocs = snapshot.data ?? [];
                final filteredUsers = validUserDocs.where(
                  (doc) => doc.id != _auth.currentUser!.uid
                ).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('No users available to add to group'));
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    try {
                      if (index >= filteredUsers.length) {
                        return const SizedBox.shrink();
                      }

                      final userDoc = filteredUsers[index];
                      final displayInfo = UserValidationService.getUserDisplayInfoFromDoc(userDoc);
                      String userId = userDoc.id;
                      String userName = displayInfo['name']!;
                      String userEmail = displayInfo['email']!;
                      String userRole = displayInfo['role']!;

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