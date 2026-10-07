class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  static DateTime _parseTimestamp(Object? value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final milliseconds = int.tryParse(value);
      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
      return DateTime.now();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final timestampValue =
        json['timestamp'] ?? json['created_at'] ?? json['createdAt'];
    final conversationId =
        (json['conversationId'] ?? json['conversation_id'])?.toString() ?? '';
    final senderId = (json['senderId'] ?? json['sender_id'])?.toString() ?? '';
    final senderName =
        (json['senderName'] ??
                json['sender_name_snapshot'] ??
                json['sender_name'])
            ?.toString() ??
        '';
    final receiverId =
        (json['receiverId'] ?? json['receiver_id'])?.toString() ?? '';
    final content = (json['content'] ?? json['message'])?.toString() ?? '';
    final isRead = json['isRead'] ?? json['is_read'] ?? false;

    return Message(
      id: (json['id'] ?? '').toString(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: content,
      timestamp: _parseTimestamp(timestampValue),
      isRead: isRead is bool
          ? isRead
          : bool.tryParse(isRead.toString()) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_name_snapshot': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }
}
