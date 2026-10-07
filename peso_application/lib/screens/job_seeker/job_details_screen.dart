import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/application.dart';
import '../../models/job.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import 'package:peso_application/utils/app_feedback.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;

  const JobDetailsScreen({required this.job, super.key});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isApplied = false;
  bool _isLoadingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshApplicationStatus();
    });
  }

  Future<void> _refreshApplicationStatus() async {
    final authProvider = context.read<AuthProvider>();
    final applicationProvider = context.read<ApplicationProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null || currentUser.role != AppConstants.roleJobSeeker) {
      if (mounted) {
        setState(() {
          _isApplied = false;
          _isLoadingStatus = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingStatus = true);
    }

    await applicationProvider.fetchApplications(currentUser.id);

    if (!mounted) return;

    final alreadyApplied = applicationProvider.hasApplied(
      widget.job.id,
      currentUser.id,
    );

    setState(() {
      _isApplied = alreadyApplied;
      _isLoadingStatus = false;
    });
  }

  void _showReportDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'inappropriate_content';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report Job Listing'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please tell us why you\'re reporting this job listing.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  items:
                      [
                        'inappropriate_content',
                        'harassment',
                        'fraud',
                        'violates_policy',
                        'other',
                      ].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category.replaceAll('_', ' ').toUpperCase(),
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Report title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in detail',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          descriptionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showAppSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      final authProvider = context.read<AuthProvider>();
                      final currentUser = authProvider.currentUser;

                      if (currentUser == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            const SnackBar(
                              content: Text('Please sign in to report'),
                            ),
                          );
                          Navigator.pop(context);
                        }
                        return;
                      }

                      final supabaseService = SupabaseService();
                      final success = await supabaseService.createReport(
                        reporterId: currentUser.id,
                        reportType: 'job_report',
                        subjectId: widget.job.id,
                        category: selectedCategory,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showAppSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Report submitted successfully'
                                  : 'Failed to submit report',
                            ),
                            backgroundColor: success
                                ? const Color(AppConstants.successColor)
                                : const Color(AppConstants.dangerColor),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final isSaved = jobProvider.isJobSaved(widget.job.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              if (isSaved) {
                jobProvider.unsaveJob(widget.job.id);
              } else {
                jobProvider.saveJob(widget.job);
              }
            },
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Report this job'),
                onTap: () => WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _showReportDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(AppConstants.primaryColor),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.job.employerName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _DetailBadge(
                        icon: Icons.schedule,
                        label: widget.job.isFullTime
                            ? 'Full-time'
                            : 'Part-time',
                      ),
                      const SizedBox(width: 10),
                      _DetailBadge(
                        icon: Icons.location_on,
                        label: widget.job.location,
                      ),
                      const SizedBox(width: 10),
                      _DetailBadge(
                        icon: Icons.category,
                        label: widget.job.category,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salary',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.job.salary,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: const Color(
                                        AppConstants.primaryColor,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          widget.job.isFullTime
                              ? Icons.work_outline
                              : Icons.access_time,
                          color: const Color(AppConstants.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.job.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Requirements',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: widget.job.requirements.map((req) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: const Color(AppConstants.successColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  req,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          label: 'Posted',
                          value: _formatDate(widget.job.postedDate),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Deadline',
                          value: _formatDate(widget.job.deadline),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Applicants',
                          value: '${widget.job.applicantCount} applicants',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isSaved) {
                      jobProvider.unsaveJob(widget.job.id);
                    } else {
                      jobProvider.saveJob(widget.job);
                    }
                  },
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  label: Text(
                    isSaved ? 'Saved' : 'Save',
                    style: const TextStyle(
                      color: Color(AppConstants.primaryColor),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(AppConstants.primaryColor),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingStatus || _isApplied
                      ? null
                      : () async {
                          final authProvider = context.read<AuthProvider>();
                          final applicationProvider = context
                              .read<ApplicationProvider>();

                          if (authProvider.currentUser == null) {
                            ScaffoldMessenger.of(context).showAppSnackBar(
                              const SnackBar(
                                content: Text('Please sign in to apply.'),
                              ),
                            );
                            return;
                          }

                          final alreadyApplied = applicationProvider.hasApplied(
                            widget.job.id,
                            authProvider.currentUser!.id,
                          );

                          if (alreadyApplied) {
                            setState(() => _isApplied = true);
                            ScaffoldMessenger.of(context).showAppSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You have already applied for this job.',
                                ),
                                backgroundColor: Color(
                                  AppConstants.warningColor,
                                ),
                              ),
                            );
                            return;
                          }

                          final application = JobApplication(
                            id: const Uuid().v4(),
                            jobId: widget.job.id,
                            jobTitle: widget.job.title,
                            jobSeekerId: authProvider.currentUser!.id,
                            jobSeekerName: authProvider.currentUser!.name,
                            status: AppConstants.statusNew,
                            coverLetter: null,
                            appliedDate: DateTime.now(),
                            reviewedDate: null,
                          );

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final jobProvider = context.read<JobProvider>();
                          final success = await applicationProvider.applyForJob(
                            application,
                          );
                          if (!mounted) return;

                          if (success) {
                            await jobProvider.refreshJob(widget.job.id);
                            setState(() => _isApplied = true);
                            scaffoldMessenger.showAppSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Application submitted successfully!',
                                ),
                                backgroundColor: Color(
                                  AppConstants.successColor,
                                ),
                              ),
                            );
                          } else {
                            final friendlyMessage =
                                applicationProvider.error ??
                                'Unable to submit application. Please try again.';

                            scaffoldMessenger.showAppSnackBar(
                              SnackBar(
                                content: Text(friendlyMessage),
                                backgroundColor: Color(
                                  AppConstants.dangerColor,
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isLoadingStatus
                        ? 'Checking...'
                        : _isApplied
                        ? 'Applied'
                        : 'Apply Now',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }
}

class _DetailBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
