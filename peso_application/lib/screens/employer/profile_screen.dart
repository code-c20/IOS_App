import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../models/user.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import '../announcement_screen.dart';
import 'create_job_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/branded_app_bar.dart';
import '../terms_policy_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class EmployerProfileScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const EmployerProfileScreen({super.key, required this.onNavigate});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      context.read<JobProvider>().fetchJobs();
      context.read<ApplicationProvider>().fetchEmployerApplications(user.id);
    });
  }

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
    final nameController = TextEditingController(
      text: user?.companyName ?? user?.name ?? '',
    );
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final locationController = TextEditingController(
      text: user?.location ?? '',
    );
    final bioController = TextEditingController(
      text: user?.companyDescription ?? '',
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
                    decoration: const InputDecoration(
                      labelText: 'Company / name',
                    ),
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
                    decoration: const InputDecoration(labelText: 'About'),
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
      'company_name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'location': locationController.text.trim(),
      'company_description': bioController.text.trim(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          success ? 'Profile updated successfully.' : 'Failed to save profile.',
        ),
      ),
    );
  }

  Future<void> _refreshProfile(BuildContext context) async {
    await context.read<AuthProvider>().loadStoredUser();
  }

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Employer settings'),
                  subtitle: Text('Manage your company account'),
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
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit company profile'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditProfileDialog(context, user);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.post_add_outlined),
                  title: const Text('Post a Job'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmployerCreateJobScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Manage Jobs'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onNavigate(1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: const Text('Applications'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onNavigate(2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Candidates'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onNavigate(2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.message_outlined),
                  title: const Text('Messages'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onNavigate(3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Announcements'),
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
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Company Profile'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onNavigate(4);
                  },
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.logout_outlined, color: Colors.red),
                  title: const Text('Logout'),
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final jobProvider = context.watch<JobProvider>();
    final applicationProvider = context.watch<ApplicationProvider>();
    final myJobs = user == null
        ? <Job>[]
        : jobProvider.jobs.where((job) => job.employerId == user.id).toList();
    final myApplicants = user == null
        ? <dynamic>[]
        : applicationProvider.applications.toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: BrandedAppBar(
        title: 'My profile',
        gradientColors: const [
          Color(AppConstants.primaryColor),
          Color(0xFF0A5BC7),
        ],
        actions: [
          IconButton(
            tooltip: 'Settings',
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withAlpha(230),
                    Theme.of(context).primaryColor.withAlpha(180),
                  ],
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
                          user?.companyName ?? user?.name ?? 'Employer',
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
                          child: Text(
                            user?.role ?? 'employer',
                            style: const TextStyle(
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
                  child: _EmployerStatCard(
                    label: 'Jobs',
                    value: myJobs.length.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EmployerStatCard(
                    label: 'Applicants',
                    value: myApplicants.length.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _EmployerSectionCard(
              title: 'About',
              child: Text(
                user?.companyDescription?.trim().isNotEmpty == true
                    ? user!.companyDescription!
                    : 'Add a short company or business description.',
                style: TextStyle(color: Colors.grey[700], height: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            _EmployerSectionCard(
              title: 'Contact details',
              child: Column(
                children: [
                  _EmployerInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user?.email ?? 'Not set',
                  ),
                  const Divider(height: 1),
                  _EmployerInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user?.phone ?? 'Not set',
                  ),
                  const Divider(height: 1),
                  _EmployerInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: user?.location ?? 'Not set',
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

class _EmployerStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _EmployerStatCard({required this.label, required this.value});

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
              color: Theme.of(context).primaryColor,
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

class _EmployerSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _EmployerSectionCard({required this.title, required this.child});

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

class _EmployerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EmployerInfoRow({
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
