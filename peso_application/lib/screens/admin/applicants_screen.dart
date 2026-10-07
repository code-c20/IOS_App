import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/application_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../employer/applicant_detail_screen.dart';

class AdminApplicantsScreen extends StatefulWidget {
  const AdminApplicantsScreen({super.key});

  @override
  State<AdminApplicantsScreen> createState() => _AdminApplicantsScreenState();
}

class _AdminApplicantsScreenState extends State<AdminApplicantsScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApplicationProvider>().fetchAllApplications();
    });
  }

  Future<void> _refresh() {
    return context.read<ApplicationProvider>().fetchAllApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: const Text('Applicants'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(AppConstants.primaryColor),
      ),
      body: Consumer<ApplicationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.applications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: provider.applications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Center(child: Text('No applications yet.')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: provider.applications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final application = provider.applications[index];
                      final color = _statusColor(application.status);
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final applicant = await _supabaseService
                                .getJobSeekerUserByProfileId(application.jobSeekerId);
                            if (!context.mounted || applicant == null) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ApplicantDetailScreen(
                                  applicant: applicant,
                                  application: application,
                                ),
                              ),
                            );
                            if (mounted) {
                              await _refresh();
                            }
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFEDE7F6),
                                child: Text(
                                  application.jobSeekerName.isEmpty
                                      ? '?'
                                      : application.jobSeekerName[0]
                                            .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF0F3D7A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      application.jobSeekerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      application.jobTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Applied ${_formatDate(application.appliedDate)}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _statusLabel(application.status),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
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

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Unknown';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  String _formatDate(DateTime date) {
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
}
