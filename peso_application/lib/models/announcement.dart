class Announcement {
  final String id;
  final String? createdBy;
  final String title;
  final String category; // Job Fair, System Maintenance, New Feature, etc.
  final String description;
  final String imagePath;
  final DateTime publishDate;
  final List<String> targetRoles; // which user roles should see this

  Announcement({
    required this.id,
    this.createdBy,
    required this.title,
    required this.category,
    required this.description,
    required this.imagePath,
    required this.publishDate,
    required this.targetRoles,
  });

  bool isVisibleTo(String? role) {
    if (role == null || role.trim().isEmpty) {
      return true;
    }

    final normalizedRole = role.toLowerCase();

    if (targetRoles.isEmpty) {
      return true;
    }

    final normalizedTargets = targetRoles
        .map((target) => target.toLowerCase())
        .toSet();

    final isAllTarget =
        normalizedTargets.contains('all') ||
        normalizedTargets.contains('all_accounts') ||
        normalizedTargets.contains('all_roles');

    return isAllTarget || normalizedTargets.contains(normalizedRole);
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final publishDateRaw = json['publish_date'] ?? json['publishDate'];
    final targetRolesRaw = json['target_roles'] ?? json['targetRoles'];

    return Announcement(
      id: (json['id'] as String?) ?? json['id']?.toString() ?? '',
      createdBy: json['created_by'] as String? ?? json['createdBy'] as String?,
      title: (json['title'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      imagePath: (json['image_path'] ?? json['imagePath'] ?? '') as String,
      publishDate: publishDateRaw is DateTime
          ? publishDateRaw
          : DateTime.parse(publishDateRaw as String),
      targetRoles: List<String>.from(targetRolesRaw as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (createdBy != null) 'created_by': createdBy,
      'title': title,
      'category': category,
      'description': description,
      'image_path': imagePath,
      'publish_date': publishDate.toIso8601String(),
      'target_roles': targetRoles,
    };
  }
}
