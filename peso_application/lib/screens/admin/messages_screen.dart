import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/branded_app_bar.dart';
import '../messages/conversation_screen.dart';
import '../messages/user_selector_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      Future.microtask(() {
        if (mounted) {
          context.read<MessageProvider>().loadConversations(currentUser.id);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = context.watch<MessageProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final query = _searchController.text.trim().toLowerCase();

    final filteredConversations = query.isEmpty
        ? messageProvider.conversations
        : messageProvider.conversations.where((conversation) {
            final otherParticipant =
                currentUser?.id == conversation.participant1Id
                ? conversation.participant2Name
                : conversation.participant1Name;
            final participantName = (otherParticipant ?? '').toLowerCase();
            final lastMessage = (conversation.lastMessage ?? '').toLowerCase();
            return participantName.contains(query) ||
                lastMessage.contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: const BrandedAppBar(title: 'Messages'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations or people',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Find a user to message',
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              color: Color(0xFF1A7CFF),
                            ),
                            onPressed: () => _openUserSearch(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                        ],
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredConversations.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  messageProvider.conversations.isEmpty
                      ? 'Search for a person to start a conversation'
                      : 'No matching conversations',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...filteredConversations.map((conversation) {
              final otherParticipant =
                  currentUser?.id == conversation.participant1Id
                  ? conversation.participant2Name
                  : conversation.participant1Name;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: UserAvatar(
                      name: otherParticipant ?? 'Unknown User',
                      imageUrl: conversation.otherParticipantProfileImage(
                        currentUser?.id ?? '',
                      ),
                      radius: 22,
                      backgroundColor: const Color(0xFFEAF3FF),
                      foregroundColor: const Color(0xFF1A7CFF),
                    ),
                    title: Text(
                      otherParticipant ?? 'Unknown User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1F2A),
                      ),
                    ),
                    subtitle: Text(
                      conversation.lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.black54,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ConversationScreen(conversation: conversation),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const UserSelectorScreen()));
        },
        backgroundColor: const Color(0xFF1A7CFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.message_rounded),
        label: const Text(
          'Message',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }

  void _openUserSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserSelectorScreen(initialQuery: _searchController.text.trim()),
      ),
    );
  }
}
