import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/models/chat_room_model.dart';
import 'package:stranger_connect/models/message_model.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/chat_service.dart';
import 'package:stranger_connect/services/matchmaking_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatScreen({super.key, required this.chatRoomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late ChatService _chatService;
  late AuthService _authService;
  ChatRoomModel? _chatRoom;
  bool _isEnded = false;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _authService = context.read<AuthService>();
    _loadChatRoom();
  }

  Future<void> _loadChatRoom() async {
    final room = await _chatService.getChatRoom(widget.chatRoomId);
    if (mounted) setState(() => _chatRoom = room);
  }

  void _sendMessage() {
    if (_isEnded) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatService.sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: _authService.uid!,
      text: text,
    );

    _messageController.clear();
  }

  Future<void> _exitChat() async {
    if (!_isEnded) {
      final uid = _authService.uid!;
      await _chatService.endChat(
        chatRoomId: widget.chatRoomId,
        endedByUid: uid,
      );
    }
    if (mounted) {
      context.read<MatchmakingService>().clearCurrentMatch();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.uid!;

    return StreamBuilder<ChatRoomModel?>(
      stream: _chatService.chatRoomStream(widget.chatRoomId),
      initialData: _chatRoom,
      builder: (context, roomSnapshot) {
        final room = roomSnapshot.data ?? _chatRoom;
        if (room != null && room.isEnded && !_isEnded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isEnded = true);
          });
        }
        final otherProfile = room?.getOtherProfile(myUid);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.cardColor,
                  backgroundImage: otherProfile?.profilePicUrl != null
                      ? CachedNetworkImageProvider(otherProfile!.profilePicUrl!)
                      : null,
                  child: otherProfile?.profilePicUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  otherProfile?.displayName ?? 'Stranger',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _exitChat,
            ),
          ),
          body: Column(
            children: [
              if (_isEnded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.redAccent.withOpacity(0.15),
                  child: const Text(
                    'Stranger has left the chat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getMessages(widget.chatRoomId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'Say hello!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == myUid;
                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.cardColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isEnded,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _isEnded ? 'Chat ended' : 'Type a message...',
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isEnded ? null : _sendMessage,
            icon: const Icon(Icons.send_rounded),
            color: _isEnded ? AppTheme.textSecondary : AppTheme.primaryColor,
            style: IconButton.styleFrom(
              backgroundColor: _isEnded
                  ? AppTheme.cardColor
                  : AppTheme.primaryColor.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat.jm().format(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
