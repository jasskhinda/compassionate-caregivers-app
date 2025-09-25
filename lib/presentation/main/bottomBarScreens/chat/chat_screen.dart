import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:caregiver/models/message.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/group_settings_screen.dart';
import 'package:caregiver/services/chat_services.dart';
import 'package:caregiver/utils/appRoutes/assets.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // User info
  late String userName;
  late String userEmail;
  late String userID;
  late bool isGroupChat;
  late String groupId;

  // Chat Services
  final ChatServices _chatServices = ChatServices();

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Use this controller to get what the user typed
  late TextEditingController messageController;

  // For text field focus
  FocusNode focusNode = FocusNode();

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // Add these new state variables
  PlatformFile? _selectedMedia;
  bool _isUploading = false;

  // Add video controller map to manage multiple video players
  final Map<String, VideoPlayerController> _videoControllers = {};

  String? _userRole;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();
  String? _recordedFilePath;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
    _getUserRole();
    _recorder.openRecorder(); // Important: Open recorder
    _player.openPlayer(); // Important: Open recorder
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _resetUnreadCount();
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    messageController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _clearSelectedMedia();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  void _clearSelectedMedia() {
    setState(() {
      _selectedMedia = null;
    });
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn
      );
    }
  }

  // UI of audio recorder
  Future<void> _showAudioRecorderDialog() async {
    String? localRecordedFilePath;
    bool isRecording = false;
    bool hasRecorded = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Record Audio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRecording ? Icons.mic : (hasRecorded ? Icons.check_circle : Icons.mic_none),
                    size: 50,
                    color: isRecording ? Colors.red : (hasRecorded ? Colors.green : Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRecording
                        ? 'Recording...'
                        : hasRecorded
                        ? 'Recording saved'
                        : 'Tap to Start Recording',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Start/Stop button
                      ElevatedButton.icon(
                        icon: Icon(isRecording ? Icons.stop : Icons.mic),
                        label: Text(isRecording ? 'Stop' : 'Start'),
                        onPressed: () async {
                          if (!isRecording) {
                            var status = await Permission.microphone.request();
                            if (status.isGranted) {
                              final tempDir = await getTemporaryDirectory();
                              localRecordedFilePath =
                              '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

                              await _recorder.startRecorder(
                                toFile: localRecordedFilePath,
                                codec: Codec.aacADTS,
                              );
                              setState(() {
                                isRecording = true;
                                hasRecorded = false;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Microphone permission denied')),
                              );
                            }
                          } else {
                            await _recorder.stopRecorder();
                            setState(() {
                              isRecording = false;
                              hasRecorded = true;
                              _recordedFilePath = localRecordedFilePath;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 12),

                      // Send button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                        onPressed: hasRecorded && !isRecording
                            ? () async {
                          Navigator.of(context).pop();
                          if (_recordedFilePath != null) {
                            await _sendAudioMessage(_recordedFilePath!);
                          }
                        }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      if (isRecording) {
                        await _recorder.stopRecorder();
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendAudioMessage(String filePath) async {
    try {
      setState(() => _isUploading = true);

      String userId = _auth.currentUser!.uid;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String path = 'chat_media/${isGroupChat ? 'groups/$groupId' : 'private/$userId'}/$timestamp.aac';

      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(File(filePath));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (isGroupChat) {
        await _chatServices.sendGroupMessage(groupId, downloadUrl, messageType: 'audio');
      } else {
        await _chatServices.sendMessage(userID, downloadUrl, messageType: 'audio');
      }
    } catch (e) {
      print('Error sending audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending audio: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String mediaType = file.extension?.toLowerCase() ?? '';

        if (['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi'].contains(mediaType)) {
          setState(() {
            _selectedMedia = file;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unsupported file type')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking media: $e')),
        );
      }
    }
  }

  Future<void> _sendMediaMessage() async {
    if (_selectedMedia == null) return;

    try {
      setState(() {
        _isUploading = true;
      });

      String mediaType = _selectedMedia!.extension?.toLowerCase() ?? '';
      bool isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(mediaType);
      bool isVideo = ['mp4', 'mov', 'avi'].contains(mediaType);
      String type = isImage ? 'image' : 'video';

      if (!isImage && !isVideo) {
        throw Exception('Unsupported file type');
      }

      // Create a unique path for the media
      String userId = _auth.currentUser!.uid;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String path = 'chat_media/${isGroupChat ? 'groups/$groupId' : 'private/$userId'}/$timestamp.$mediaType';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(path);
      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = storageRef.putData(
          _selectedMedia!.bytes!,
          SettableMetadata(contentType: isImage ? 'image/$mediaType' : 'video/$mediaType'),
        );
      } else {
        uploadTask = storageRef.putFile(File(_selectedMedia!.path!));
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Send the message with the valid URL
      if (isGroupChat) {
        await _chatServices.sendGroupMessage(
          groupId,
          downloadUrl,
          messageType: type,
        );
      } else {
        await _chatServices.sendMessage(
          userID,
          downloadUrl,
          messageType: type,
        );
      }

      _clearSelectedMedia();
    } catch (e) {
      print('Error uploading media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (messageController.text.trim().isNotEmpty) {
      try {
        if (isGroupChat) {
          await _chatServices.sendGroupMessage(groupId, messageController.text.trim());
        } else {
          await _chatServices.sendMessage(userID, messageController.text.trim());
        }
        messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  Future<void> _getUserRole() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(_auth.currentUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'];
        });
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  Future<void> _resetUnreadCount() async {
    if (isGroupChat) {
      await _chatServices.resetGroupUnreadCount(groupId);
    } else {
      // Mark individual chat messages as read
      await _chatServices.markMessagesAsRead(userID);
    }
  }

  String _getChatRoomId() {
    List<String> ids = [_auth.currentUser!.uid, userID];
    ids.sort();
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve arguments safely
    final args = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> arguments = args is Map<String, dynamic> ? args : {};

    userName = arguments['userName'] ?? (arguments['isGroupChat'] ?? false ? 'Group Chat' : 'User');
    userEmail = arguments['userEmail'] ?? 'Tap for info';
    userID = arguments['userID'] ?? '';
    isGroupChat = arguments['isGroupChat'] ?? false;
    groupId = arguments['groupId'] ?? '';

    return Scaffold(
      backgroundColor: AppUtils.getColorScheme(context).surface,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: AppUtils.getColorScheme(context).surface,
        title: GestureDetector(
          onTap: isGroupChat && _userRole != 'Caregiver' ? () async {
            // Check if group still exists before navigating
            try {
              final groupDoc = await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .get();

              if (!groupDoc.exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This group has been deleted.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.of(context).pop(); // Go back to chat list
                }
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupSettingsScreen(
                    groupId: groupId,
                    groupName: userName,
                  ),
                ),
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error accessing group: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } : null,
          child: Row(
            children: [
              if (!isGroupChat)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('Users').doc(userID).get(),
                  builder: (context, snapshot) {
                    String? profileImageUrl;
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      profileImageUrl = data?['profile_image_url'];
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              fit: BoxFit.cover,
                              height: 40,
                              width: 40,
                              placeholder: (context, url) => Image.asset(
                                Assets.loginBack,
                                fit: BoxFit.cover,
                                height: 40,
                                width: 40,
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                Assets.loginBack,
                                fit: BoxFit.cover,
                                height: 40,
                                width: 40,
                              ),
                            )
                          : Image.asset(
                              Assets.loginBack,
                              fit: BoxFit.cover,
                              height: 40,
                              width: 40,
                            ),
                    );
                  },
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName),
                    if (isGroupChat && _userRole != 'Caregiver')
                      Text(
                        'Tap for group info',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: AppUtils.getColorScheme(context).onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            _buildMediaPreview(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    String currentUserId = _auth.currentUser!.uid;
    return StreamBuilder<List<Message>>(
      stream: isGroupChat
          ? _chatServices.getGroupMessages(groupId)
          : _chatServices.getMessages(currentUserId, userID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                TextButton(
                  onPressed: () {
                    setState(() {}); // Retry loading messages
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading messages...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!isGroupChat)
                  const Text(
                    'Start a conversation by sending a message',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          );
        }

        List<Message> messages = snapshot.data!;
        messages = messages.reversed.toList(); // Reverse the messages list

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0); // Scroll to top since list is reversed
          }
        });

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // Make list build from bottom to top
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageItem(messages[index]),
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) return const SizedBox.shrink();

    String mediaType = _selectedMedia!.extension?.toLowerCase() ?? '';
    bool isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(mediaType);

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isImage ? 'Image Preview' : 'Video Preview',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelectedMedia,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              if (isImage && _selectedMedia!.bytes != null)
                Image.memory(
                  _selectedMedia!.bytes!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              else if (!isImage)
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.black87,
                  child: const Icon(
                    Icons.video_library,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              if (_isUploading)
                const CircularProgressIndicator(),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isUploading ? null : _sendMediaMessage,
            child: Text(_isUploading ? 'Sending...' : 'Send Media'),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(String url) {
    bool isPlaying = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  if (isPlaying) {
                    await _player.pausePlayer();
                  } else {
                    await _player.startPlayer(
                      fromURI: url,
                      whenFinished: () => setState(() => isPlaying = false),
                    );
                  }
                  setState(() => isPlaying = !isPlaying);
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Audio Message",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppUtils.getColorScheme(context).surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _pickMedia,
              icon: const Icon(Icons.attach_file),
              tooltip: 'Send media',
            ),
            Expanded(
              child: TextField(
                controller: messageController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppUtils.getColorScheme(context).surface.withAlpha(80),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              onPressed: () async {
                if (kIsWeb) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio recording is not supported on Web.')),
                  );
                  return;
                }

                await _showAudioRecorderDialog();
              },
              icon: const Icon(Icons.mic),
              tooltip: 'Record audio',
            ),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              tooltip: 'Send message',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    bool isCurrentUser = message.senderId == FirebaseAuth.instance.currentUser!.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.4,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue : AppUtils.getColorScheme(context).secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCurrentUser)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Users').doc(message.senderId).get(),
                    builder: (context, snapshot) {
                      String senderName = 'User no longer exists';
                      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        senderName = data?['name'] ?? 'User no longer exists';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrentUser ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                if (message.messageType == 'text')
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : AppUtils.getColorScheme(context).onSurface,
                    ),
                  )
                else if (message.messageType == 'image')
                  _buildImageMessage(message)
                else if (message.messageType == 'video')
                  _buildVideoPlayer(message.content)
                else if (message.messageType == 'audio')
                  _buildAudioPlayer(message.content)
                else
                  const Text('Unsupported message type'),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      // Show read receipt for sender's messages
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chat_rooms')
                            .doc(_getChatRoomId())
                            .collection('messages')
                            .where('senderId', isEqualTo: message.senderId)
                            .where('timestamp', isEqualTo: message.timestamp)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          bool isRead = false;
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            final messageDoc = snapshot.data!.docs.first;
                            final data = messageDoc.data() as Map<String, dynamic>?;
                            isRead = data?['read'] ?? false;
                          }

                          return Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 12,
                            color: isRead ? Colors.blue : Colors.white70,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageMessage(Message message) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              backgroundColor: Colors.black,
              body: Center(
                child: CachedNetworkImage(
                  imageUrl: message.content,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) {
                    print('Image loading error: $error for URL: $url');
                    return const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 50,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 200,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.content,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) {
              print('Image loading error: $error for URL: $url');
              return Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 50,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (!_videoControllers.containsKey(videoUrl)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[videoUrl] = controller;
      controller.initialize().then((_) {
        setState(() {});
      });
    }

    final controller = _videoControllers[videoUrl]!;
    if (!controller.value.isInitialized) {
      return Container(
        height: 200,
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _FullScreenVideoPlayer(controller: controller),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 200,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              Container(
                color: Colors.black.withOpacity(0.4),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullScreenVideoPlayer({required this.controller});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (widget.controller.value.isPlaying) {
                              widget.controller.pause();
                            } else {
                              widget.controller.play();
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          widget.controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
