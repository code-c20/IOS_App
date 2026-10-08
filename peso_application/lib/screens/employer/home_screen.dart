import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../utils/constants.dart';
import '../notification_center_screen.dart';
import '../announcement_detail_screen.dart';
import '../../utils/route_helpers.dart';
import '../../widgets/user_avatar.dart';
import 'widgets.dart';
import 'create_job_screen.dart';
import 'applicants_screen.dart';

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        setState(() => _isLoading = true);
        Future.wait([
          context.read<JobProvider>().fetchJobs(),
          context.read<ApplicationProvider>().fetchEmployerApplications(
            user.id,
          ),
          context.read<AnnouncementProvider>().fetchAnnouncements(
            role: user.role,
          ),
        ]).whenComplete(() {
          if (!mounted) return;
          setState(() => _isLoading = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final jobProvider = context.watch<JobProvider>();
    final appProvider = context.watch<ApplicationProvider>();
    final announcementProvider = context.watch<AnnouncementProvider>();
    final latestAnnouncement = announcementProvider.latestAnnouncement;
    final safeUserName = user?.name.trim().isNotEmpty == true
        ? user!.name.split(' ').first
        : 'Employer';

    final employerJobs = user == null
        ? <Job>[]
        : jobProvider.jobs.where((job) => job.employerId == user.id).toList();

    final activeJobs = employerJobs.length;
    final totalApplications = appProvider.applications.length;
    final newApplications = appProvider.applications
        .where((app) => app.status == AppConstants.statusNew)
        .length;
    final shortlistedApplications = appProvider.applications
        .where((app) => app.status == AppConstants.statusShortlisted)
        .length;
    final hiredApplications = appProvider.applications
        .where((app) => app.status == AppConstants.statusAccepted)
        .length;
    final recentApplications = appProvider.applications.take(3).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth >= 900
        ? screenWidth - 238 - 8 - 32
        : screenWidth - 32;
    final cardWidth = (contentWidth - 12) / 2;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(AppConstants.primaryColor), Color(0xFF0A5BC7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: AppBar(
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (user != null) {
                    await Future.wait([
                      context.read<JobProvider>().fetchJobs(),
                      context
                          .read<ApplicationProvider>()
                          .fetchEmployerApplications(user.id),
                      context.read<AnnouncementProvider>().fetchAnnouncements(
                        role: user.role,
                      ),
                    ]);
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(AppConstants.primaryColor),
                              Color(0xFF0A5BC7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                AppConstants.primaryColor,
                              ).withAlpha(35),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  name:
                                      context
                                          .read<AuthProvider>()
                                          .currentUser
                                          ?.name ??
                                      '',
                                  imageUrl: context
                                      .read<AuthProvider>()
                                      .currentUser
                                      ?.profileImage,
                                  radius: 25,
                                  backgroundColor: Colors.white.withAlpha(26),
                                  foregroundColor: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        safeUserName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Hiring overview',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context
                                        .read<NotificationProvider>()
                                        .markAllAsRead();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationCenterScreen(),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(14),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.notifications_none,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      Consumer<NotificationProvider>(
                                        builder:
                                            (
                                              context,
                                              notificationProvider,
                                              child,
                                            ) {
                                              final unreadCount =
                                                  notificationProvider
                                                      .totalNotificationCount;
                                              if (unreadCount == 0) {
                                                return const SizedBox.shrink();
                                              }
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFF3B30),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  unreadCount > 99
                                                      ? '99+'
                                                      : unreadCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _EmployerPulseCard(
                        totalApplications: totalApplications,
                        activeJobs: activeJobs,
                        totalHires: hiredApplications,
                        onPostJob: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EmployerCreateJobScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _EmployerQuickActionCard(
                              label: 'Post Job',
                              icon: Icons.add_circle_outline,
                              color: const Color(0xFF4FC3F7),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EmployerCreateJobScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _EmployerQuickActionCard(
                              label: 'Applicants',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF7C4DFF),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EmployerApplicantsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: StatCard(
                              label: 'New',
                              value: newApplications.toString(),
                              icon: Icons.mark_email_unread_outlined,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: StatCard(
                              label: 'Shortlisted',
                              value: shortlistedApplications.toString(),
                              icon: Icons.star_border_rounded,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: StatCard(
                              label: 'Hired',
                              value: hiredApplications.toString(),
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: StatCard(
                              label: 'Active',
                              value: activeJobs.toString(),
                              icon: Icons.work_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (announcementProvider.isLoading)
                        const SizedBox.shrink()
                      else if (latestAnnouncement != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      latestAnnouncement.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        AppConstants.primaryColor,
                                      ).withAlpha(24),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      latestAnnouncement.category,
                                      style: const TextStyle(
                                        color: Color(AppConstants.primaryColor),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                latestAnnouncement.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      slideFromRight(
                                        AnnouncementDetailScreen(
                                          announcement: latestAnnouncement,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Read more'),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: const Text(
                                  'No team announcements yet.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent applications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EmployerApplicantsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (recentApplications.isEmpty)
                              const Text(
                                'No new applications yet. Share your job post to start receiving candidates.',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              ...recentApplications.map((application) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            AppConstants.primaryColor,
                                          ).withAlpha(20),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          size: 18,
                                          color: Color(
                                            AppConstants.primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${application.jobSeekerName} applied for ${application.jobTitle}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _statusLabel(application.status),
                                              style: TextStyle(
                                                color: _statusColor(
                                                  application.status,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusNew:
        return const Color(AppConstants.accentColor);
      case AppConstants.statusShortlisted:
        return const Color(AppConstants.primaryColor);
      case AppConstants.statusAccepted:
        return const Color(AppConstants.successColor);
      case AppConstants.statusRejected:
        return const Color(AppConstants.dangerColor);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppConstants.statusNew:
        return 'New';
      case AppConstants.statusShortlisted:
        return 'Shortlisted';
      case AppConstants.statusPending:
        return 'Interview pending';
      case AppConstants.statusRejected:
        return 'Rejected';
      case AppConstants.statusAccepted:
        return 'Accepted';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }
}

class _EmployerQuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _EmployerQuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _EmployerPulseCard extends StatelessWidget {
  const _EmployerPulseCard({
    required this.totalApplications,
    required this.activeJobs,
    required this.totalHires,
    required this.onPostJob,
  });

  final int totalApplications;
  final int activeJobs;
  final int totalHires;
  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1455D9), Color(0xFF2F7AF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1455D9).withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total applications',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      totalApplications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Live recruitment activity',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                height: 58,
                child: CustomPaint(painter: _PulsePainter()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PulseMetric(label: 'Active jobs', value: activeJobs),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(label: 'Total hires', value: totalHires),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPostJob,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Post a new job'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1455D9),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(210)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(2, size.height * .75)
      ..lineTo(size.width * .2, size.height * .42)
      ..lineTo(size.width * .38, size.height * .62)
      ..lineTo(size.width * .56, size.height * .25)
      ..lineTo(size.width * .73, size.height * .43)
      ..lineTo(size.width - 2, size.height * .08);
    canvas.drawPath(path, paint);
    final dotPaint = Paint()..color = Colors.white;
    for (final point in [
      Offset(2, size.height * .75),
      Offset(size.width * .2, size.height * .42),
      Offset(size.width * .38, size.height * .62),
      Offset(size.width * .56, size.height * .25),
      Offset(size.width * .73, size.height * .43),
      Offset(size.width - 2, size.height * .08),
    ]) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
