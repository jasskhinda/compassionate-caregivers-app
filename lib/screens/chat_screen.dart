import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/message.dart';
import '../services/chat_services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/audio_player_widget.dart';

class ChatScreen extends StatefulWidget {
  final String userID;
  final String userEmail;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.userID,
    required this.userEmail,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ChatServices chatService = ChatServices();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty) return;

    try {
      if (widget.isGroup) {
        await chatService.sendGroupMessage(widget.userID, message);
      } else {
        await chatService.sendMessage(widget.userID, message);
      }
      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _sendMediaMessage(File file, String messageType) async {
    try {
      setState(() => _isLoading = true);

      String fileName = 'media_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      String mediaPath = widget.isGroup 
          ? 'chat_media/groups/${widget.userID}/$fileName'
          : 'chat_media/${FirebaseAuth.instance.currentUser!.uid}/$fileName';
      
      final ref = FirebaseStorage.instance.ref().child(mediaPath);
      await ref.putFile(file);
      String mediaUrl = await ref.getDownloadURL();

      if (widget.isGroup) {
        await chatService.sendGroupMediaMessage(widget.userID, file, messageType);
      } else {
        await chatService.sendMediaMessage(
          widget.userID,
          messageType,
          mediaUrl: mediaUrl,
          isGroup: false,
        );
      }

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending media: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndSendMedia(String type) async {
    try {
      final picker = ImagePicker();
      final XFile? file = type == 'video'
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery);

      if (file == null) return;

      final mediaFile = File(file.path);
      await _sendMediaMessage(mediaFile, type);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send media: ${e.toString()}')),
      );
    }
  }

  Widget _buildMessageBubble(Message message) {
    final bool isMe = message.senderId == FirebaseAuth.instance.currentUser?.uid;
    final radius = Radius.circular(12);
    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isMe ? radius : Radius.zero,
      bottomRight: isMe ? Radius.zero : radius,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && widget.isGroup) ...[
              Text(
                message.senderEmail,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
            ],
            if (message.messageType == 'text')
              Text(
                message.content,
                style: TextStyle(fontSize: 16),
              )
            else if (message.messageType == 'image' && message.mediaUrl != null)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: Center(
                        child: CachedNetworkImage(
                          imageUrl: message.mediaUrl!,
                          placeholder: (context, url) => CircularProgressIndicator(),
                          errorWidget: (context, url, error) => Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    placeholder: (context, url) => const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (message.messageType == 'video' && message.mediaUrl != null)
              VideoPlayerWidget(videoUrl: message.mediaUrl!)
            else if (message.messageType == 'audio' && message.mediaUrl != null)
              AudioPlayerWidget(
                audioUrl: message.mediaUrl!,
                showDeleteButton: isMe,
                onDelete: isMe ? () {
                  // TODO: Implement delete functionality
                } : null,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userEmail),
            if (widget.isGroup)
              Text(
                'Tap for group info',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.isGroup
                  ? chatService.getGroupMessages(widget.userID)
                  : chatService.getMessages(
                      FirebaseAuth.instance.currentUser!.uid,
                      widget.userID,
                    ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withAlpha(100),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (context) => SizedBox(
                        height: 120,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.image),
                              title: const Text('Image'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickAndSendMedia('image');
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.videocam),
                              title: const Text('Video'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickAndSendMedia('video');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 