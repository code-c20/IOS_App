class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // job_seeker, employer, admin
  final String accountStatus;
  final String? phone;
  final String? location;
  final String? companyName;
  final String? companyDescription;
  final String? profileImage;
  final String? bio;
  final String? resumeFileName;
  final String? resumeUrl;
  final String? resumeImageFileName;
  final String? resumeImageUrl;
  final String? skills;
  final String? workExperience;
  final String? education;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.accountStatus = 'active',
    this.phone,
    this.location,
    this.companyName,
    this.companyDescription,
    this.profileImage,
    this.bio,
    this.resumeFileName,
    this.resumeUrl,
    this.resumeImageFileName,
    this.resumeImageUrl,
    this.skills,
    this.workExperience,
    this.education,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] ?? json['createdAt'];
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] ?? json['account_type']) as String,
      accountStatus:
          (json['account_status'] ?? json['accountStatus'] ?? 'active')
              as String,
      phone: json['phone'] as String?,
      location: json['location'] as String?,
      companyName: json['company_name'] as String?,
      companyDescription: json['company_description'] as String?,
      profileImage: (json['profile_image'] ?? json['profileImage']) as String?,
      bio: json['bio'] as String?,
      resumeFileName:
          (json['resume_file_name'] ?? json['resumeFileName']) as String?,
      resumeUrl: (json['resume_url'] ?? json['resumeUrl']) as String?,
      resumeImageFileName:
          (json['resume_image_file_name'] ?? json['resumeImageFileName'])
              as String?,
      resumeImageUrl:
          (json['resume_image_url'] ?? json['resumeImageUrl']) as String?,
      skills: (json['skills'] ?? json['skill']) as String?,
      workExperience: json['work_experience'] as String?,
      education: json['education'] as String?,
      createdAt: createdAt == null
          ? DateTime.now()
          : DateTime.parse(createdAt as String),
    );
  }

  bool get isActive => accountStatus == 'active';

  bool get canSignIn => accountStatus != 'deleted';

  bool get canAccessRoleActions => accountStatus == 'active';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'account_status': accountStatus,
      'phone': phone,
      'location': location,
      'profile_image': profileImage,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
