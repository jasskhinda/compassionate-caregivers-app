import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/component/appBar/main_app_bar.dart';
import 'package:healthcare/component/other/input_text_fields/input_text_field.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/chat/chat_layout.dart';
import 'package:healthcare/services/chat_services.dart';
import 'package:healthcare/utils/appRoutes/app_routes.dart';
import 'package:healthcare/utils/app_utils/AppUtils.dart';

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

        final users = snapshot.data!.where((user) {
          if (user["email"] == _auth.currentUser!.email) return false;
          if (_searchQuery.isEmpty) return true;
          return user["name"].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 user["email"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Get all chat rooms for the current user
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chat_rooms')
              .where('participants', arrayContains: _auth.currentUser!.uid)
              .snapshots(),
          builder: (context, chatSnapshot) {
            if (chatSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (chatSnapshot.hasError) {
              return Center(child: Text('Error: ${chatSnapshot.error}'));
            }

            // Create a map of user IDs to their chat room data
            final chatRooms = chatSnapshot.data?.docs ?? [];
            final userChatData = <String, Map<String, dynamic>>{};
            
            for (var chat in chatRooms) {
              final data = chat.data() as Map<String, dynamic>;
              final participants = data['participants'] as List<dynamic>;
              final otherUserId = participants.firstWhere(
                (id) => id != _auth.currentUser!.uid,
                orElse: () => null,
              );
              if (otherUserId != null) {
                userChatData[otherUserId] = {
                  'lastMessageTime': data['lastMessageTime'],
                  'unreadCount': data['unreadCount_${_auth.currentUser!.uid}'] ?? 0,
                };
              }
            }

            // Sort users based on their chat activity
            users.sort((a, b) {
              final aData = userChatData[a['uid']];
              final bData = userChatData[b['uid']];
              
              // If both users have no chat data, keep their original order
              if (aData == null && bData == null) return 0;
              
              // Users with chat data come before users without
              if (aData == null) return 1;
              if (bData == null) return -1;
              
              // First sort by unread count (users with unread messages come first)
              final aUnread = aData['unreadCount'] as int;
              final bUnread = bData['unreadCount'] as int;
              if (aUnread != bUnread) {
                return bUnread.compareTo(aUnread);
              }
              
              // Then sort by last message time
              final aTime = aData['lastMessageTime'] as Timestamp?;
              final bTime = bData['lastMessageTime'] as Timestamp?;
              
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              
              return bTime.compareTo(aTime);
            });

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: users.map((userData) => _buildUserListItem(userData, context)).toList(),
            );
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

  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    // Create chat room ID from user IDs (sorted to ensure consistency)
    List<String> ids = [FirebaseAuth.instance.currentUser!.uid, userData['uid']];
    ids.sort();
    String chatRoomId = ids.join('_');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        String lastMessage = '';
        DateTime? lastMessageTime;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final lastMessageDoc = snapshot.data!.docs.first;
          lastMessage = lastMessageDoc['message'] as String? ?? '';
          lastMessageTime = (lastMessageDoc['timestamp'] as Timestamp?)?.toDate();
          unreadCount = lastMessageDoc['senderId'] == FirebaseAuth.instance.currentUser!.uid 
              ? 0 
              : 1; // Simple unread count logic
        }

        return ChatLayout(
          hasBadge: unreadCount > 0,
          badgeCount: unreadCount,
          backgroundColor: AppUtils.getColorScheme(context).secondary,
          title: userData["name"],
          profileImageUrl: userData["profile_image_url"],
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.chatScreen,
              arguments: {
                'userName': userData["name"],
                'userEmail': userData["email"],
                'userID': userData["uid"],
                'isGroupChat': false,
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
            await Future.wait([
              _getUserRole(),
              _chatServices.refreshUserStream(),
              _chatServices.refreshGroupStream(),
            ]);
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
