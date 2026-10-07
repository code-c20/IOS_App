class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String jobSeekerId;
  final String jobSeekerName;
  final String status; // new, shortlisted, pending, rejected, accepted
  final String? coverLetter;
  final DateTime? interviewDate;
  final DateTime appliedDate;
  final DateTime? reviewedDate;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.jobSeekerId,
    required this.jobSeekerName,
    required this.status,
    this.coverLetter,
    required this.appliedDate,
    this.reviewedDate,
    this.interviewDate,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as String,
      jobId: (json['job_id'] ?? json['jobId']) as String,
      jobTitle:
          (json['job_title_snapshot'] ?? json['job_title'] ?? json['jobTitle'])
              as String? ??
          '',
      jobSeekerId: (json['job_seeker_id'] ?? json['jobSeekerId']) as String,
      jobSeekerName:
          (json['job_seeker_name_snapshot'] ??
                  json['job_seeker_name'] ??
                  json['jobSeekerName'])
              as String? ??
          '',
      status: json['status'] as String,
      coverLetter: (json['cover_letter'] ?? json['coverLetter']) as String?,
      appliedDate: DateTime.parse(
        (json['applied_date'] ?? json['appliedDate']) as String,
      ),
      reviewedDate: (json['reviewed_date'] ?? json['reviewedDate']) != null
          ? DateTime.parse(
              (json['reviewed_date'] ?? json['reviewedDate']) as String,
            )
          : null,
      interviewDate: (json['interview_date'] ?? json['interviewDate']) != null
          ? DateTime.parse(
              (json['interview_date'] ?? json['interviewDate']) as String,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'job_title_snapshot': jobTitle,
      'job_seeker_id': jobSeekerId,
      'job_seeker_name_snapshot': jobSeekerName,
      'status': status,
      'cover_letter': coverLetter,
      'applied_date': appliedDate.toIso8601String(),
      'reviewed_date': reviewedDate?.toIso8601String(),
      'interview_date': interviewDate?.toIso8601String(),
    };
  }

  JobApplication copyWith({String? status, DateTime? interviewDate}) {
    return JobApplication(
      id: id,
      jobId: jobId,
      jobTitle: jobTitle,
      jobSeekerId: jobSeekerId,
      jobSeekerName: jobSeekerName,
      status: status ?? this.status,
      coverLetter: coverLetter,
      appliedDate: appliedDate,
      reviewedDate: reviewedDate,
      interviewDate: interviewDate ?? this.interviewDate,
    );
  }
}
