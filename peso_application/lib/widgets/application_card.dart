import 'package:flutter/material.dart';
import '../models/application.dart';
import '../utils/constants.dart';

class ApplicationCard extends StatelessWidget {
  final JobApplication application;
  final VoidCallback onTap;

  const ApplicationCard({
    super.key,
    required this.application,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Color(AppConstants.accentColor);
      case 'shortlisted':
        return Color(AppConstants.successColor);
      case 'pending':
        return Color(AppConstants.warningColor);
      case 'accepted':
        return Color(AppConstants.successColor);
      case 'rejected':
        return Color(AppConstants.dangerColor);
      default:
        return Color(AppConstants.textLight);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'new':
        return 'New';
      case 'shortlisted':
        return 'Shortlisted';
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.jobTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Applied ${_formatDate(application.appliedDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (application.interviewDate != null) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Color(0xFFFFA500),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Interview: ${_formatInterviewDate(application.interviewDate!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFFA500),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(application.status).withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(application.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(application.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${(diff.inDays / 7).floor()} weeks ago';
    }
  }

  String _formatInterviewDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today ${_formatTime(date)}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month} ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
