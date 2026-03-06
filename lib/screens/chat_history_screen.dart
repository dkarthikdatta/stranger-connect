import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/models/chat_room_model.dart';
import 'package:stranger_connect/screens/chat_screen.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/chat_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final uid = authService.uid!;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat History')),
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: chatService.getUserChatRooms(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Shake your phone to connect!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final other = room.getOtherProfile(uid);
              final timeStr = room.lastMessageAt != null
                  ? DateFormat.MMMd().add_jm().format(room.lastMessageAt!)
                  : '';

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.cardColor,
                  backgroundImage: other?.profilePicUrl != null
                      ? CachedNetworkImageProvider(other!.profilePicUrl!)
                      : null,
                  child: other?.profilePicUrl == null
                      ? const Icon(Icons.person, color: AppTheme.textSecondary)
                      : null,
                ),
                title: Text(
                  other?.displayName ?? 'Stranger',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  room.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatRoomId: room.id,
                        readOnly: true,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
