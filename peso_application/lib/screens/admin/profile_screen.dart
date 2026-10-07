import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/branded_app_bar.dart';
import 'applicants_screen.dart';
import 'jobs_management_screen.dart';
import '../terms_policy_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Future<void> _pickProfileImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return;
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.uploadProfileImage(File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile photo updated successfully.'
                : 'Unable to upload picture.',
          ),
        ),
      );
      if (success) await authProvider.loadStoredUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Unable to pick profile photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: BrandedAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            tooltip: 'System settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1F3A), Color(0xFF0F3D7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F3D7A).withAlpha(45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0x337C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    user?.name ?? 'Admin',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Administrator',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1F2A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoTile(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: user?.email ?? '',
                  ),
                  const Divider(height: 1),
                  _InfoTile(
                    icon: Icons.verified_user_rounded,
                    label: 'Role',
                    value: 'Administrator',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administrator overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1F2A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AdminRoleDetail(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Access level',
                    value: 'Full system administrator',
                  ),
                  const Divider(height: 1),
                  _AdminRoleDetail(
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Platform responsibility',
                    value: 'Users, employers, job posts, and reports',
                  ),
                  const Divider(height: 1),
                  _AdminRoleDetail(
                    icon: Icons.verified_outlined,
                    label: 'Account status',
                    value: 'Active and verified',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('System settings'),
                  subtitle: Text('Manage the administrator workspace'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Change profile photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickProfileImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: const Text('Edit terms and policies'),
                  subtitle: const Text('Update rules and protocols'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsPolicyScreen(canEdit: true),
                      ),
                    );
                  },
                ),
                _AdminSettingTile(
                  icon: Icons.settings_outlined,
                  label: 'System Settings',
                  isSelected: true,
                  onTap: () => Navigator.pop(sheetContext),
                ),
                _AdminSettingTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => _selectSection(sheetContext, 0),
                ),
                _AdminSettingTile(
                  icon: Icons.people_outline,
                  label: 'User Management',
                  onTap: () => _selectSection(sheetContext, 1),
                ),
                _AdminSettingTile(
                  icon: Icons.person_search_outlined,
                  label: 'Applicants',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminApplicantsScreen(),
                      ),
                    );
                  },
                ),
                _AdminSettingTile(
                  icon: Icons.business_outlined,
                  label: 'Employers',
                  onTap: () => _selectSection(sheetContext, 1),
                ),
                _AdminSettingTile(
                  icon: Icons.work_outline,
                  label: 'Manage All Jobs',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminJobsManagementScreen(),
                      ),
                    );
                  },
                ),
                _AdminSettingTile(
                  icon: Icons.assignment_outlined,
                  label: 'My Jobs',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminJobsManagementScreen(
                          adminJobsOnly: true,
                        ),
                      ),
                    );
                  },
                ),
                _AdminSettingTile(
                  icon: Icons.analytics_outlined,
                  label: 'Reports & Analytics',
                  onTap: () => _selectSection(sheetContext, 3),
                ),
                _AdminSettingTile(
                  icon: Icons.campaign_outlined,
                  label: 'Announcements',
                  onTap: () => _selectSection(sheetContext, 2),
                ),
                _AdminSettingTile(
                  icon: Icons.message_outlined,
                  label: 'Messages',
                  onTap: () => _selectSection(sheetContext, 4),
                ),
                _AdminSettingTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Audit Logs',
                  onTap: () => _selectSection(sheetContext, 3),
                ),
                const Divider(height: 8),
                _AdminSettingTile(
                  icon: Icons.logout_outlined,
                  label: 'Logout',
                  iconColor: Colors.red,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmLogout(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectSection(BuildContext sheetContext, int index) {
    Navigator.pop(sheetContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNavigate?.call(index);
    });
  }

  void _confirmLogout(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await authProvider.logout();
              if (!dialogContext.mounted) return;
              Navigator.of(
                dialogContext,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _AdminRoleDetail extends StatelessWidget {
  const _AdminRoleDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F3D7A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1C1F2A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSettingTile extends StatelessWidget {
  const _AdminSettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF0F3D7A))
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1C1F2A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
