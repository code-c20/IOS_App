// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/application.dart';
import '../../providers/application_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/user_avatar.dart';
import 'package:peso_application/utils/app_feedback.dart';

class ApplicantDetailScreen extends StatefulWidget {
  final UserModel applicant;
  final JobApplication application;

  const ApplicantDetailScreen({
    super.key,
    required this.applicant,
    required this.application,
  });

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(title: const Text('Applicant details'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
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
                          name: widget.applicant.name,
                          imageUrl: widget.applicant.profileImage,
                          radius: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.applicant.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.application.jobTitle,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Email', value: widget.applicant.email),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Phone',
                      value: widget.applicant.phone ?? 'Not provided',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Location',
                      value: widget.applicant.location ?? 'Not provided',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Status', value: widget.application.status),
                    const SizedBox(height: 16),
                    if (widget.application.coverLetter != null &&
                        widget.application.coverLetter!.trim().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cover letter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.application.coverLetter!,
                            style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (widget.applicant.skills?.trim().isNotEmpty == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Skills',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.applicant.skills!,
                            style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (widget.applicant.workExperience?.trim().isNotEmpty ==
                        true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work experience',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.applicant.workExperience!,
                            style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    if (widget.applicant.education?.trim().isNotEmpty == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Education',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.applicant.education!,
                            style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    const Text(
                      'Resume',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.applicant.resumeImageUrl?.trim().isNotEmpty == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.applicant.resumeImageUrl!,
                              height: 360,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return SizedBox(
                                  height: 360,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes == null
                                          ? null
                                          : progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: Text(
                                        'Resume image could not be loaded. Check the resumes bucket policy in Supabase.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => _ResumeViewerScreen(
                                    resumeUrl: widget.applicant.resumeImageUrl!,
                                    resumeFileName:
                                        widget.applicant.resumeImageFileName ??
                                        'Resume image',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.zoom_in),
                            label: const Text('Open full screen'),
                          ),
                        ],
                      )
                    else if (widget.applicant.resumeUrl?.trim().isNotEmpty == true)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => _ResumeViewerScreen(
                                resumeUrl: widget.applicant.resumeUrl!,
                                resumeFileName:
                                    widget.applicant.resumeFileName ?? 'Resume',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('View Resume'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    else
                      Text(
                        'No resume available for this applicant.',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    const SizedBox(height: 24),
                    // Action Buttons
                    if (widget.application.status != AppConstants.statusAccepted &&
                        widget.application.status != AppConstants.statusRejected)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _acceptApplication(context),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Accept'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(AppConstants.successColor),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _rejectApplication(context),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('Reject'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(AppConstants.dangerColor),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _scheduleInterview(context),
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Schedule Interview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptApplication(BuildContext context) async {
    final appProvider = context.read<ApplicationProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Application'),
        content: const Text(
          'Are you sure you want to accept this application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.successColor),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await appProvider.updateApplicationStatus(
        applicationId: widget.application.id,
        status: AppConstants.statusAccepted,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Application accepted successfully'
                  : 'Failed to accept application',
            ),
            backgroundColor: success
                ? const Color(AppConstants.successColor)
                : const Color(AppConstants.dangerColor),
          ),
        );

        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _rejectApplication(BuildContext context) async {
    final appProvider = context.read<ApplicationProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text(
          'Are you sure you want to reject this application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.dangerColor),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await appProvider.updateApplicationStatus(
        applicationId: widget.application.id,
        status: AppConstants.statusRejected,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Application rejected successfully'
                  : 'Failed to reject application',
            ),
            backgroundColor: success
                ? const Color(AppConstants.successColor)
                : const Color(AppConstants.dangerColor),
          ),
        );

        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _scheduleInterview(BuildContext context) async {
    DateTime? selectedDate = widget.application.interviewDate;
    TimeOfDay? selectedTime = widget.application.interviewDate != null
        ? TimeOfDay.fromDateTime(widget.application.interviewDate!)
        : null;

    final appProvider = context.read<ApplicationProvider>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Interview'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select interview date and time:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    selectedDate == null
                        ? 'Select date'
                        : selectedDate!.toString().split(' ')[0],
                  ),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    selectedTime == null
                        ? 'Select time'
                        : selectedTime!.format(context),
                  ),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDate != null && selectedTime != null
                  ? () async {
                      Navigator.pop(context);
                      final interviewDateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );

                      final success = await appProvider.updateApplicationStatus(
                        applicationId: widget.application.id,
                        status: AppConstants.statusShortlisted,
                        interviewDate: interviewDateTime,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showAppSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Interview scheduled successfully'
                                  : 'Failed to schedule interview',
                            ),
                            backgroundColor: success
                                ? const Color(AppConstants.successColor)
                                : const Color(AppConstants.dangerColor),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Schedule'),
            ),
          ],
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(value, style: TextStyle(color: Colors.grey[700])),
        ),
      ],
    );
  }
}

class _ResumeViewerScreen extends StatelessWidget {
  final String resumeUrl;
  final String resumeFileName;

  const _ResumeViewerScreen({
    required this.resumeUrl,
    required this.resumeFileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(resumeFileName)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            resumeUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
