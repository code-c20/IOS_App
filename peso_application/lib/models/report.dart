import 'package:intl/intl.dart';

class Report {
  final String id;
  final String reporterId;
  final String reportType; // 'job_report', 'applicant_violation', etc.
  final String? subjectId; // job_id, applicant_id, user_id, etc.
  final String
  category; // 'inappropriate_content', 'harassment', 'fraud', 'other'
  final String title;
  final String description;
  final String status; // 'pending', 'reviewed', 'resolved', 'dismissed'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByAdminId;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportType,
    this.subjectId,
    required this.category,
    required this.title,
    required this.description,
    this.status = 'pending',
    this.adminNotes,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByAdminId,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportType: json['report_type'] as String,
      subjectId:
          (json['subject_job_id'] ??
                  json['subject_user_id'] ??
                  json['subject_id'])
              as String?,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedByAdminId: json['reviewed_by_admin_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'report_type': reportType,
      if (subjectId != null && reportType == 'job_report')
        'subject_job_id': subjectId,
      if (subjectId != null &&
          (reportType == 'applicant_violation' || reportType == 'user_report'))
        'subject_user_id': subjectId,
      'category': category,
      'title': title,
      'description': description,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by_admin_id': reviewedByAdminId,
    };
  }

  Report copyWith({
    String? id,
    String? reporterId,
    String? reportType,
    String? subjectId,
    String? category,
    String? title,
    String? description,
    String? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedByAdminId,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reportType: reportType ?? this.reportType,
      subjectId: subjectId ?? this.subjectId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedByAdminId: reviewedByAdminId ?? this.reviewedByAdminId,
    );
  }

  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(createdAt);
  }

  String get formattedTime {
    return DateFormat('hh:mm a').format(createdAt);
  }

  String get statusBadgeColor {
    switch (status) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'reviewed':
        return '#4169E1'; // Blue
      case 'resolved':
        return '#28A745'; // Green
      case 'dismissed':
        return '#6C757D'; // Gray
      default:
        return '#6C757D';
    }
  }
}
