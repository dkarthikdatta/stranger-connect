import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/models/chat_room_model.dart';
import 'package:stranger_connect/models/message_model.dart';
import 'package:stranger_connect/models/user_model.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/chat_service.dart';
import 'package:stranger_connect/services/matchmaking_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final bool readOnly;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    this.readOnly = false,
  });

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
  bool _isEndingLocally = false;
  bool _remoteEndHandled = false;
  bool _isSendingMessage = false;
  final List<_PendingMessage> _pendingMessages = [];
  final Uuid _uuid = const Uuid();
  StreamSubscription<UserModel?>? _userSubscription;
  bool _seenCurrentMatchForThisRoom = false;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _authService = context.read<AuthService>();
    if (!widget.readOnly) {
      _userSubscription = _authService.userStream().listen(_onUserProfileUpdate);
    }
    _loadChatRoom();
  }

  void _onUserProfileUpdate(UserModel? user) {
    if (!mounted || _isEndingLocally || _remoteEndHandled) return;

    final currentMatch = user?.currentMatch;
    if (currentMatch?.chatRoomId == widget.chatRoomId) {
      _seenCurrentMatchForThisRoom = true;
      return;
    }

    if (_seenCurrentMatchForThisRoom && currentMatch == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleRemoteEnd());
    }
  }

  Future<void> _loadChatRoom() async {
    try {
      final room = await _chatService.getChatRoom(widget.chatRoomId);
      if (mounted) setState(() => _chatRoom = room);
    } catch (_) {
      // Stream listener remains active and can still render once connection recovers.
    }
  }

  Future<void> _sendMessage() async {
    if (widget.readOnly || _isEnded || _isSendingMessage) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final clientMessageId = _uuid.v4();
    final pending = _PendingMessage(
      clientMessageId: clientMessageId,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _pendingMessages.insert(0, pending);
      _isSendingMessage = true;
      _messageController.clear();
    });

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        senderId: _authService.uid!,
        text: text,
        clientMessageId: clientMessageId,
      );
      if (!mounted) return;
      setState(() {
        _isSendingMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingMessage = false;
        final index = _pendingMessages
            .indexWhere((m) => m.clientMessageId == clientMessageId);
        if (index != -1) {
          _pendingMessages[index] = _pendingMessages[index].copyWith(
            status: _PendingStatus.failed,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send message. Chat may have ended.')),
      );
    }
  }

  Future<void> _exitChat() async {
    if (widget.readOnly) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final matchmakingService = context.read<MatchmakingService>();
    final navigator = Navigator.of(context);
    final uid = _authService.uid;
    if (uid == null) return;

    try {
      if (!_isEnded) {
        setState(() => _isEndingLocally = true);
        await _chatService.markChatEndedLocally(
          chatRoomId: widget.chatRoomId,
          endedByUid: uid,
        );
        await _chatService.endChat(
          chatRoomId: widget.chatRoomId,
        );
      }
      if (!mounted) return;
      await matchmakingService.clearCurrentMatch();
      if (!mounted) return;
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isEndingLocally = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to end chat right now. Please try again.')),
      );
    }
  }

  Future<void> _handleRemoteEnd() async {
    if (_remoteEndHandled || _isEndingLocally || !mounted) return;
    _remoteEndHandled = true;
    final matchmakingService = context.read<MatchmakingService>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chat ended'),
        content: const Text('The other user has ended this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await matchmakingService.clearCurrentMatch();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmExitChat() async {
    if (widget.readOnly) return true;
    if (_isEnded) return true;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit chat?'),
        content: const Text('Are you sure you want to end this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  Future<void> _handleBackPressed() async {
    if (_isEndingLocally) return;
    if (widget.readOnly) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final confirmed = await _confirmExitChat();
    if (confirmed) {
      await _exitChat();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
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
        final ended = room?.endedBy != null || room?.isEnded == true;
        if (ended && !_isEnded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isEnded = true);
          });
        }
        if (room != null &&
            room.endedBy != null &&
            room.endedBy != myUid &&
            !widget.readOnly &&
            !_remoteEndHandled) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleRemoteEnd());
        }
        final otherProfile = room?.getOtherProfile(myUid);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleBackPressed();
          },
          child: Scaffold(
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
                onPressed: _handleBackPressed,
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
                    final sentIds = messages
                        .where((m) => m.senderId == myUid && m.clientMessageId != null)
                        .map((m) => m.clientMessageId!)
                        .toSet();
                    final visiblePending = _pendingMessages
                        .where((m) => !sentIds.contains(m.clientMessageId))
                        .toList();

                    if (messages.isEmpty && visiblePending.isEmpty) {
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
                      itemCount: visiblePending.length + messages.length,
                      itemBuilder: (context, index) {
                        if (index < visiblePending.length) {
                          return _PendingMessageBubble(message: visiblePending[index]);
                        }
                        final message = messages[index - visiblePending.length];
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
              if (!widget.readOnly) _buildInputBar(),
            ],
          ),
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
            onPressed: (_isEnded || _isSendingMessage) ? null : _sendMessage,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PendingStatus { sending, failed }

class _PendingMessage {
  final String clientMessageId;
  final String text;
  final DateTime createdAt;
  final _PendingStatus status;

  _PendingMessage({
    required this.clientMessageId,
    required this.text,
    required this.createdAt,
    this.status = _PendingStatus.sending,
  });

  _PendingMessage copyWith({_PendingStatus? status}) {
    return _PendingMessage(
      clientMessageId: clientMessageId,
      text: text,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

class _PendingMessageBubble extends StatelessWidget {
  final _PendingMessage message;

  const _PendingMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.sentBubble.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(message.createdAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (message.status == _PendingStatus.sending)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  if (message.status == _PendingStatus.failed)
                    Icon(
                      Icons.error_outline_rounded,
                      size: 13,
                      color: Colors.orange.shade200,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
