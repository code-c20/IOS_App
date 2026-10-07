import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/application.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../widgets/branded_app_bar.dart';
import 'applicant_detail_screen.dart';
import 'widgets.dart';
import 'package:peso_application/utils/app_feedback.dart';

class EmployerApplicantsScreen extends StatefulWidget {
  const EmployerApplicantsScreen({super.key});

  @override
  State<EmployerApplicantsScreen> createState() =>
      _EmployerApplicantsScreenState();
}

class _EmployerApplicantsScreenState extends State<EmployerApplicantsScreen> {
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  static const List<String> _statusTabs = [
    'All',
    'New',
    'Shortlisted',
    'Hired',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        setState(() => _isLoading = true);
        context
            .read<ApplicationProvider>()
            .fetchEmployerApplications(currentUser.id)
            .whenComplete(() {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshApplicants() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      setState(() => _isLoading = true);
      await context
          .read<ApplicationProvider>()
          .fetchEmployerApplications(currentUser.id)
          .whenComplete(() {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          });
    }
  }

  void applyStatusFilter(String status) {
    setState(() {
      _selectedStatus = _statusTabs.contains(status)
          ? status
          : status == AppConstants.statusAccepted
          ? 'Hired'
          : status == AppConstants.statusShortlisted
          ? 'Shortlisted'
          : status == AppConstants.statusNew
          ? 'New'
          : 'All';
    });
  }

  void _openApplicantDetails(JobApplication application) async {
    final applicant = await SupabaseService()    .getJobSeekerUserByProfileId(
      application.jobSeekerId,
    );
    if (!mounted) return;

    if (applicant != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ApplicantDetailScreen(
            applicant: applicant,
            application: application,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Could not load applicant details. Try again.'),
        ),
      );
    }
  }

  void _showReportApplicantDialog(String applicantName, String applicantId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'inappropriate_content';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Report $applicantName'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please tell us why you\'re reporting this applicant.',
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
                    hintText: 'Describe the violation in detail',
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
                        reportType: 'applicant_violation',
                        subjectId: applicantId,
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
    final applicationProvider = context.watch<ApplicationProvider>();
    final applications = applicationProvider.applications;
    final selectedStatusValue = _selectedStatus == 'All'
        ? null
        : _selectedStatus == 'Hired'
        ? AppConstants.statusAccepted
        : _selectedStatus.toLowerCase();
    final filtered = applications.where((app) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery =
          _searchQuery.trim().isEmpty ||
          app.jobSeekerName.toLowerCase().contains(q) ||
          app.jobTitle.toLowerCase().contains(q) ||
          app.status.toLowerCase().contains(q);
      final matchesStatus =
          selectedStatusValue == null || app.status == selectedStatusValue;
      return matchesQuery && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(
        title: 'Applicants',
        gradientColors: [Color(AppConstants.primaryColor), Color(0xFF0A5BC7)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Recent applicants',
                subtitle: 'Review candidates who applied to your job posts.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search applicants by name, role, or status',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusTabs.map((status) {
                    final selected = _selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedStatus = status),
                        selectedColor: Theme.of(context).primaryColor,
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshApplicants,
                  child: _isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          children: const [
                            Center(child: CircularProgressIndicator()),
                          ],
                        )
                      : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          children: const [
                            EmptyState(
                              icon: Icons.people_outline,
                              title: 'No matching applicants',
                              subtitle:
                                  'Try a different search keyword or select another status to refine the list.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (itemContext, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (itemContext, index) {
                            final application = filtered[index];
                            return ApplicantCard(
                              name: application.jobSeekerName,
                              role: application.jobTitle,
                              status: application.status,
                              onTap: () => _openApplicantDetails(application),
                              onReport: () => _showReportApplicantDialog(
                                application.jobSeekerName,
                                application.jobSeekerId,
                              ),
                            );
                          },
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
