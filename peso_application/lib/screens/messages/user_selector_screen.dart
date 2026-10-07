import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import 'conversation_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class UserSelectorScreen extends StatefulWidget {
  final String? excludeRole;
  final String initialQuery;

  const UserSelectorScreen({
    super.key,
    this.excludeRole,
    this.initialQuery = '',
  });

  @override
  State<UserSelectorScreen> createState() => _UserSelectorScreenState();
}

class _UserSelectorScreenState extends State<UserSelectorScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      final users = await _supabaseService.fetchConversationUsers();

      // Filter out current user
      final filtered = users
          .where(
            (user) =>
                user.id != currentUser?.id &&
                (widget.excludeRole == null || user.role != widget.excludeRole),
          )
          .toList();

      setState(() {
        _allUsers = filtered;
        _filteredUsers = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers
          .where(
            (user) =>
                user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case AppConstants.roleJobSeeker:
        return 'Job Seeker';
      case AppConstants.roleEmployer:
        return 'Employer';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleJobSeeker:
        return Colors.blue;
      case AppConstants.roleEmployer:
        return Colors.green;
      case AppConstants.roleAdmin:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _startConversation(UserModel selectedUser) async {
    if (_isLoading) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Error: User not logged in')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      final conversation = await _supabaseService.getOrCreateConversation(
        currentUserId: currentUser.id,
        otherUserId: selectedUser.id,
      );

      if (conversation != null && mounted) {
        Navigator.of(context).pop(); // Close user selector
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text(
              'Unable to start this conversation. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text('Error starting conversation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Conversation'), elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 72,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUsers,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 72,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No users available'
                                : 'No users found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try searching with different keywords.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(
                              user.role,
                            ).withAlpha(30),
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(user.role),
                              ),
                            ),
                          ),
                          title: Text(user.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.email,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user.role).withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getRoleLabel(user.role),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getRoleColor(user.role),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _startConversation(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
