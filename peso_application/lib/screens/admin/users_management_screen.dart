import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/branded_app_bar.dart';
import 'package:peso_application/utils/app_feedback.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'all';
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> get _filteredUsers {
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final matchesStatus =
          _statusFilter == 'all' || user.accountStatus == _statusFilter;
      final matchesQuery =
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query) ||
          user.accountStatus.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _supabaseService.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load users: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openCreateUser(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const _CreateUserScreen()))
        .then((_) {
          _loadUsers();
        });
  }

  void _suspendUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspend $userName?'),
        content: const Text(
          'This account will be suspended and the user will still be able to sign in, but they will lose access to role-based actions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _supabaseService.suspendUser(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Account suspended'
                          : 'Failed to suspend account',
                    ),
                    backgroundColor: success
                        ? const Color(AppConstants.successColor)
                        : const Color(AppConstants.dangerColor),
                  ),
                );
                if (success) _loadUsers();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _reactivateUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reactivate $userName?'),
        content: const Text(
          'This account will be restored to active status. The user can log in again once approved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _supabaseService.reactivateUser(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Account reactivated'
                          : 'Failed to reactivate account',
                    ),
                    backgroundColor: success
                        ? const Color(AppConstants.successColor)
                        : const Color(AppConstants.dangerColor),
                  ),
                );
                if (success) _loadUsers();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $userName?'),
        content: const Text(
          'This action will permanently delete the account and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _supabaseService.deleteUser(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Account deleted' : 'Failed to delete account',
                    ),
                    backgroundColor: success
                        ? const Color(AppConstants.successColor)
                        : const Color(AppConstants.dangerColor),
                  ),
                );
                if (success) _loadUsers();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _readableRole(String role) {
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

  Color _badgeColor(BuildContext context, String role) {
    switch (role.toLowerCase()) {
      case 'job_seeker':
        return Colors.green.shade100;
      case 'employer':
        return Colors.blue.shade100;
      case 'admin':
        return Colors.purple.shade100;
      default:
        return Theme.of(context).primaryColor.withAlpha(31);
    }
  }

  Color _badgeTextColor(BuildContext context, String role) {
    switch (role.toLowerCase()) {
      case 'job_seeker':
        return Colors.green.shade800;
      case 'employer':
        return Colors.blue.shade800;
      case 'admin':
        return Colors.purple.shade800;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = _users.length;
    final adminCount = _users
        .where((user) => user.role == AppConstants.roleAdmin)
        .length;
    final suspendedCount = _users
        .where((user) => user.accountStatus == 'suspended')
        .length;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(title: 'Users Management'),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'User Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add and manage accounts for job seekers, employers, and admins.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Total users',
                          value: totalUsers.toString(),
                          color: Theme.of(context).primaryColor.withAlpha(20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatChip(
                          label: 'Admins',
                          value: adminCount.toString(),
                          color: const Color(0xFF8E44AD).withAlpha(20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${_users.length})'),
                          selected: _statusFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Active (${_users.where((user) => user.accountStatus != 'suspended' && user.accountStatus != 'deleted').length})',
                          ),
                          selected: _statusFilter == 'active',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'active'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Suspended ($suspendedCount)'),
                          selected: _statusFilter == 'suspended',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'suspended'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Deleted (${_users.where((user) => user.accountStatus == 'deleted').length})',
                          ),
                          selected: _statusFilter == 'deleted',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'deleted'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name, email, or role',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(
              title: 'Users list',
              subtitle: 'Browse accounts and review roles',
            ),
            const SizedBox(height: 12),
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
            ] else if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
            ] else if (_filteredUsers.isEmpty && _users.isNotEmpty) ...[
              const Text('No users match your search.'),
              const SizedBox(height: 20),
            ] else if (_users.isEmpty) ...[
              const Text('No registered user accounts were returned.'),
              const SizedBox(height: 20),
            ] else
              ..._filteredUsers.map((user) {
                return _UserTile(
                  userId: user.id,
                  name: user.name,
                  profileImage: user.profileImage,
                  role: _readableRole(user.role),
                  email: user.email,
                  accountStatus: user.accountStatus,
                  badgeColor: _badgeColor(context, user.role),
                  badgeTextColor: _badgeTextColor(context, user.role),
                  onSuspend: user.accountStatus == 'suspended'
                      ? null
                      : () => _suspendUser(user.id, user.name),
                  onReactivate: user.accountStatus == 'suspended'
                      ? () => _reactivateUser(user.id, user.name)
                      : null,
                  onDelete: () => _deleteUser(user.id, user.name),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateUser(context),
        backgroundColor: const Color(0xFF1A7CFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add User',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _CreateUserScreen extends StatefulWidget {
  const _CreateUserScreen();

  @override
  State<_CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<_CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _selectedRole = AppConstants.roleJobSeeker;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await SupabaseService().createUserAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _selectedRole,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(content: Text('User created successfully.')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Failed to create user. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = _formatCreateUserError(e);
      });
    }
  }

  String _formatCreateUserError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('failed to connect')) {
      return 'Unable to connect to the service. Please check your internet connection and try again.';
    }

    if (text.contains('permission denied') ||
        text.contains('row level security') ||
        text.contains('policy') ||
        text.contains('rls')) {
      return 'The admin account creation is blocked by the database policy. Please update the Supabase users policy to allow admin inserts.';
    }

    if (text.contains('duplicate') || text.contains('already exists')) {
      return 'This user already exists. Try a different email address.';
    }

    if (text.contains('invalid') || text.contains('password')) {
      return 'The admin account details could not be accepted. Please review the email and password.';
    }

    return 'Failed to create user. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isEmployer = _selectedRole == AppConstants.roleEmployer;

    return Scaffold(
      appBar: AppBar(title: const Text('Create User'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new user',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a job seeker or employer account from the admin portal.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _RoleSelectorChip(
                              label: 'Job Seeker',
                              selected:
                                  _selectedRole == AppConstants.roleJobSeeker,
                              onTap: () => setState(
                                () =>
                                    _selectedRole = AppConstants.roleJobSeeker,
                              ),
                            ),
                            _RoleSelectorChip(
                              label: 'Employer',
                              selected:
                                  _selectedRole == AppConstants.roleEmployer,
                              onTap: () => setState(
                                () => _selectedRole = AppConstants.roleEmployer,
                              ),
                            ),
                            _RoleSelectorChip(
                              label: 'Admin',
                              selected: _selectedRole == AppConstants.roleAdmin,
                              onTap: () => setState(
                                () => _selectedRole = AppConstants.roleAdmin,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: isEmployer
                                ? 'Company Name'
                                : 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter ${isEmployer ? 'company name' : 'full name'}.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an email address.';
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(value.trim())) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password.';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedRole == AppConstants.roleAdmin
                              ? 'You are creating a new admin account. Make sure this user should have full platform access.'
                              : 'Create a job seeker, employer, or admin account from the admin portal.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Create User'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelectorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleSelectorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final String userId;
  final String name;
  final String? profileImage;
  final String role;
  final String email;
  final String accountStatus;
  final Color badgeColor;
  final Color badgeTextColor;
  final VoidCallback? onSuspend;
  final VoidCallback? onReactivate;
  final VoidCallback? onDelete;

  const _UserTile({
    required this.userId,
    required this.name,
    this.profileImage,
    required this.role,
    required this.email,
    required this.accountStatus,
    required this.badgeColor,
    required this.badgeTextColor,
    this.onSuspend,
    this.onReactivate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UserAvatar(name: name, imageUrl: profileImage, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accountStatus == 'suspended'
                          ? Colors.orange.shade100
                          : accountStatus == 'deleted'
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      accountStatus == 'suspended'
                          ? 'Suspended'
                          : accountStatus == 'deleted'
                          ? 'Deleted'
                          : 'Active',
                      style: TextStyle(
                        color: accountStatus == 'suspended'
                            ? Colors.orange.shade900
                            : accountStatus == 'deleted'
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  PopupMenuButton(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => [
                      if (onSuspend != null)
                        PopupMenuItem(
                          onTap: onSuspend,
                          child: const Text('Suspend'),
                        ),
                      if (onReactivate != null)
                        PopupMenuItem(
                          onTap: onReactivate,
                          child: const Text('Reactivate'),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          onTap: onDelete,
                          child: const Text('Delete'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
