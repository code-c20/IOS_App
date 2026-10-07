import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
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

    if (text.contains('invalid login credentials') ||
        text.contains('invalid_grant') ||
        text.contains('email not confirmed') ||
        text.contains('email_not_confirmed')) {
      return 'Check your email and password, then try again.';
    }

    if (error is StateError) {
      return error.message;
    }
    if (error is FormatException) return error.message.toString();

    if (text.contains('authapiexception') || text.contains('auth')) {
      return 'Sign-in failed. Please try again.';
    }

    if (text.contains('postgrest') ||
        text.contains('postgres') ||
        text.contains('row-level security') ||
        text.contains('row level security')) {
      return 'Your account profile could not be loaded: $error';
    }

    return 'Something went wrong. Please try again.';
  }

  static String formatSignupError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('failed host lookup') ||
        text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('failed to connect')) {
      return 'Unable to connect to the service. Please check your internet connection and try again.';
    }

    if (error is TimeoutException || text.contains('timeoutexception')) {
      return 'The request took too long. Please try again.';
    }

    if (text.contains('user already registered') ||
        text.contains('already registered') ||
        text.contains('already exists') ||
        text.contains('email_exists')) {
      return 'This email is already registered. Try signing in.';
    }

    if (text.contains('invalid email') ||
        text.contains('email_address_invalid')) {
      return 'Enter a valid email address.';
    }

    if (text.contains('password') &&
        (text.contains('weak') ||
            text.contains('short') ||
            text.contains('at least'))) {
      return 'Use a password with at least 6 characters.';
    }

    if (text.contains('rate limit') || text.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }

    if (text.contains('redirect') ||
        text.contains('not allowed') ||
        text.contains('url configuration')) {
      return 'Email verification is not configured for this app yet. Add worknest://email-verified to Supabase Redirect URLs, then try again.';
    }

    if (text.contains('postgrest') ||
        text.contains('postgres') ||
        text.contains('row-level security')) {
      return 'Account setup failed: $error';
    }

    if (text.contains('row level security') || text.contains('permission')) {
      return 'You do not have permission to create this account.';
    }

    return 'Check your details and try again.';
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  /// Login user with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _supabaseService.login(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final status = await _supabaseService.getUserAccountStatusByEmail(
          email,
        );
        _error = switch (status) {
          'suspended' => 'This account is suspended. Please contact support.',
          'deleted' => 'This account has been deleted.',
          _ => 'Login failed. Please check your credentials.',
        };
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on supabase.AuthApiException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('email not confirmed') ||
          message.contains('email_not_confirmed')) {
        _error = 'Please confirm your email before signing in.';
      } else {
        _error = formatErrorForUI(e);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on StateError catch (e) {
      _error = formatErrorForUI(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = formatErrorForUI(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign up new user
  Future<bool> signup(
    String name,
    String email,
    String password,
    String role,
  ) async {
    if (role == AppConstants.roleAdmin) {
      _error =
          'Admin accounts can only be created by an authorized administrator.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _supabaseService
          .signUp(email: email, password: password, name: name, role: role)
          .timeout(const Duration(seconds: 30));

      if (user != null) {
        // A successful signup can legitimately return without a session when email
        // confirmation is required. In that case, the user is not logged in and
        // should not be treated as an authenticated app user.
        _currentUser = user.hasSession ? user.user : null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Sign up failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on supabase.AuthApiException catch (e) {
      _error = formatSignupError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } on StateError catch (e) {
      _error = formatSignupError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = formatSignupError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendSignupConfirmation(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.resendSignupConfirmation(email: email);
      return true;
    } catch (e) {
      _error = formatSignupError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _supabaseService.logout();
      _currentUser = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
    }
  }

  /// Load stored user session
  Future<void> loadStoredUser() async {
    try {
      if (_supabaseService.isAuthenticated()) {
        final user = await _supabaseService.getCurrentUser();
        if (user != null) {
          _currentUser = user.accountStatus == 'deleted' ? null : user;
        }
      }
    } catch (e) {
      _error = formatErrorForUI(e);
    }
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_currentUser == null) return false;

    try {
      final success = await _supabaseService.updateUserProfile(
        userId: _currentUser!.id,
        data: data,
      );

      if (success) {
        // Update local user object
        _currentUser = _currentUser!.copyWith(data);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Upload and set profile avatar image
  Future<bool> uploadProfileImage(File file) async {
    if (_currentUser == null) return false;

    try {
      final url = await _supabaseService.uploadProfileImage(
        userId: _currentUser!.id,
        file: file,
      );

      if (url != null) {
        _currentUser = _currentUser!.copyWith({
          'profile_image': url,
          'profileImage': url,
        });
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Upload and set the resume image
  Future<bool> uploadResumeImage(File file) async {
    if (_currentUser == null) return false;

    try {
      final url = await _supabaseService.uploadResumeImage(
        userId: _currentUser!.id,
        file: file,
      );
      if (url == null) return false;

      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      _currentUser = _currentUser!.copyWith({
        'resume_image_file_name': fileName,
        'resume_image_url': url,
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Delete the current user's resume image.
  Future<bool> deleteResumeImage() async {
    if (_currentUser == null) return false;

    try {
      final success = await _supabaseService.deleteResumeImage(
        userId: _currentUser!.id,
        url: _currentUser!.resumeImageUrl ?? _currentUser!.resumeUrl,
      );
      if (!success) return false;

      _currentUser = _currentUser!.copyWith({
        'resume_image_file_name': null,
        'resume_image_url': null,
        'resume_file_name': null,
        'resume_url': null,
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  /// Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    try {
      final success = await _supabaseService.requestPasswordReset(email: email);
      return success;
    } catch (e) {
      _error = formatErrorForUI(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final success = await _supabaseService.updatePassword(password: password);
    _isLoading = false;
    if (!success) {
      _error =
          'Unable to update your password. Please request a new reset link.';
    }
    notifyListeners();
    return success;
  }
}

/// Extension to support copyWith for UserModel (if not already in model)
extension UserCopyWith on UserModel {
  UserModel copyWith(Map<String, dynamic> data) {
    return UserModel(
      id: id,
      name: data['name'] ?? name,
      email: data['email'] ?? email,
      role: data['role'] ?? role,
      accountStatus:
          data['account_status'] ?? data['accountStatus'] ?? accountStatus,
      phone: data['phone'] ?? phone,
      location: data['location'] ?? location,
      companyName: data['company_name'] ?? companyName,
      companyDescription:
          data['company_description'] ?? companyDescription,
      profileImage:
          data['profileImage'] ?? data['profile_image'] ?? profileImage,
      bio: data['bio'] ?? bio,
      resumeFileName: data.containsKey('resumeFileName')
          ? data['resumeFileName'] as String?
          : data.containsKey('resume_file_name')
          ? data['resume_file_name'] as String?
          : resumeFileName,
      resumeUrl: data.containsKey('resumeUrl')
          ? data['resumeUrl'] as String?
          : data.containsKey('resume_url')
          ? data['resume_url'] as String?
          : resumeUrl,
      resumeImageFileName: data.containsKey('resumeImageFileName')
          ? data['resumeImageFileName'] as String?
          : data.containsKey('resume_image_file_name')
          ? data['resume_image_file_name'] as String?
          : resumeImageFileName,
      resumeImageUrl: data.containsKey('resumeImageUrl')
          ? data['resumeImageUrl'] as String?
          : data.containsKey('resume_image_url')
          ? data['resume_image_url'] as String?
          : resumeImageUrl,
      skills: data['skills'] ?? skills,
      workExperience:
          data['workExperience'] ?? data['work_experience'] ?? workExperience,
      education: data['education'] ?? education,
      createdAt: createdAt,
    );
  }
}
