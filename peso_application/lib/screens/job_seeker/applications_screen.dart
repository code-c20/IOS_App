import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/application_provider.dart';
import '../../models/application.dart';
import '../../utils/constants.dart';
import '../../widgets/application_card.dart';
import '../../widgets/branded_app_bar.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<ApplicationProvider>().fetchApplications(userId);
      }
    });
  }

  Future<void> _refreshApplications() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<ApplicationProvider>().fetchApplications(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(
        title: 'Applications',
        gradientColors: [Color(0xFF075443), Color(0xFF0B8F78)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your applications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConstants.textDark),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _StatusFilter(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        color: const Color(AppConstants.primaryColor),
                        isSelected: _selectedStatus == 'all',
                        onTap: () => setState(() => _selectedStatus = 'all'),
                      ),
                      _StatusFilter(
                        label: 'New',
                        icon: Icons.fiber_new_rounded,
                        color: const Color(AppConstants.accentColor),
                        isSelected: _selectedStatus == AppConstants.statusNew,
                        onTap: () => setState(
                          () => _selectedStatus = AppConstants.statusNew,
                        ),
                      ),
                      _StatusFilter(
                        label: 'Shortlisted',
                        icon: Icons.star_outline_rounded,
                        color: const Color(AppConstants.successColor),
                        isSelected:
                            _selectedStatus == AppConstants.statusShortlisted,
                        onTap: () => setState(
                          () =>
                              _selectedStatus = AppConstants.statusShortlisted,
                        ),
                      ),
                      _StatusFilter(
                        label: 'Pending',
                        icon: Icons.schedule_rounded,
                        color: const Color(AppConstants.warningColor),
                        isSelected:
                            _selectedStatus == AppConstants.statusPending,
                        onTap: () => setState(
                          () => _selectedStatus = AppConstants.statusPending,
                        ),
                      ),
                      _StatusFilter(
                        label: 'Rejected',
                        icon: Icons.close_rounded,
                        color: const Color(AppConstants.dangerColor),
                        isSelected:
                            _selectedStatus == AppConstants.statusRejected,
                        onTap: () => setState(
                          () => _selectedStatus = AppConstants.statusRejected,
                        ),
                      ),
                      _StatusFilter(
                        label: 'Accepted',
                        icon: Icons.check_rounded,
                        color: const Color(AppConstants.successColor),
                        isSelected:
                            _selectedStatus == AppConstants.statusAccepted,
                        onTap: () => setState(
                          () => _selectedStatus = AppConstants.statusAccepted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<ApplicationProvider>(
              builder: (context, appProvider, _) {
                return RefreshIndicator(
                  onRefresh: _refreshApplications,
                  child: appProvider.isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: CircularProgressIndicator()),
                          ],
                        )
                      : Builder(
                          builder: (context) {
                            final filteredApps = _selectedStatus == 'all'
                                ? appProvider.applications
                                : appProvider.applications
                                      .where(
                                        (app) => app.status == _selectedStatus,
                                      )
                                      .toList();

                            if (filteredApps.isEmpty) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                children: [
                                  const SizedBox(height: 120),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.note_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No applications',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Apply to jobs to see your applications here.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: filteredApps.length,
                              itemBuilder: (context, index) {
                                final app = filteredApps[index];
                                return ApplicationCard(
                                  application: app,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ApplicationDetailScreen(
                                              application: app,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
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

class ApplicationDetailScreen extends StatelessWidget {
  const ApplicationDetailScreen({super.key, required this.application});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(application.status);
    final steps = [
      _TimelineStep(
        title: 'Application submitted',
        date: _formatDate(application.appliedDate),
        icon: Icons.send_outlined,
        isComplete: true,
      ),
      if (application.reviewedDate != null)
        _TimelineStep(
          title: 'Application reviewed',
          date: _formatDate(application.reviewedDate!),
          icon: Icons.visibility_outlined,
          isComplete: true,
        ),
      _TimelineStep(
        title: _statusTitle(application.status),
        date: application.reviewedDate == null
            ? 'Awaiting employer review'
            : 'Current status',
        icon: Icons.flag_outlined,
        isComplete: true,
        isCurrent: true,
      ),
      if (application.interviewDate != null)
        _TimelineStep(
          title: 'Interview scheduled',
          date:
              '${_formatDate(application.interviewDate!)} at ${_formatTime(application.interviewDate!)}',
          icon: Icons.event_available_outlined,
          isComplete: true,
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(title: const Text('Application details'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF075443),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.work_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    application.jobTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusTitle(application.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Application progress',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < steps.length; index++)
                    _ApplicationTimelineItem(
                      step: steps[index],
                      color: statusColor,
                      isLast: index == steps.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _InfoSection(
              icon: Icons.calendar_today_outlined,
              label: 'Applied date',
              value: _formatDate(application.appliedDate),
            ),
            const SizedBox(height: 12),
            if (application.interviewDate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB84D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: Color(0xFFFFA500)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Interview on ${_formatDate(application.interviewDate!)} at ${_formatTime(application.interviewDate!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (application.coverLetter?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 20),
              const Text(
                'Cover letter',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  application.coverLetter!,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusAccepted:
      case AppConstants.statusShortlisted:
        return const Color(AppConstants.successColor);
      case AppConstants.statusPending:
        return const Color(AppConstants.warningColor);
      case AppConstants.statusRejected:
        return const Color(AppConstants.dangerColor);
      default:
        return const Color(AppConstants.accentColor);
    }
  }

  static String _statusTitle(String status) {
    if (status.isEmpty) return 'Application received';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.date,
    required this.icon,
    required this.isComplete,
    this.isCurrent = false,
  });

  final String title;
  final String date;
  final IconData icon;
  final bool isComplete;
  final bool isCurrent;
}

class _ApplicationTimelineItem extends StatelessWidget {
  const _ApplicationTimelineItem({
    required this.step,
    required this.color,
    required this.isLast,
  });

  final _TimelineStep step;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Icon(
                step.icon,
                size: 21,
                color: step.isCurrent ? color : const Color(0xFF0B8F78),
              ),
              if (!isLast)
                Container(width: 2, height: 42, color: const Color(0xFFD8EAE4)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  step.date,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoSection({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A7CFF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1F2A),
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

class _StatusFilter extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilter({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFD9E2E7),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withAlpha(45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: isSelected ? Colors.white : color),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : const Color(AppConstants.textDark),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
