import 'package:uuid/uuid.dart';

class Job {
  final String id;
  final String title;
  final String category; // Office Assistant, Marketing Assistant, etc.
  final String description;
  final String employerName;
  final String employerId;
  final String? adminId;
  final String? employerProfileImage;
  final String location;
  final String salary;
  final bool isFullTime;
  final List<String> requirements;
  final int applicantCount;
  final DateTime postedDate;
  final DateTime deadline;

  Job({
    String? id,
    required this.title,
    required this.category,
    required this.description,
    required this.employerName,
    required this.employerId,
    this.adminId,
    this.employerProfileImage,
    required this.location,
    required this.salary,
    required this.isFullTime,
    required this.requirements,
    required this.applicantCount,
    required this.postedDate,
    required this.deadline,
  }) : id = id ?? const Uuid().v4();

  factory Job.fromJson(Map<String, dynamic> json) {
    final postedDateRaw = json['posted_date'] ?? json['postedDate'];
    final deadlineRaw = json['deadline'];

    return Job(
      id: json['id'] as String?,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      employerName:
          (json['employer_name'] ??
                  json['employerName'] ??
                  (json['employer'] as Map<String, dynamic>?)?['name'])
              as String? ??
          '',
      employerId:
          (json['employer_user_id'] ??
                  json['employer_id'] ??
                  json['employerId'])
              as String? ??
          '',
      adminId: (json['admin_id'] ?? json['adminId']) as String?,
      employerProfileImage:
          (json['employer_profile_image'] ?? json['employerProfileImage'])
              as String?,
      location: json['location'] as String,
      salary: json['salary'] as String,
      isFullTime: (json['is_full_time'] ?? json['isFullTime']) as bool? ?? true,
      requirements: List<String>.from(
        (json['requirements'] ?? []) as List? ?? [],
      ),
      applicantCount:
          (json['applicant_count'] ?? json['applicantCount']) as int? ?? 0,
      postedDate: postedDateRaw == null
          ? DateTime.now()
          : DateTime.parse(postedDateRaw as String),
      deadline: deadlineRaw == null
          ? DateTime.now()
          : DateTime.parse(deadlineRaw as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'employer_id': employerId,
      'admin_id': adminId,
      'location': location,
      'salary': salary,
      'is_full_time': isFullTime,
      'requirements': requirements,
      'posted_date': postedDate.toIso8601String(),
      'deadline': deadline.toIso8601String(),
    };
  }

  Job copyWith({String? employerProfileImage}) {
    return Job(
      id: id,
      title: title,
      category: category,
      description: description,
      employerName: employerName,
      employerId: employerId,
      adminId: adminId,
      employerProfileImage: employerProfileImage ?? this.employerProfileImage,
      location: location,
      salary: salary,
      isFullTime: isFullTime,
      requirements: requirements,
      applicantCount: applicantCount,
      postedDate: postedDate,
      deadline: deadline,
    );
  }
}
