import 'dart:async';
import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';

class JobProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  final List<Job> _savedJobs = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;
  final SupabaseService _supabaseService = SupabaseService();

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
      return 'You do not have permission to view these jobs.';
    }

    return 'Unable to load jobs. Please try again.';
  }

  List<Job> get jobs => _jobs;
  List<Job> get savedJobs => _savedJobs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _savedJobs.clear();
    if (userId != null) unawaited(loadSavedJobs(userId));
  }

  Future<void> loadSavedJobs(String userId) async {
    try {
      final savedJobs = await _supabaseService.fetchSavedJobs(userId);
      if (_userId != userId) return;
      _savedJobs
        ..clear()
        ..addAll(savedJobs);
      notifyListeners();
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
    }
  }

  Future<void> refreshSavedJobs() async {
    final userId = _userId;
    if (userId != null) await loadSavedJobs(userId);
  }

  Future<void> refreshJob(String jobId) async {
    final updatedJob = await _supabaseService.getJobById(jobId);
    if (updatedJob == null) return;
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index == -1) return;
    _jobs[index] = updatedJob;
    notifyListeners();
  }

  /// Fetch all jobs with optional filters
  Future<void> fetchJobs({String? category, String? location}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _supabaseService.fetchJobs(
        category: category,
        location: location,
      );
      _isLoading = false;

      // Subscribe to real-time job updates
      try {
        _supabaseService.subscribeToJobs(
          onChange: (record) {
            final jobId = record['id'] as String?;
            if (jobId != null) unawaited(_refreshRealtimeJob(jobId));
          },
        );
      } catch (_) {}

      notifyListeners();
    } catch (e) {
      _error = formatErrorForUI(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshRealtimeJob(String jobId) async {
    final updatedJob = await _supabaseService.getJobById(jobId);
    if (updatedJob == null) return;
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index == -1) {
      _jobs.insert(0, updatedJob);
    } else {
      _jobs[index] = updatedJob;
    }
    notifyListeners();
  }

  /// Search jobs by title or description
  Future<void> searchJobs(String query) async {
    if (query.isEmpty) {
      await fetchJobs();
      return;
    }

    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _supabaseService.searchJobs(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = formatErrorForUI(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save job to saved list
  Future<void> saveJob(Job job) async {
    try {
      final userId = _userId;
      if (userId == null ||
          _savedJobs.any((savedJob) => savedJob.id == job.id)) {
        return;
      }
      await _supabaseService.saveJobForUser(userId, job.id);
      if (!_savedJobs.any((savedJob) => savedJob.id == job.id)) {
        _savedJobs.add(job);
        notifyListeners();
      }
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
    }
  }

  /// Remove job from saved list
  Future<void> unsaveJob(String jobId) async {
    try {
      final userId = _userId;
      if (userId == null) return;
      await _supabaseService.unsaveJobForUser(userId, jobId);
      _savedJobs.removeWhere((j) => j.id == jobId);
      notifyListeners();
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
    }
  }

  /// Check if job is saved
  bool isJobSaved(String jobId) {
    return _savedJobs.any((j) => j.id == jobId);
  }

  /// Get single job by ID
  Future<Job?> getJobById(String jobId) async {
    try {
      return await _supabaseService.getJobById(jobId);
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return null;
    }
  }

  /// Create a new job posting
  Future<bool> createJob(Job job) async {
    try {
      _error = null;
      final success = await _supabaseService.createJob(job);
      if (success) {
        _jobs.insert(0, job);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e is StateError ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a job posting
  Future<bool> deleteJob(String jobId) async {
    try {
      final success = await _supabaseService.deleteJob(jobId);
      if (success) {
        _jobs.removeWhere((job) => job.id == jobId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }
}
