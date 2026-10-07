import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import 'create_job_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

const _adminColor = Color(AppConstants.adminColor);

class AdminJobsManagementScreen extends StatefulWidget {
  const AdminJobsManagementScreen({super.key, this.adminJobsOnly = false});

  final bool adminJobsOnly;

  @override
  State<AdminJobsManagementScreen> createState() =>
      _AdminJobsManagementScreenState();
}

class _AdminJobsManagementScreenState extends State<AdminJobsManagementScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _adminProfileId;
  String? _loadError;
  bool _isLoadingAdminProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadJobs();
    });
  }

  Future<void> _loadJobs() async {
    if (widget.adminJobsOnly) {
      setState(() {
        _isLoadingAdminProfile = true;
        _loadError = null;
      });
      try {
        final userId = context.read<AuthProvider>().currentUser?.id;
        if (userId == null) {
          throw StateError('Sign in as an admin to view your jobs.');
        }
        _adminProfileId = await SupabaseService().getAdminProfileId(userId);
        if (_adminProfileId == null) {
          throw StateError('The signed-in account has no admin profile.');
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _loadError = error.toString();
            _isLoadingAdminProfile = false;
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() => _isLoadingAdminProfile = false);
    }

    await context.read<JobProvider>().fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Job> _filteredJobs(List<Job> jobs) {
    if (widget.adminJobsOnly) {
      jobs = jobs.where((job) => job.adminId == _adminProfileId).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return jobs;
    return jobs
        .where(
          (job) =>
              job.title.toLowerCase().contains(query) ||
              job.employerName.toLowerCase().contains(query) ||
              job.location.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _deleteJob(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove job post?'),
        content: Text(
          'This will remove "${job.title}" and its associated applications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _adminColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await context.read<JobProvider>().deleteJob(job.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          success ? 'Job post removed.' : 'Unable to remove the job post.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final jobs = _filteredJobs(provider.jobs);

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        backgroundColor: _adminColor,
        foregroundColor: Colors.white,
        title: Text(widget.adminJobsOnly ? 'My jobs' : 'Manage all jobs'),
        actions: [
          IconButton(
            tooltip: 'Refresh jobs',
            onPressed: provider.isLoading
                ? null
                : () => context.read<JobProvider>().fetchJobs(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminCreateJobScreen())),
        backgroundColor: _adminColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Post a job'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search by job, employer, or location',
                prefixIcon: const Icon(Icons.search, color: _adminColor),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load your admin jobs.\n$_loadError',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _isLoadingAdminProfile || provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : jobs.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No jobs have been posted yet.'
                          : 'No jobs match your search.',
                    ),
                  )
                : RefreshIndicator(
                    color: _adminColor,
                    onRefresh: () => context.read<JobProvider>().fetchJobs(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _adminColor,
                              child: Icon(
                                Icons.work_outline,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              job.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${job.employerName}  |  ${job.location}\n${job.applicantCount} applicants  |  ${job.isFullTime ? 'Full-time' : 'Part-time'}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Remove job post',
                              onPressed: () => _deleteJob(job),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
