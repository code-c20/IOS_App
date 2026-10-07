// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/application_provider.dart';
import 'saved_jobs_screen.dart';
import '../announcement_screen.dart';
import '../notification_center_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/branded_app_bar.dart';
import 'report_history_screen.dart';
import '../terms_policy_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await authProvider.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    UserModel? user,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final locationController = TextEditingController(
      text: user?.location ?? '',
    );
    final bioController = TextEditingController(text: user?.bio ?? '');
    final skillsController = TextEditingController(text: user?.skills ?? '');
    final experienceController = TextEditingController(
      text: user?.workExperience ?? '',
    );
    final educationController = TextEditingController(
      text: user?.education ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'About me'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: skillsController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Skills'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: experienceController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Work experience',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: educationController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Education'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final success = await authProvider.updateProfile({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'location': locationController.text.trim(),
      'bio': bioController.text.trim(),
      'skills': skillsController.text.trim(),
      'work_experience': experienceController.text.trim(),
      'education': educationController.text.trim(),
    });

    if (!mounted) return;
    final msg = success
        ? 'Profile updated successfully.'
        : (context.read<AuthProvider>().error ?? 'Unable to save profile.');
    ScaffoldMessenger.of(context).showAppSnackBar(SnackBar(content: Text(msg)));
    if (success) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        await context.read<ApplicationProvider>().fetchApplications(userId);
      }
      await context.read<JobProvider>().fetchJobs();
    }
  }

  Future<void> _pickResume() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 3400,
      );
      if (picked == null) return;

      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.uploadResumeImage(File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Resume image saved successfully.'
                : 'Unable to save resume image.',
          ),
        ),
      );
      if (success) {
        final userId = context.read<AuthProvider>().currentUser?.id;
        if (userId != null) {
          await context.read<ApplicationProvider>().fetchApplications(userId);
        }
        await context.read<JobProvider>().fetchJobs();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Unable to pick resume image: $e')),
      );
    }
  }

  Future<void> _viewResume(UserModel user) async {
    final resumeUrl = user.resumeImageUrl ?? user.resumeUrl;
    if (resumeUrl == null || resumeUrl.trim().isEmpty) {
      await _pickResume();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          user.resumeImageFileName ?? user.resumeFileName ?? 'Resume',
        ),
        content: InteractiveViewer(
          child: Image.network(
            resumeUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 120,
              child: Center(child: Text('Resume could not be loaded.')),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Delete resume?'),
                  content: const Text('This will remove your saved resume.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (shouldDelete != true || !mounted) return;

              final success = await context
                  .read<AuthProvider>()
                  .deleteResumeImage();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showAppSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Resume deleted.'
                        : 'Unable to delete resume. Please try again.',
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.uploadProfileImage(file);
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

      if (success) {
        await authProvider.loadStoredUser();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text('Unable to upload picture: $e')));
    }
  }

  Future<void> _refreshProfile(BuildContext context) async {
    await context.read<AuthProvider>().loadStoredUser();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final jobProvider = context.watch<JobProvider>();
    final appProvider = context.watch<ApplicationProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF1FBF7),
      appBar: BrandedAppBar(
        title: 'My profile',
        gradientColors: const [Color(0xFF075443), Color(0xFF0B8F78)],
        actions: [
          IconButton(
            tooltip: 'Profile settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context, user),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshProfile(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF075443), Color(0xFF0B8F78)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withAlpha(40),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: UserAvatar(
                      name: user?.name ?? '',
                      imageUrl: user?.profileImage,
                      radius: 34,
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Job seeker',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Job seeker',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user?.location ?? 'Location not set',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Terms and Policies'),
                subtitle: const Text('Review app rules and protocols'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsPolicyScreen()),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ProfileStatCard(
                    label: 'Applications',
                    value: appProvider.applications.length.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    label: 'Saved',
                    value: jobProvider.savedJobs.length.toString(),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'About me',
              child: Text(
                user?.bio?.trim().isNotEmpty == true
                    ? user!.bio!
                    : 'Add a short profile summary to help employers know more about you.',
                style: TextStyle(color: Colors.grey[700], height: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Contact information',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user?.email ?? 'Not set',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user?.phone ?? 'Not set',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: user?.location ?? 'Not set',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Career details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailBlock(
                    label: 'Skills',
                    value: user?.skills?.trim().isNotEmpty == true
                        ? user!.skills!
                        : 'Add your skills and strengths.',
                  ),
                  const SizedBox(height: 12),
                  _DetailBlock(
                    label: 'Work experience',
                    value: user?.workExperience?.trim().isNotEmpty == true
                        ? user!.workExperience!
                        : 'Add your employment history.',
                  ),
                  const SizedBox(height: 12),
                  _DetailBlock(
                    label: 'Education',
                    value: user?.education?.trim().isNotEmpty == true
                        ? user!.education!
                        : 'Add your educational background.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Documents',
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: 'Resume',
                    subtitle:
                        user?.resumeImageFileName ??
                        user?.resumeFileName ??
                        'Upload resume',
                    onTap: () {
                      final currentUser = context
                          .read<AuthProvider>()
                          .currentUser;
                      if (currentUser == null) return;
                      _viewResume(currentUser);
                    },
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.image_outlined,
                    title: 'Profile photo',
                    subtitle: 'Update your profile image',
                    onTap: _pickProfileImage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSettingsSheet(BuildContext context, UserModel? user) async {
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
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Profile settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Edit profile'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditProfileDialog(context, user);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Resume Builder'),
                  subtitle: Text(
                    user?.resumeImageFileName ?? 'Upload a resume image',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickResume();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Saved Jobs'),
                  subtitle: const Text('View jobs you saved for later'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SavedJobsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report history'),
                  subtitle: const Text(
                    'View your submitted reports and updates',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final userId = context.read<AuthProvider>().currentUser?.id;
                    if (userId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportHistoryScreen(userId: userId),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Announcements'),
                  subtitle: const Text('Read the latest PESO updates'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnnouncementScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Review your latest updates'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationCenterScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Privacy & security'),
                  subtitle: const Text(
                    'Keep your account information protected',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showInfoMessage(
                      'Privacy and security settings are managed securely by your account.',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & support'),
                  subtitle: const Text('Get assistance with your account'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showInfoMessage(
                      'For support, contact your local PESO administrator.',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_outlined, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleLogout(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
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
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;

  const _DetailBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: Colors.grey[700], height: 1.5)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
