import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'message_provider.dart';
import 'application_provider.dart';
import 'announcement_provider.dart';
import 'job_provider.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

/// Unified notification provider that aggregates notifications from all sources:
/// - Messages (conversations)
/// - Job Applications (new/updated applications)
/// - Announcements (new announcements)
class NotificationItem {
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? targetId;
  final bool isRead;

  const NotificationItem({
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.targetId,
    this.isRead = false,
  });
}

class NotificationProvider extends ChangeNotifier {
  static const Duration _recentItemWindow = Duration(days: 7);
  static const String _storageKeyPrefix = 'notification_read_keys';

  final AuthProvider authProvider;
  final MessageProvider messageProvider;
  final ApplicationProvider applicationProvider;
  final AnnouncementProvider announcementProvider;
  final JobProvider jobProvider;
  DateTime? _lastReadAt;
  final Set<String> _readNotificationKeys = {};
  Future<void>? _loadOperation;
  bool _hasPendingReadStateChange = false;
  String? _realtimeUserId;
  bool _isSyncingRealtimeSources = false;

  NotificationProvider({
    required this.authProvider,
    required this.messageProvider,
    required this.applicationProvider,
    required this.announcementProvider,
    required this.jobProvider,
  }) {
    // Listen to changes from all providers
    authProvider.addListener(_onNotificationChange);
    messageProvider.addListener(_onNotificationChange);
    applicationProvider.addListener(_onNotificationChange);
    announcementProvider.addListener(_onNotificationChange);
    jobProvider.addListener(_onNotificationChange);

    Future.microtask(() async {
      await loadPersistedReadState();
      await _syncRealtimeSources();
    });
  }

  DateTime get _readCutoff {
    return _lastReadAt ?? DateTime.now().subtract(_recentItemWindow);
  }

  DateTime get _recentCutoff => DateTime.now().subtract(_recentItemWindow);

  String _notificationKey(NotificationItem item) {
    return '${item.type}|${item.title}|${item.message}|${item.timestamp.toIso8601String()}';
  }

  String get _storageKey {
    final userId = authProvider.currentUser?.id ?? 'guest';
    return '$_storageKeyPrefix|$userId';
  }

  Future<void> saveReadState() async {
    final prefs = await SharedPreferences.getInstance();
    final values = _readNotificationKeys.toList()..sort();
    await prefs.setStringList(_storageKey, values);
    if (_lastReadAt != null) {
      await prefs.setString(
        '${_storageKey}_last_read',
        _lastReadAt!.toIso8601String(),
      );
    } else {
      await prefs.remove('${_storageKey}_last_read');
    }

    // Also sync to Supabase if user is logged in
    final userId = authProvider.currentUser?.id;
    if (userId != null &&
        _lastReadAt != null &&
        SupabaseService().isInitialized) {
      try {
        await SupabaseService().saveNotificationReadState(
          userId: userId,
          readKeys: values,
          lastReadAt: _lastReadAt!,
        );
      } catch (e) {
        // Fail silently; local cache is sufficient
        debugPrint('Failed to sync read state to Supabase: $e');
      }
    }
  }

  Future<void> loadPersistedReadState() async {
    final existingLoad = _loadOperation;
    if (existingLoad != null) return existingLoad;

    final operation = _loadPersistedReadState();
    _loadOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadOperation, operation)) {
        _loadOperation = null;
      }
    }
  }

  Future<void> _loadPersistedReadState() async {
    final userId = authProvider.currentUser?.id;

    if (userId != null && SupabaseService().isInitialized) {
      try {
        final supabaseData = await SupabaseService().loadNotificationReadState(
          userId,
        );
        if (supabaseData != null) {
          final keys =
              (supabaseData['read_keys'] as List<dynamic>?)?.cast<String>() ??
              [];
          final lastReadStr = supabaseData['last_read_at'] as String?;

          _readNotificationKeys
            ..clear()
            ..addAll(keys);
          _lastReadAt = lastReadStr != null
              ? DateTime.tryParse(lastReadStr)
              : null;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint(
          'Failed to load from Supabase, falling back to local storage: $e',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final storedKeys = prefs.getStringList(_storageKey) ?? const [];
    if (_hasPendingReadStateChange) return;
    _readNotificationKeys
      ..clear()
      ..addAll(storedKeys);

    final storedLastRead = prefs.getString('${_storageKey}_last_read');
    _lastReadAt = storedLastRead != null
        ? DateTime.tryParse(storedLastRead)
        : null;
    notifyListeners();
  }

  void markAllAsRead() {
    _hasPendingReadStateChange = true;
    _lastReadAt = DateTime.now();
    _readNotificationKeys.clear();
    for (final item in notificationItems) {
      _readNotificationKeys.add(_notificationKey(item));
    }
    saveReadState();
    notifyListeners();
  }

  bool isRead(NotificationItem item) {
    return _readNotificationKeys.contains(_notificationKey(item)) ||
        (_lastReadAt != null && !item.timestamp.isAfter(_lastReadAt!));
  }

  void _onNotificationChange() {
    notifyListeners();
    final userId = authProvider.currentUser?.id;
    if (userId != null && userId != _realtimeUserId) {
      _syncRealtimeSources();
    }
  }

  Future<void> _syncRealtimeSources() async {
    final user = authProvider.currentUser;
    if (user == null ||
        _isSyncingRealtimeSources ||
        user.id == _realtimeUserId) {
      return;
    }

    _isSyncingRealtimeSources = true;
    _realtimeUserId = user.id;
    try {
      await Future.wait([
        messageProvider.loadConversations(user.id),
        announcementProvider.fetchAnnouncements(role: user.role),
      ]);
    } finally {
      _isSyncingRealtimeSources = false;
      notifyListeners();
    }
  }

  /// Count only recent conversations that have a fresh incoming message.
  /// This prevents the bell from showing every historical conversation as unread.
  int get unreadMessagesCount {
    final cutoff = _readCutoff;
    return messageProvider.conversations
        .where(
          (conversation) =>
              conversation.lastMessageTimestamp != null &&
              conversation.lastMessageTimestamp!.isAfter(cutoff) &&
              conversation.lastMessage != null &&
              conversation.lastMessage!.trim().isNotEmpty,
        )
        .length;
  }

  /// Get new applications count (for employers showing "new" status)
  int get newApplicationsCount {
    if (authProvider.currentUser?.role != AppConstants.roleEmployer) {
      return 0;
    }
    final cutoff = _readCutoff;
    return applicationProvider.applications
        .where(
          (app) =>
              app.status == AppConstants.statusNew &&
              app.appliedDate.isAfter(cutoff),
        )
        .length;
  }

  /// Get status update count (for job seekers with status changes)
  int get applicationStatusUpdatesCount {
    if (authProvider.currentUser?.role != AppConstants.roleJobSeeker) {
      return 0;
    }
    final cutoff = _readCutoff;
    return applicationProvider.applications
        .where(
          (app) =>
              (app.status == AppConstants.statusShortlisted ||
                  app.status == AppConstants.statusAccepted ||
                  app.status == AppConstants.statusRejected) &&
              (app.reviewedDate ?? app.appliedDate).isAfter(cutoff),
        )
        .length;
  }

  /// Count announcements published in the recent activity window.
  int get newAnnouncementsCount {
    final cutoff = _readCutoff;
    return announcementProvider.announcements
        .where((announcement) => announcement.publishDate.isAfter(cutoff))
        .length;
  }

  /// Count newly posted jobs published in the recent activity window.
  int get newJobsCount {
    final userRole = authProvider.currentUser?.role;
    if (userRole == AppConstants.roleJobSeeker ||
        userRole == AppConstants.roleAdmin) {
      final cutoff = _readCutoff;
      return jobProvider.jobs
          .where((job) => job.postedDate.isAfter(cutoff))
          .length;
    }
    return 0;
  }

  /// Get total notification count based on user role
  int get totalNotificationCount {
    final userRole = authProvider.currentUser?.role;
    int total = unreadMessagesCount + newAnnouncementsCount + newJobsCount;

    if (userRole == AppConstants.roleEmployer) {
      total += newApplicationsCount;
    } else if (userRole == AppConstants.roleJobSeeker) {
      total += applicationStatusUpdatesCount;
    } else if (userRole == AppConstants.roleAdmin) {
      total += applicationProvider.applications.length;
    }

    return total;
  }

  /// Get notification details for badge display
  String getNotificationBadgeText() {
    final total = totalNotificationCount;
    if (total == 0) return '';
    if (total > 99) return '99+';
    return total.toString();
  }

  /// Check if there are any notifications
  bool get hasNotifications => totalNotificationCount > 0;

  List<NotificationItem> get notificationItems {
    // Read state changes badge counts, but should not make recent activity
    // disappear from the notification center.
    final cutoff = _recentCutoff;
    final items = <NotificationItem>[];

    if (authProvider.currentUser == null) {
      return items;
    }

    for (final conversation in messageProvider.conversations) {
      if (conversation.lastMessageTimestamp != null &&
          conversation.lastMessageTimestamp!.isAfter(cutoff) &&
          conversation.lastMessage != null &&
          conversation.lastMessage!.trim().isNotEmpty) {
        items.add(
          NotificationItem(
            type: 'message',
            title: 'New message',
            message: conversation.lastMessage!,
            timestamp: conversation.lastMessageTimestamp!,
            targetId: conversation.id,
            isRead: isRead(
              NotificationItem(
                type: 'message',
                title: 'New message',
                message: conversation.lastMessage!,
                timestamp: conversation.lastMessageTimestamp!,
              ),
            ),
          ),
        );
      }
    }

    for (final announcement in announcementProvider.announcements) {
      if (announcement.publishDate.isAfter(cutoff)) {
        items.add(
          NotificationItem(
            type: 'announcement',
            title: announcement.title,
            message: announcement.description,
            timestamp: announcement.publishDate,
            targetId: announcement.id,
            isRead: isRead(
              NotificationItem(
                type: 'announcement',
                title: announcement.title,
                message: announcement.description,
                timestamp: announcement.publishDate,
              ),
            ),
          ),
        );
      }
    }

    for (final job in jobProvider.jobs) {
      if ((authProvider.currentUser?.role == AppConstants.roleJobSeeker ||
              authProvider.currentUser?.role == AppConstants.roleAdmin) &&
          job.postedDate.isAfter(cutoff)) {
        items.add(
          NotificationItem(
            type: 'job',
            title: 'New job posted',
            message: job.title,
            timestamp: job.postedDate,
            targetId: job.id,
            isRead: isRead(
              NotificationItem(
                type: 'job',
                title: 'New job posted',
                message: job.title,
                timestamp: job.postedDate,
              ),
            ),
          ),
        );
      }
    }

    for (final app in applicationProvider.applications) {
      if (authProvider.currentUser?.role == AppConstants.roleEmployer &&
          app.status == AppConstants.statusNew &&
          app.appliedDate.isAfter(cutoff)) {
        items.add(
          NotificationItem(
            type: 'application',
            title: 'New application',
            message: '${app.jobSeekerName} applied for ${app.jobTitle}',
            timestamp: app.appliedDate,
            targetId: app.id,
            isRead: isRead(
              NotificationItem(
                type: 'application',
                title: 'New application',
                message: '${app.jobSeekerName} applied for ${app.jobTitle}',
                timestamp: app.appliedDate,
              ),
            ),
          ),
        );
      }

      if (authProvider.currentUser?.role == AppConstants.roleJobSeeker &&
          (app.status == AppConstants.statusShortlisted ||
              app.status == AppConstants.statusAccepted ||
              app.status == AppConstants.statusRejected) &&
          (app.reviewedDate ?? app.appliedDate).isAfter(cutoff)) {
        final statusTimestamp = app.reviewedDate ?? app.appliedDate;
        items.add(
          NotificationItem(
            type: 'application',
            title: 'Application update',
            message: '${app.jobTitle} status: ${app.status}',
            timestamp: statusTimestamp,
            targetId: app.id,
            isRead: isRead(
              NotificationItem(
                type: 'application',
                title: 'Application update',
                message: '${app.jobTitle} status: ${app.status}',
                timestamp: statusTimestamp,
              ),
            ),
          ),
        );
      }
    }

    items.sort((a, b) {
      final unreadOrder = a.isRead == b.isRead ? 0 : (a.isRead ? 1 : -1);
      if (unreadOrder != 0) return unreadOrder;
      return b.timestamp.compareTo(a.timestamp);
    });
    return items;
  }

  @override
  void dispose() {
    authProvider.removeListener(_onNotificationChange);
    messageProvider.removeListener(_onNotificationChange);
    applicationProvider.removeListener(_onNotificationChange);
    announcementProvider.removeListener(_onNotificationChange);
    jobProvider.removeListener(_onNotificationChange);
    super.dispose();
  }
}
