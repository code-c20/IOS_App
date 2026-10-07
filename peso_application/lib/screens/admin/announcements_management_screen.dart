import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../utils/constants.dart';
import '../../models/announcement.dart';
import '../../services/supabase_service.dart';
import '../../widgets/branded_app_bar.dart';
import 'package:peso_application/utils/app_feedback.dart';

class AnnouncementsManagementScreen extends StatefulWidget {
  const AnnouncementsManagementScreen({super.key});

  @override
  State<AnnouncementsManagementScreen> createState() =>
      _AnnouncementsManagementScreenState();
}

class _AnnouncementsManagementScreenState
    extends State<AnnouncementsManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  String? _error;
  List<Announcement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final announcements = await _supabaseService.getAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load announcements.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteAnnouncement(String announcementId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text(
          'This action will permanently delete the announcement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _supabaseService.deleteAnnouncement(
                announcementId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Announcement deleted'
                          : 'Failed to delete announcement',
                    ),
                    backgroundColor: success
                        ? const Color(AppConstants.successColor)
                        : const Color(AppConstants.dangerColor),
                  ),
                );
                if (success) _loadAnnouncements();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(title: 'Announcements'),
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
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
                        'Announcements',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create and manage platform announcements',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_announcements.length} announcements published',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(
              title: 'Recent announcements',
              subtitle: 'Manage your published announcements',
            ),
            const SizedBox(height: 12),
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
            ] else if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ] else if (_announcements.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 72,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No announcements yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a new announcement to keep users informed.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else
              ..._announcements.map((announcement) {
                return _AnnouncementCard(
                  title: announcement.title,
                  category: announcement.category,
                  message: announcement.description,
                  publishDate: announcement.publishDate,
                  onDelete: () => _deleteAnnouncement(announcement.id),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => const _CreateAnnouncementScreen(),
              ),
            )
            .then((_) => _loadAnnouncements()),
        backgroundColor: const Color(0xFF1A7CFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text(
          'Create',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _CreateAnnouncementScreen extends StatefulWidget {
  const _CreateAnnouncementScreen();

  @override
  State<_CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<_CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedRoles = {
    AppConstants.roleJobSeeker,
    AppConstants.roleEmployer,
    AppConstants.roleAdmin,
  };
  bool _sendToAllAccounts = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final announcement = Announcement(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      imagePath: '',
      publishDate: DateTime.now(),
      targetRoles: _sendToAllAccounts ? const ['all'] : _selectedRoles.toList(),
    );

    final success = await SupabaseService().createAnnouncement(announcement);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Announcement created successfully.')),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = 'Failed to create announcement. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Announcement'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create an announcement',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visibility',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _RoleSelectorChip(
                      label: 'All accounts',
                      selected: _sendToAllAccounts,
                      onTap: () {
                        setState(() {
                          _sendToAllAccounts = !_sendToAllAccounts;
                          if (_sendToAllAccounts) {
                            _selectedRoles
                              ..clear()
                              ..addAll([
                                AppConstants.roleJobSeeker,
                                AppConstants.roleEmployer,
                                AppConstants.roleAdmin,
                              ]);
                          }
                        });
                      },
                    ),
                    _RoleSelectorChip(
                      label: 'Job Seeker',
                      selected: _selectedRoles.contains(
                        AppConstants.roleJobSeeker,
                      ),
                      onTap: () {
                        setState(() {
                          if (_selectedRoles.contains(
                            AppConstants.roleJobSeeker,
                          )) {
                            _selectedRoles.remove(AppConstants.roleJobSeeker);
                          } else {
                            _selectedRoles.add(AppConstants.roleJobSeeker);
                          }
                          _sendToAllAccounts = false;
                        });
                      },
                    ),
                    _RoleSelectorChip(
                      label: 'Employer',
                      selected: _selectedRoles.contains(
                        AppConstants.roleEmployer,
                      ),
                      onTap: () {
                        setState(() {
                          if (_selectedRoles.contains(
                            AppConstants.roleEmployer,
                          )) {
                            _selectedRoles.remove(AppConstants.roleEmployer);
                          } else {
                            _selectedRoles.add(AppConstants.roleEmployer);
                          }
                          _sendToAllAccounts = false;
                        });
                      },
                    ),
                    _RoleSelectorChip(
                      label: 'Admin',
                      selected: _selectedRoles.contains(AppConstants.roleAdmin),
                      onTap: () {
                        setState(() {
                          if (_selectedRoles.contains(AppConstants.roleAdmin)) {
                            _selectedRoles.remove(AppConstants.roleAdmin);
                          } else {
                            _selectedRoles.add(AppConstants.roleAdmin);
                          }
                          _sendToAllAccounts = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
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
                        : const Text('Publish Announcement'),
                  ),
                ),
              ],
            ),
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

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String category;
  final String message;
  final DateTime publishDate;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.title,
    required this.category,
    required this.message,
    required this.publishDate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(31),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(onTap: onDelete, child: const Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              'Published: ${publishDate.toString().split('.')[0]}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
