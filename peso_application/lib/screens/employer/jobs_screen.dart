import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/branded_app_bar.dart';
import 'widgets.dart';
import 'create_job_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class EmployerJobsScreen extends StatefulWidget {
  const EmployerJobsScreen({super.key, this.adminView = false});

  final bool adminView;

  @override
  State<EmployerJobsScreen> createState() => _EmployerJobsScreenState();
}

class _EmployerJobsScreenState extends State<EmployerJobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobProvider>().fetchJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final List<Job> myJobs = currentUser == null
        ? <Job>[]
        : jobProvider.jobs
              .where((job) => job.employerId == currentUser.id)
              .toList();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: BrandedAppBar(
        title: widget.adminView ? 'My Jobs' : 'Jobs',
        gradientColors: const [
          Color(AppConstants.primaryColor),
          Color(0xFF0A5BC7),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmployerCreateJobScreen()),
        ),
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Post a new job'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Manage jobs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Publish new job listings and track their performance.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Total Jobs',
                            value: myJobs.length.toString(),
                            icon: Icons.work_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Total Applicants',
                            value: myJobs
                                .map((job) => job.applicantCount)
                                .fold<int>(0, (sum, count) => sum + count)
                                .toString(),
                            icon: Icons.people_outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: jobProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : myJobs.isEmpty
                    ? const EmptyState(
                        icon: Icons.work_outline,
                        title: 'No job posts yet',
                        subtitle:
                            'Create your first opening to start receiving applications and manage hiring from one place.',
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth * 0.84).clamp(
                            320.0,
                            420.0,
                          );
                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            itemCount: myJobs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final job = myJobs[index];
                              return SizedBox(
                                width: cardWidth,
                                child: JobPostCard(
                                  title: job.title,
                                  location: job.location,
                                  salary: job.salary,
                                  applicants: job.applicantCount,
                                  jobType: job.isFullTime
                                      ? 'Full-time'
                                      : 'Part-time',
                                  onViewApplicants: () {
                                    // This will be handled from parent navigation
                                  },
                                  onCloseJob: () async {
                                    final jobProvider = context
                                        .read<JobProvider>();
                                    final navigator = Navigator.of(context);
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(navigator.context);

                                    // ignore: use_build_context_synchronously
                                    final confirm = await showDialog<bool>(
                                      context: navigator.context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Close job'),
                                        content: const Text(
                                          'Are you sure you want to close this job posting?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      final success = await jobProvider
                                          .deleteJob(job.id);
                                      if (!mounted) return;
                                      if (success) {
                                        scaffoldMessenger.showAppSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Job closed successfully.',
                                            ),
                                          ),
                                        );
                                      } else {
                                        scaffoldMessenger.showAppSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Failed to close job. Try again.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
