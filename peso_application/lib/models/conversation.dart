import '../utils/constants.dart';

class Conversation {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String? participant1Name;
  final String? participant2Name;
  final String? participant1Role;
  final String? participant2Role;
  final String? participant1ProfileImage;
  final String? participant2ProfileImage;
  final String? lastMessage;
  final DateTime? lastMessageTimestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.participant1Name,
    this.participant2Name,
    this.participant1Role,
    this.participant2Role,
    this.participant1ProfileImage,
    this.participant2ProfileImage,
    this.lastMessage,
    this.lastMessageTimestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['created_at'] ?? json['createdAt'];
    final updatedAtValue = json['updated_at'] ?? json['updatedAt'];
    final lastMessageTimestampValue =
        json['last_message_timestamp'] ?? json['lastMessageTimestamp'];

    return Conversation(
      id: json['id'] as String,
      participant1Id: json['participant1_id'] as String,
      participant2Id: json['participant2_id'] as String,
      participant1Name:
          json['participant1_name'] as String? ??
          json['participant1Name'] as String?,
      participant2Name:
          json['participant2_name'] as String? ??
          json['participant2Name'] as String?,
      participant1Role:
          json['participant1_role'] as String? ??
          json['participant1Role'] as String?,
      participant2Role:
          json['participant2_role'] as String? ??
          json['participant2Role'] as String?,
        participant1ProfileImage: json['participant1_profile_image'] as String? ??
          json['participant1ProfileImage'] as String?,
        participant2ProfileImage: json['participant2_profile_image'] as String? ??
          json['participant2ProfileImage'] as String?,
      lastMessage:
          json['last_message'] as String? ?? json['lastMessage'] as String?,
      lastMessageTimestamp: lastMessageTimestampValue == null
          ? null
          : DateTime.parse(lastMessageTimestampValue as String),
      createdAt: createdAtValue == null
          ? DateTime.now()
          : DateTime.parse(createdAtValue as String),
      updatedAt: updatedAtValue == null
          ? DateTime.now()
          : DateTime.parse(updatedAtValue as String),
    );
  }

  Conversation copyWith({
    String? participant1Name,
    String? participant2Name,
    String? participant1Role,
    String? participant2Role,
    String? participant1ProfileImage,
    String? participant2ProfileImage,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
  }) {
    return Conversation(
      id: id,
      participant1Id: participant1Id,
      participant2Id: participant2Id,
      participant1Name: participant1Name ?? this.participant1Name,
      participant2Name: participant2Name ?? this.participant2Name,
      participant1Role: participant1Role ?? this.participant1Role,
      participant2Role: participant2Role ?? this.participant2Role,
        participant1ProfileImage:
          participant1ProfileImage ?? this.participant1ProfileImage,
        participant2ProfileImage:
          participant2ProfileImage ?? this.participant2ProfileImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String otherParticipantId(String currentUserId) {
    return participant1Id == currentUserId ? participant2Id : participant1Id;
  }

  String otherParticipantName(String currentUserId) {
    if (participant1Id == currentUserId) {
      return participant2Name?.trim().isNotEmpty == true
          ? participant2Name!
          : 'Unknown User';
    }
    return participant1Name?.trim().isNotEmpty == true
        ? participant1Name!
        : 'Unknown User';
  }

  String? otherParticipantProfileImage(String currentUserId) {
    return participant1Id == currentUserId
        ? participant2ProfileImage
        : participant1ProfileImage;
  }

  String otherParticipantRole(String currentUserId) {
    if (participant1Id == currentUserId) {
      return participant2Role ?? 'unknown';
    }
    return participant1Role ?? 'unknown';
  }

  String typeForRole(String currentUserRole, String currentUserId) {
    final otherRole = otherParticipantRole(currentUserId);
    if (otherRole == AppConstants.roleAdmin) {
      return 'Admin';
    }

    switch (currentUserRole) {
      case AppConstants.roleEmployer:
        return otherRole == AppConstants.roleJobSeeker
            ? 'Candidates'
            : 'Support';
      case AppConstants.roleJobSeeker:
        return otherRole == AppConstants.roleEmployer ? 'Employers' : 'Admin';
      case AppConstants.roleAdmin:
        if (otherRole == AppConstants.roleEmployer) return 'Employers';
        if (otherRole == AppConstants.roleJobSeeker) return 'Job Seekers';
        return 'Admin';
      default:
        return otherRole == AppConstants.roleEmployer
            ? 'Employers'
            : otherRole == AppConstants.roleJobSeeker
            ? 'Candidates'
            : 'Admin';
    }
  }
}
