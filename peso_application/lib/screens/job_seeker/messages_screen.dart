import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../utils/constants.dart';
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
  final _searchController = TextEditingController();
  String _selectedTab = 'All';
  bool _hasInitialized = false;

  static const _tabs = ['All', 'Employers', 'Job Seekers', 'Admin'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser != null && !_hasInitialized) {
        _hasInitialized = true;
        context.read<MessageProvider>().loadConversations(currentUser.id);
      }
    });
  }

  Future<void> _refreshConversations() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      await context.read<MessageProvider>().loadConversations(currentUser.id);
    }
  }

  List<Conversation> _filteredConversations(
    List<Conversation> conversations,
    String currentUserId,
    String currentUserRole,
  ) {
    final query = _searchController.text.toLowerCase();
    return conversations.where((conversation) {
      final name = conversation
          .otherParticipantName(currentUserId)
          .toLowerCase();
      final lastMessage = (conversation.lastMessage ?? '').toLowerCase();
      final type = conversation.typeForRole(currentUserRole, currentUserId);
      final matchesQuery =
          query.isEmpty || name.contains(query) || lastMessage.contains(query);
      final matchesTab = _selectedTab == 'All' || type == _selectedTab;
      return matchesQuery && matchesTab;
    }).toList();
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
    final conversations = currentUser == null
        ? []
        : _filteredConversations(
            messageProvider.conversations,
            currentUser.id,
            currentUser.role,
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: const BrandedAppBar(
        title: 'Messages',
        gradientColors: [Color(0xFF075443), Color(0xFF0B8F78)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Find a user to message',
                                    icon: const Icon(
                                      Icons.person_add_alt_1,
                                      color: Color(AppConstants.primaryColor),
                                    ),
                                    onPressed: () => _openUserSearch(),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tabs.map((tab) {
                        final selected = _selectedTab == tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tab),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedTab = tab),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(
                              AppConstants.primaryColor,
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF1C1F2A),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: selected
                                    ? const Color(AppConstants.primaryColor)
                                    : Colors.grey[300]!,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshConversations,
                child: messageProvider.isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : conversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.message_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No conversations yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C1F2A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Messages will appear here when you start a conversation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: conversations.map((conversation) {
                          final otherParticipant = conversation
                              .otherParticipantName(currentUser?.id ?? '');

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
                                  name: otherParticipant,
                                  imageUrl: conversation
                                      .otherParticipantProfileImage(
                                        currentUser?.id ?? '',
                                      ),
                                  radius: 22,
                                  backgroundColor: const Color(0xFFEAF3FF),
                                  foregroundColor: const Color(0xFF1A7CFF),
                                ),
                                title: Text(
                                  otherParticipant,
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
                                      builder: (_) => ConversationScreen(
                                        conversation: conversation,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const UserSelectorScreen()));
        },
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.message_rounded),
        label: const Text(
          'New message',
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
