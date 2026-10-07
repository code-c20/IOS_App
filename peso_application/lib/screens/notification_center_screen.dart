import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import 'announcement_screen.dart';
import 'admin/navigation_screen.dart';
import 'announcement_detail_screen.dart';
import 'employer/applicant_detail_screen.dart';
import 'employer/navigation_screen.dart';
import 'job_seeker/job_details_screen.dart';
import 'job_seeker/navigation_screen.dart';
import 'messages/conversation_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.message_rounded;
      case 'job':
        return Icons.work_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'application':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationItem item,
  ) async {
    final userRole = context.read<AuthProvider>().currentUser?.role;

    switch (item.type) {
      case 'message':
        if (item.targetId == null) {
          if (userRole == AppConstants.roleEmployer) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EmployerNavigationScreen(initialIndex: 3),
              ),
            );
          } else if (userRole == AppConstants.roleAdmin) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminNavigationScreen(initialIndex: 4),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const JobSeekerNavigationScreen(initialIndex: 3),
              ),
            );
          }
          break;
        }

        final conversations = context.read<NotificationProvider>().messageProvider.conversations;
        final conversation = conversations.firstWhere(
          (entry) => entry.id == item.targetId,
          orElse: () => conversations.first,
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
        break;
      case 'job':
        if (item.targetId != null) {
          final jobProvider = context.read<NotificationProvider>().jobProvider;
          final job = jobProvider.jobs.firstWhere(
            (entry) => entry.id == item.targetId,
            orElse: () => jobProvider.jobs.first,
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
          );
          break;
        }
        if (userRole == AppConstants.roleEmployer) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EmployerNavigationScreen(initialIndex: 1),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const JobSeekerNavigationScreen(initialIndex: 1),
            ),
          );
        }
        break;
      case 'announcement':
        if (item.targetId != null) {
          final announcementProvider = context.read<NotificationProvider>().announcementProvider;
          final announcement = announcementProvider.announcements.firstWhere(
            (entry) => entry.id == item.targetId,
            orElse: () => announcementProvider.announcements.first,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnnouncementDetailScreen(announcement: announcement),
            ),
          );
          break;
        }
        if (userRole == AppConstants.roleEmployer) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AnnouncementScreen(),
            ),
          );
        } else if (userRole == AppConstants.roleAdmin) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminNavigationScreen(initialIndex: 2),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AnnouncementScreen(),
            ),
          );
        }
        break;
      case 'application':
        if (item.targetId != null) {
          final appProvider = context.read<NotificationProvider>().applicationProvider;
          final application = appProvider.applications.firstWhere(
            (entry) => entry.id == item.targetId,
            orElse: () => appProvider.applications.first,
          );
          final applicant = await SupabaseService().getJobSeekerUserByProfileId(
            application.jobSeekerId,
          );
          if (context.mounted && applicant != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ApplicantDetailScreen(
                  applicant: applicant,
                  application: application,
                ),
              ),
            );
          }
          break;
        }
        if (userRole == AppConstants.roleEmployer) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EmployerNavigationScreen(initialIndex: 2),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const JobSeekerNavigationScreen(initialIndex: 3),
            ),
          );
        }
        break;
      default:
        break;
    }

    if (context.mounted) {
      context.read<NotificationProvider>().markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(AppConstants.primaryColor),
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final items = provider.notificationItems;
          final firstUnreadIndex = items.indexWhere((item) => !item.isRead);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || items.isEmpty) return;
            final targetIndex = firstUnreadIndex >= 0 ? firstUnreadIndex : 0;
            final estimatedItemHeight = 86.0;
            final targetOffset = targetIndex * estimatedItemHeight;
            if (_scrollController.hasClients &&
                _scrollController.offset != targetOffset) {
              _scrollController.jumpTo(targetOffset);
            }
          });

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No new notifications',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(AppConstants.textLight),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];

              final unread = !item.isRead;

              return ListTile(
                tileColor: unread
                    ? const Color(AppConstants.primaryColor).withAlpha(8)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: unread
                        ? const Color(AppConstants.primaryColor).withAlpha(20)
                        : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForType(item.type),
                    color: unread
                        ? const Color(AppConstants.primaryColor)
                        : const Color(AppConstants.textLight),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: unread
                              ? const Color(AppConstants.textDark)
                              : const Color(AppConstants.textLight),
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: Color(AppConstants.primaryColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.message,
                    style: TextStyle(
                      color: unread
                          ? const Color(AppConstants.textDark)
                          : const Color(AppConstants.textLight),
                    ),
                  ),
                ),
                trailing: Text(
                  DateFormat.Hm().format(item.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread
                        ? const Color(AppConstants.primaryColor)
                        : const Color(AppConstants.textLight),
                  ),
                ),
                onTap: () async => _handleNotificationTap(context, item),
              );
            },
          );
        },
      ),
    );
  }
}
