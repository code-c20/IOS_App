import 'package:flutter/material.dart';
import '../models/job.dart';
import '../utils/constants.dart';
import 'user_avatar.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final VoidCallback? onSavePressed;
  final bool isSaved;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.onSavePressed,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(AppConstants.primaryColor);
    final mutedColor = Colors.blueGrey.shade600;
    final daysLeft = job.deadline.difference(DateTime.now()).inDays;
    final deadlineLabel = daysLeft < 0
        ? 'Closed'
        : daysLeft == 0
            ? 'Closes today'
            : 'Closes in $daysLeft days';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    name: job.employerName,
                    imageUrl: job.employerProfileImage,
                    radius: 23,
                    backgroundColor: primaryColor.withAlpha(22),
                    foregroundColor: primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.business_outlined, size: 15, color: mutedColor),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                job.employerName,
                                style: TextStyle(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onSavePressed != null)
                    IconButton(
                      tooltip: isSaved ? 'Remove saved job' : 'Save job',
                      onPressed: onSavePressed,
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: primaryColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _JobBadge(
                    icon: Icons.work_outline,
                    label: job.isFullTime ? 'Full-time' : 'Part-time',
                    color: primaryColor,
                  ),
                  _JobBadge(
                    icon: Icons.category_outlined,
                    label: job.category,
                    color: Colors.indigo.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                job.description,
                style: TextStyle(color: Colors.blueGrey.shade700, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.blueGrey.shade100),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _JobMeta(
                      icon: Icons.location_on_outlined,
                      label: job.location,
                    ),
                  ),
                  Expanded(
                    child: _JobMeta(
                      icon: Icons.people_outline,
                      label: '${job.applicantCount} applicants',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.salary,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    deadlineLabel,
                    style: TextStyle(
                      color: daysLeft <= 3 ? Colors.deepOrange.shade700 : mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
}

class _JobBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _JobBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _JobMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _JobMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.blueGrey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
