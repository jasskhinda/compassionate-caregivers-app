import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:caregiver/component/appBar/main_app_bar.dart';
import 'package:caregiver/component/other/input_text_fields/input_text_field.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/chat_layout.dart';
import 'package:caregiver/services/chat_services.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';

class RecentChatScreen extends StatefulWidget {
  const RecentChatScreen({super.key});

  @override
  State<RecentChatScreen> createState() => _RecentChatScreenState();
}

class _RecentChatScreenState extends State<RecentChatScreen> {
  final ChatServices _chatServices = ChatServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TextEditingController searchController;
  String _searchQuery = '';
  String? _userRole;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatServices.getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return Center(child: Text('No users found'));
        }

        // First filter out invalid users
        final validUsers = snapshot.data!.where((user) {
          // Filter out current user
          if (user["email"] == _auth.currentUser!.email) return false;

          // Filter out users with missing or invalid data
          if (user["name"] == null ||
              user["name"].toString().isEmpty ||
              user["name"].toString().toLowerCase() == "unknown user" ||
              user["email"] == null ||
              user["email"].toString().isEmpty ||
              user["uid"] == null ||
              user["uid"].toString().isEmpty) {
            return false;
          }

          // Filter out users without a valid role (likely deleted users)
          if (user["role"] == null || user["role"].toString().isEmpty) {
            return false;
          }

          return true;
        }).toList();

        // Remove duplicates by email (keep the most recent one based on name/data completeness)
        final Map<String, Map<String, dynamic>> uniqueUsersMap = {};
        for (var user in validUsers) {
          final email = user["email"].toString().toLowerCase();

          if (!uniqueUsersMap.containsKey(email)) {
            uniqueUsersMap[email] = user;
          } else {
            // Keep the user with more complete data (preferring non-empty names)
            final existingUser = uniqueUsersMap[email]!;
            final existingName = existingUser["name"]?.toString() ?? "";
            final currentName = user["name"]?.toString() ?? "";

            // Prefer user with actual name over generic ones
            if (currentName.isNotEmpty && existingName.isEmpty) {
              uniqueUsersMap[email] = user;
            } else if (currentName.isNotEmpty && existingName.isNotEmpty) {
              // Both have names, prefer the one that's not "Unknown User" or similar
              if (!currentName.toLowerCase().contains("unknown") &&
                  existingName.toLowerCase().contains("unknown")) {
                uniqueUsersMap[email] = user;
              }
            }
          }
        }

        // Convert back to list and apply search filter
        final users = uniqueUsersMap.values.where((user) {
          // Apply search filter if search query exists
          if (_searchQuery.isEmpty) return true;
          return user["name"].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 user["email"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _searchQuery.isEmpty ? 'No users available' : 'No users found matching your search',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: users.map((userData) => _buildSimpleUserListItem(userData, context)).toList(),
        );
      },
    );
  }

  Widget _buildSimpleUserListItem(Map<String, dynamic> userData, BuildContext context) {
    // Get user name with fallback (though filtering should prevent this)
    String userName = userData["name"]?.toString() ?? "User";
    if (userName.isEmpty || userName.toLowerCase() == "unknown user") {
      userName = userData["email"]?.toString().split('@')[0] ?? "User";
    }
    
    return ChatLayout(
      hasBadge: false,
      badgeCount: 0,
      backgroundColor: AppUtils.getColorScheme(context).secondary,
      title: userName,
      profileImageUrl: userData["profile_image_url"],
      lastMessage: "Tap to start chatting",
      lastMessageTime: null,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.chatScreen,
          arguments: {
            'userName': userName,
            'userEmail': userData["email"] ?? "",
            'userID': userData["uid"] ?? "",
            'isGroupChat': false,
          }
        );
      }
    );
  }

  Widget _buildGroupList() {
    return StreamBuilder(
      stream: _chatServices.getUserGroups(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No groups yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final groups = snapshot.data!.docs.where((group) {
          if (_searchQuery.isEmpty) return true;
          return group['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No groups found matching your search',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: groups.map((group) => _buildGroupListItem(group, context)).toList(),
        );
      }
    );
  }

  Widget _buildGroupListItem(QueryDocumentSnapshot group, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .doc(group.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        String lastMessage = '';
        DateTime? lastMessageTime;
        final String fieldName = 'unreadCount_${_auth.currentUser!.uid}';

        int unreadCount = (group.data() as Map<String, dynamic>?)
            ?.containsKey(fieldName) == true
            ? group[fieldName] as int? ?? 0
            : 0;

        if (snapshot.data!.docs.isNotEmpty) {
          final lastMessageDoc = snapshot.data!.docs.first;
          lastMessage = lastMessageDoc['message'] as String? ?? '';
          lastMessageTime = (lastMessageDoc['timestamp'] as Timestamp?)?.toDate();
        }

        return ChatLayout(
          hasBadge: unreadCount > 0,
          badgeCount: unreadCount,
          backgroundColor: AppUtils.getColorScheme(context).secondary,
          title: group['name'],
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.chatScreen,
              arguments: {
                'userName': group['name'],
                'groupId': group.id,
                'isGroupChat': true,
              }
            );
          }
        );
      }
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      floatingActionButton: _userRole != 'Caregiver'
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.width < 600 ? 80.0 : 0.0,
              ),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.createGroupScreen);
                },
                child: const Icon(Icons.group_add),
                backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _searchQuery = '';
              searchController.clear();
            });
            await _getUserRole();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const MainAppBar(title: 'Chat'),
              SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: AppUtils.getScreenSize(context).width >= 600
                        ? AppUtils.getScreenSize(context).width * 0.45
                        : double.infinity,
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InputTextField(
                            controller: searchController,
                            onTextChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            labelText: 'Search',
                            hintText: 'e.g. john, smith...',
                            prefixIcon: Icons.search,
                            suffixIcon: Icons.clear,
                            errorText: null,
                            onIconPressed: () {
                              setState(() {
                                searchController.clear();
                                _searchQuery = '';
                              });
                            }
                          ),
                          SizedBox(height: 15),
                          // Groups Section
                          if (_searchQuery.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                  child: Text(
                                    'Groups',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildGroupList(),
                                const SizedBox(height: 15),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                  child: Text(
                                    'Individual Chats',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          _buildUserList(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ]
          ),
        ),
      ),
    );
  }
}
