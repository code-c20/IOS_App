import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/announcement.dart';
import '../providers/auth_provider.dart';
import '../providers/announcement_provider.dart';
import '../utils/constants.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser != null) {
        context.read<AnnouncementProvider>().fetchAnnouncements(
          role: currentUser.role,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final announcementProvider = context.watch<AnnouncementProvider>();
    final announcements = announcementProvider.announcements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: const Color(AppConstants.primaryColor),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final currentUser = context.read<AuthProvider>().currentUser;
          if (currentUser != null) {
            await context.read<AnnouncementProvider>().fetchAnnouncements(
              role: currentUser.role,
            );
          }
        },
        child: announcementProvider.isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : announcements.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No announcements available yet.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: announcements.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final announcement = announcements[index];
                  return _AnnouncementTile(announcement: announcement);
                },
              ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(announcement.category),
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(30),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Published ${announcement.publishDate.toLocal().toString().split(' ').first}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
