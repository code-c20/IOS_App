import 'package:flutter/material.dart';
import '../models/application.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class ApplicationProvider extends ChangeNotifier {
  List<JobApplication> _applications = [];
  bool _isLoading = false;
  String? _error;
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

    if (text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('rls') ||
        text.contains('policy')) {
      return 'Your account is not allowed to submit this application.';
    }

    if (text.contains('duplicate') || text.contains('already applied')) {
      return 'You have already applied for this job.';
    }

    if (text.contains('uuid') ||
        text.contains('invalid input syntax') ||
        text.contains('insert')) {
      return 'The job application could not be submitted. Please try again.';
    }

    return 'Unable to submit application. Please try again.';
  }

  List<JobApplication> get applications => _applications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch applications for job seeker
  Future<void> fetchApplications(String userId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _applications = await _supabaseService.getJobSeekerApplications(userId);
      _isLoading = false;

      try {
        _supabaseService.subscribeToApplications(
          userId: userId,
          role: AppConstants.roleJobSeeker,
          onChange: (record) {
            try {
              final updatedApp = JobApplication.fromJson(record);
              final index = _applications.indexWhere(
                (a) => a.id == updatedApp.id,
              );
              if (index != -1) {
                _applications[index] = updatedApp;
              } else {
                _applications.insert(0, updatedApp);
              }
              notifyListeners();
            } catch (_) {}
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

  /// Fetch applications received by employer
  Future<void> fetchEmployerApplications(String employerId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _applications = await _supabaseService.getEmployerApplications(
        employerId,
      );
      _isLoading = false;

      // subscribe to realtime updates for this employer so UI updates automatically
      try {
        _supabaseService.subscribeToApplications(
          userId: employerId,
          role: AppConstants.roleEmployer,
          onChange: (record) {
            try {
              final updatedApp = JobApplication.fromJson(record);
              final index = _applications.indexWhere(
                (a) => a.id == updatedApp.id,
              );
              if (index != -1) {
                _applications[index] = updatedApp;
              } else {
                _applications.insert(0, updatedApp);
              }
              notifyListeners();
            } catch (_) {}
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

  /// Fetch every application for administrator views.
  Future<void> fetchAllApplications() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _applications = await _supabaseService.fetchApplications();
    } catch (e) {
      _error = formatErrorForUI(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply for a job
  Future<bool> applyForJob(JobApplication application) async {
    try {
      final success = await _supabaseService.applyForJob(application);
      if (success) {
        _applications.add(application);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Check whether the logged-in job seeker has already applied for a job.
  bool hasApplied(String jobId, String userId) {
    return _applications.any(
      (app) => app.jobId == jobId && app.jobSeekerId == userId,
    );
  }

  /// Update application status (employer only)
  Future<bool> updateApplicationStatus({
    required String applicationId,
    required String status,
    DateTime? interviewDate,
  }) async {
    try {
      final success = await _supabaseService.updateApplicationStatus(
        applicationId: applicationId,
        status: status,
        interviewDate: interviewDate,
      );

      if (success) {
        // Update local application
        final index = _applications.indexWhere(
          (app) => app.id == applicationId,
        );
        if (index != -1) {
          _applications[index] = _applications[index].copyWith(
            status: status,
            interviewDate: interviewDate,
          );
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Get count of applications by status
  int getStatusCount(String status) {
    return _applications.where((app) => app.status == status).length;
  }

  /// Get applications filtered by status
  List<JobApplication> getApplicationsByStatus(String status) {
    return _applications.where((app) => app.status == status).toList();
  }
}

/// Extension to support copyWith for JobApplication
extension JobApplicationCopyWith on JobApplication {
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
