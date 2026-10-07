import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../services/supabase_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;

  static String formatErrorForUI(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('failed to connect')) {
      return 'Unable to connect to the service. Please check your internet connection and try again.';
    }

    if (text.contains('permission denied') ||
        text.contains('row level security') ||
        text.contains('policy') ||
        text.contains('rls')) {
      return 'You do not have permission to load announcements.';
    }

    return 'Unable to load announcements. Please try again.';
  }

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Announcement? get latestAnnouncement =>
      _announcements.isEmpty ? null : _announcements.first;

  String? _role;
  bool _isSubscribed = false;

  void _ensureAnnouncementSubscription(String? role) {
    _role = role;
    if (_isSubscribed) return;

    _isSubscribed = true;
    _supabaseService.subscribeToAnnouncements(
      onChange: () {
        // Re-fetch announcements when the table changes in realtime.
        fetchAnnouncements(role: _role);
      },
    );
  }

  Future<void> fetchAnnouncements({String? role}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _announcements = await _supabaseService.getAnnouncements(role: role);
      _isLoading = false;
      notifyListeners();
      _ensureAnnouncementSubscription(role);
    } catch (e) {
      _error = formatErrorForUI(e);
      _isLoading = false;
      notifyListeners();
    }
  }
}
