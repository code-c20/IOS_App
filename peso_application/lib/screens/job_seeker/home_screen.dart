import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/application_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/constants.dart';
import '../notification_center_screen.dart';
import 'job_details_screen.dart';
import '../../widgets/user_avatar.dart';

class JobSeekerHomeScreen extends StatefulWidget {
  const JobSeekerHomeScreen({super.key});

  @override
  State<JobSeekerHomeScreen> createState() => _JobSeekerHomeScreenState();
}

class _JobSeekerHomeScreenState extends State<JobSeekerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user != null) {
        context.read<ApplicationProvider>().fetchApplications(user.id);
      }
    });
  }

  Future<void> _refreshData() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      await Future.wait([
        context.read<JobProvider>().fetchJobs(),
        context.read<ApplicationProvider>().fetchApplications(user.id),
      ]);
    }
  }

  int _profileCompletionPercentage() {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return 0;

    final fields = [
      user.name.trim().isNotEmpty,
      user.email.trim().isNotEmpty,
      user.phone?.trim().isNotEmpty == true,
      user.location?.trim().isNotEmpty == true,
      user.bio?.trim().isNotEmpty == true,
      user.skills?.trim().isNotEmpty == true,
      user.workExperience?.trim().isNotEmpty == true,
      user.education?.trim().isNotEmpty == true,
      user.resumeImageUrl?.trim().isNotEmpty == true ||
          user.resumeUrl?.trim().isNotEmpty == true,
    ];

    final completed = fields.where((field) => field).length;
    return ((completed / fields.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final jobProvider = context.watch<JobProvider>();
    final appProvider = context.watch<ApplicationProvider>();
    final name = user?.name;
    final displayName = (name != null && name.isNotEmpty)
        ? name.split(' ').first
        : 'there';
    final savedJobsCount = jobProvider.savedJobs.length;
    final appliedCount = appProvider.applications.length;
    final shortlistedCount = appProvider.getStatusCount(
      AppConstants.statusShortlisted,
    );
    final pendingCount = appProvider.getStatusCount(AppConstants.statusPending);
    final rejectedCount = appProvider.getStatusCount(
      AppConstants.statusRejected,
    );
    final acceptedCount = appProvider.getStatusCount(
      AppConstants.statusAccepted,
    );
    final profileCompletion = _profileCompletionPercentage();
    final recentApplications = appProvider.applications.take(3).toList();

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
                colors: [Color(0xFF075443), Color(0xFF0B8F78)],
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
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _refreshData,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD8F1E8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B8F78).withAlpha(18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            name: user?.name ?? '',
                            imageUrl: user?.profileImage,
                            radius: 26,
                            backgroundColor: const Color(0xFFE4F7F0),
                            foregroundColor: const Color(0xFF0B8F78),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Color(0xFF14213D),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your job search dashboard',
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontSize: 13,
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
                                Icon(
                                  Icons.notifications_none,
                                  color: Color(0xFF14213D),
                                  size: 28,
                                ),
                                Consumer<NotificationProvider>(
                                  builder:
                                      (context, notificationProvider, child) {
                                        final unreadCount = notificationProvider
                                            .totalNotificationCount;
                                        if (unreadCount == 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF3B30),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Color(0xFF14213D),
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
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1FBF7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profile completion',
                                    style: TextStyle(
                                      color: Color(0xFF0B8F78),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$profileCompletion%',
                                    style: const TextStyle(
                                      color: Color(0xFF0B8F78),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: profileCompletion / 100,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFCDEBDD),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF0B8F78),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardSearchField(
                  onTap: () => Navigator.pushNamed(context, '/jobs'),
                ),
                const SizedBox(height: 18),
                _DiscoveryPrompt(
                  onExplore: () => Navigator.pushNamed(context, '/jobs'),
                ),
                const SizedBox(height: 18),
                _SectionHeading(
                  title: 'Recommended jobs',
                  actionLabel: 'View all',
                  onAction: () => Navigator.pushNamed(context, '/jobs'),
                ),
                const SizedBox(height: 10),
                if (jobProvider.jobs.isEmpty)
                  _EmptyJobsPrompt(
                    onTap: () => Navigator.pushNamed(context, '/jobs'),
                  )
                else
                  ...jobProvider.jobs
                      .take(3)
                      .map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecommendedJobTile(
                            job: job,
                            isSaved: jobProvider.isJobSaved(job.id),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailsScreen(job: job),
                              ),
                            ),
                            onSave: () {
                              if (jobProvider.isJobSaved(job.id)) {
                                jobProvider.unsaveJob(job.id);
                              } else {
                                jobProvider.saveJob(job);
                              }
                            },
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
                // Use a Wrap for quick actions to avoid pixel overflow on small screens.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _QuickActionCard(
                        label: 'Search Jobs',
                        icon: Icons.search,
                        onTap: () {
                          Navigator.pushNamed(context, '/jobs');
                        },
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _QuickActionCard(
                        label: 'Applications',
                        icon: Icons.folder_outlined,
                        onTap: () {
                          Navigator.pushNamed(context, '/applications');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Use Wrap for status cards so layout adapts and prevents overflow.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _StatusCard(
                        label: 'Applied',
                        count: appliedCount,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _StatusCard(
                        label: 'Saved',
                        count: savedJobsCount,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _StatusCard(
                        label: 'Shortlisted',
                        count: shortlistedCount,
                        color: Colors.indigo,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      child: _StatusCard(
                        label: 'Pending',
                        count: pendingCount,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (recentApplications.isNotEmpty)
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
                        const Text(
                          'Recent applications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recentApplications.map((application) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      AppConstants.primaryColor,
                                    ).withAlpha(18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.work_outline,
                                    size: 18,
                                    color: const Color(
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
                                        application.jobTitle,
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
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'No applications yet. Start by searching for jobs.',
                      style: TextStyle(color: Colors.grey),
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
                      const Text(
                        'Application overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MiniStatRow(
                        label: 'Rejected',
                        value: rejectedCount.toString(),
                      ),
                      _MiniStatRow(
                        label: 'Accepted',
                        value: acceptedCount.toString(),
                      ),
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
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusRejected:
        return Colors.red;
      case AppConstants.statusAccepted:
        return Colors.green;
      case AppConstants.statusShortlisted:
        return Colors.indigo;
      case AppConstants.statusPending:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickActionCard({required this.label, required this.icon, this.onTap});

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
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryColor).withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(AppConstants.primaryColor),
                  size: 20,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSearchField extends StatelessWidget {
  const _DashboardSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF0B8F78)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search jobs, keywords, or locations...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              const Icon(Icons.tune, color: Color(0xFF0B8F78), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryPrompt extends StatelessWidget {
  const _DiscoveryPrompt({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F5B), Color(0xFF0B8F78)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find the right job\nthat fits you.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Explore jobs'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF087F5B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _EmptyJobsPrompt extends StatelessWidget {
  const _EmptyJobsPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Explore current openings to discover your next opportunity.',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _RecommendedJobTile extends StatelessWidget {
  const _RecommendedJobTile({
    required this.job,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
  });

  final Job job;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F7F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline, color: Color(0xFF0B8F78)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      job.employerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${job.location}  •  ${job.salary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isSaved ? 'Remove saved job' : 'Save job',
                onPressed: onSave,
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: const Color(0xFF0B8F78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
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
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
