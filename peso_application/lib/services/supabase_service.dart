import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/job.dart';
import '../models/application.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/announcement.dart';
import '../utils/constants.dart';

/// Supabase Service - Singleton for all database operations
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  late supabase.SupabaseClient _client;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize Supabase
  Future<void> initialize() async {
    await supabase.Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = supabase.Supabase.instance.client;
    _isInitialized = true;
  }

  supabase.SupabaseClient get client => _client;

  // ==================== AUTH OPERATIONS ====================

  /// Sign up new user
  Future<({UserModel user, bool hasSession})?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (role != AppConstants.roleJobSeeker &&
        role != AppConstants.roleEmployer) {
      throw ArgumentError.value(
        role,
        'role',
        'Public signup is available only for job seekers and employers.',
      );
    }

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb
            ? '${Uri.base.origin}/#/email-verified'
            : 'worknest://email-verified',
        data: {'name': name, 'role': role},
      );

      if (response.user != null) {
        final createdAt = DateTime.now();

        // The database trigger provisions public rows even when confirmation
        // is required and Supabase does not return a client session.
        if (response.session == null) {
          return (
            user: UserModel(
              id: response.user!.id,
              name: name,
              email: email,
              role: role,
              createdAt: createdAt,
            ),
            hasSession: false,
          );
        }

        // An Auth trigger may already have created the public profile. If the
        // database migration is not installed, create it through the existing
        // authenticated fallback instead.
        final user =
            await getUserById(response.user!.id) ??
            await _createProfileFromAuthUser(response.user!);

        return (user: user, hasSession: true);
      }
      return null;
    } catch (e) {
      // Handle signup error silently for production
      rethrow;
    }
  }

  Future<void> resendSignupConfirmation({required String email}) async {
    await _client.auth.resend(
      type: supabase.OtpType.signup,
      email: email,
      emailRedirectTo: kIsWeb
          ? '${Uri.base.origin}/#/email-verified'
          : 'worknest://email-verified',
    );
  }

  /// Create an account without changing the current administrator's session.
  Future<bool> createUserAccount({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final response = await _client.functions.invoke(
      'admin-create-user',
      body: {
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'role': role,
      },
    );
    final data = response.data;
    if (data is! Map || data['user_id'] is! String) {
      throw const FormatException(
        'The account service returned an invalid response.',
      );
    }
    return true;
  }

  /// Login user
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        try {
          final userData = await _client
              .from(SupabaseConfig.usersTable)
              .select()
              .eq('auth_user_id', response.user!.id)
              .maybeSingle();

          final user = userData == null
              ? await _createProfileFromAuthUser(response.user!)
              : UserModel.fromJson(await _withRoleProfile(userData));

          if (user.accountStatus == 'deleted') {
            await _client.auth.signOut();
            return null;
          }

          return user;
        } catch (error, stackTrace) {
          try {
            await _client.auth.signOut();
          } catch (signOutError) {
            debugPrint(
              'Could not clear the session after profile loading failed: '
              '$signOutError',
            );
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
      return null;
    } catch (e) {
      // Handle login error silently for production
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      // Handle logout error silently for production
      rethrow;
    }
  }

  /// Request a password reset email for the given address
  Future<bool> requestPasswordReset({required String email}) async {
    try {
      final redirectTo = kIsWeb ? '${Uri.base.origin}/#/reset-password' : null;
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
      return true;
    } catch (e) {
      // Return false on failure but don't crash the caller
      return false;
    }
  }

  /// Update the authenticated user's password after a recovery link is opened.
  Future<bool> updatePassword({required String password}) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: password),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the authenticated user's profile, including its database role.
  Future<UserModel?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final existingUser = await getUserById(session.user.id);
    if (existingUser != null) {
      if (existingUser.accountStatus == 'deleted') {
        return null;
      }
      return existingUser;
    }

    final createdUser = await _createProfileFromAuthUser(session.user);
    if (createdUser.accountStatus == 'deleted') {
      return null;
    }
    return createdUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _client.auth.currentSession != null;
  }

  // ==================== USER OPERATIONS ====================

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final userData = await _client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (userData == null) return null;
    return UserModel.fromJson(await _withRoleProfile(userData));
  }

  Future<UserModel?> getJobSeekerUserByProfileId(
    String jobSeekerProfileId,
  ) async {
    final response = await _client.rpc(
      'get_job_seeker_applicant',
      params: {'p_job_seeker_profile_id': jobSeekerProfileId},
    );
    if (response is! List) {
      throw const FormatException('Invalid applicant profile response.');
    }
    if (response.isEmpty) return null;
    final row = Map<String, dynamic>.from(response.first as Map);
    row['resume_url'] = await _signedResumeUrl(row['resume_url'] as String?);
    row['resume_image_url'] = await _signedResumeUrl(
      row['resume_image_url'] as String?,
    );
    return UserModel.fromJson(row);
  }

  /// Fetch all users
  Future<List<UserModel>> fetchUsers() async {
    final usersData = await _client.rpc('admin_list_users');
    return (usersData as List)
        .map((user) => UserModel.fromJson(user as Map<String, dynamic>))
        .toList();
  }

  /// Fetch the limited active-user directory used to start conversations.
  Future<List<UserModel>> fetchConversationUsers() async {
    final usersData = await _client.rpc('conversation_user_directory');
    return (usersData as List)
        .map((user) => UserModel.fromJson(user as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> fetchAdminDashboardStats() async {
    final response = await _client.rpc('admin_dashboard_stats');
    if (response is! Map) {
      throw const FormatException('Invalid admin dashboard statistics.');
    }

    int countFor(String key) {
      final value = response[key];
      if (value is! num) {
        throw FormatException('Missing or invalid dashboard statistic: $key.');
      }
      return value.toInt();
    }

    return {
      'users': countFor('users'),
      'employers': countFor('employers'),
      'jobs': countFor('jobs'),
      'announcements': countFor('announcements'),
      'reports': countFor('reports'),
    };
  }

  Future<UserModel> _createProfileFromAuthUser(supabase.User authUser) async {
    final metadata = authUser.userMetadata;
    final metadataRole = metadata is Map<String, dynamic>
        ? metadata['role']
        : null;
    final trustedAdmin = authUser.appMetadata['role'] == AppConstants.roleAdmin;
    final roleCandidate = trustedAdmin ? AppConstants.roleAdmin : metadataRole;

    if (roleCandidate is! String ||
        (roleCandidate != AppConstants.roleEmployer &&
            roleCandidate != AppConstants.roleJobSeeker &&
            !trustedAdmin)) {
      throw const FormatException(
        'This account is missing a valid role or requires administrator provisioning. Contact support to restore access.',
      );
    }
    final role = roleCandidate;

    final name = metadata is Map<String, dynamic>
        ? (metadata['name'] as String?)
        : null;

    final email = authUser.email ?? '';
    final profileName = name?.trim().isNotEmpty == true
        ? name!
        : email.split('@').first;
    final createdAt = DateTime.now();

    final profile = {
      'auth_user_id': authUser.id,
      'email': email,
      'name': profileName,
      'role': role,
      'account_status': 'active',
      'created_at': createdAt.toIso8601String(),
    };

    await _client.from(SupabaseConfig.usersTable).insert(profile);
    await _ensureRoleProfile(authUser.id, role, profileName);
    return UserModel(
      id: authUser.id,
      name: profileName,
      email: email,
      role: role,
      accountStatus: 'active',
      createdAt: createdAt,
    );
  }

  Future<void> _ensureRoleProfile(
    String userId,
    String role,
    String name,
  ) async {
    switch (role) {
      case AppConstants.roleJobSeeker:
        await _client
            .from('job_seekers')
            .upsert(
              {'user_id': userId},
              onConflict: 'user_id',
              ignoreDuplicates: true,
            );
        break;
      case AppConstants.roleEmployer:
        await _client
            .from('employers')
            .upsert(
              {'user_id': userId, 'company_name': name},
              onConflict: 'user_id',
              ignoreDuplicates: true,
            );
        break;
      case AppConstants.roleAdmin:
        await _client
            .from('admins')
            .upsert(
              {'user_id': userId},
              onConflict: 'user_id',
              ignoreDuplicates: true,
            );
        break;
      default:
        throw StateError('Unsupported account type "$role" for role profile.');
    }
  }

  Future<String?> _getJobSeekerProfileId(String userId) async {
    final profile = await _client
        .from('job_seekers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['id'] as String?;
  }

  Future<String?> _getEmployerProfileId(String userId) async {
    final profile = await _client
        .from('employers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['id'] as String?;
  }

  Future<String?> _getAdminProfileId(String userId) async {
    final profile = await _client
        .from('admins')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['id'] as String?;
  }

  Future<String?> getAdminProfileId(String userId) =>
      _getAdminProfileId(userId);

  String? _resumeObjectPath(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;

    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('object');
    if (objectIndex < 0 ||
        objectIndex + 3 >= segments.length ||
        !{
          'public',
          'sign',
          'authenticated',
        }.contains(segments[objectIndex + 1]) ||
        segments[objectIndex + 2] != SupabaseConfig.resumesBucket) {
      return null;
    }

    return segments.skip(objectIndex + 3).join('/');
  }

  Future<String?> _signedResumeUrl(String? value) async {
    if (value == null || value.trim().isEmpty) return value;
    final path = _resumeObjectPath(value);
    if (path == null) return value;
    if (path.isEmpty) {
      throw const FormatException('The stored resume path is invalid.');
    }

    return _client.storage
        .from(SupabaseConfig.resumesBucket)
        .createSignedUrl(path, 60 * 60 * 24);
  }

  Future<Map<String, dynamic>> _withRoleProfile(
    Map<String, dynamic> userData,
  ) async {
    final userId = userData['auth_user_id'] as String;
    final role = userData['role'];
    if (role is! String ||
        (role != AppConstants.roleJobSeeker &&
            role != AppConstants.roleEmployer &&
            role != AppConstants.roleAdmin)) {
      throw StateError(
        'User $userId has a missing or unsupported account type.',
      );
    }

    final table = switch (role) {
      AppConstants.roleJobSeeker => 'job_seekers',
      AppConstants.roleEmployer => 'employers',
      AppConstants.roleAdmin => 'admins',
      _ => throw StateError('Unsupported account type "$role".'),
    };

    var profile = await _client
        .from(table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (profile == null) {
      if (_client.auth.currentUser?.id != userId) {
        throw StateError(
          'The $role profile for user $userId is missing and cannot be restored '
          'from this account.',
        );
      }
      final name = userData['name'];
      if (name is! String || name.trim().isEmpty) {
        throw StateError(
          'Cannot restore the $role profile for user $userId without a name.',
        );
      }
      await _ensureRoleProfile(userId, role, name);
      profile = await _client
          .from(table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    }
    if (profile == null) {
      throw StateError(
        'The $role profile for user $userId could not be restored.',
      );
    }
    final result = {
      ...userData,
      ...profile,
      'id': userId,
      'role': role,
      'created_at': userData['created_at'],
    };
    if (role == AppConstants.roleJobSeeker) {
      result['resume_url'] = await _signedResumeUrl(
        profile['resume_url'] as String?,
      );
      result['resume_image_url'] = await _signedResumeUrl(
        profile['resume_image_url'] as String?,
      );
    }
    return result;
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('You may update only your own profile.');
    }

    const userFields = {'name', 'bio', 'profile_image'};
    const seekerFields = {
      'phone',
      'location',
      'skills',
      'work_experience',
      'education',
      'resume_file_name',
      'resume_url',
      'resume_image_file_name',
      'resume_image_url',
    };
    const employerFields = {
      'phone',
      'location',
      'company_name',
      'company_address',
      'company_description',
      'industry',
      'company_logo',
      'website',
    };
    const adminFields = {'phone', 'location'};

    final userData = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => !userFields.contains(key));
    final profileData = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => userFields.contains(key));
    final role = await _client
        .from(SupabaseConfig.usersTable)
        .select('role')
        .eq('auth_user_id', userId)
        .single();
    final roleName = role['role'];

    final Set<String> allowedProfileFields;
    final String profileTable;
    switch (roleName) {
      case AppConstants.roleJobSeeker:
        allowedProfileFields = seekerFields;
        profileTable = 'job_seekers';
      case AppConstants.roleEmployer:
        allowedProfileFields = employerFields;
        profileTable = 'employers';
      case AppConstants.roleAdmin:
        allowedProfileFields = adminFields;
        profileTable = 'admins';
      default:
        throw StateError('The signed-in account has an unsupported role.');
    }

    final invalidFields = profileData.keys
        .where((key) => !allowedProfileFields.contains(key))
        .toList();
    if (invalidFields.isNotEmpty) {
      throw ArgumentError(
        'Fields are not valid for the $roleName profile: '
        '${invalidFields.join(', ')}.',
      );
    }

    if (userData.isNotEmpty) {
      await _client
          .from(SupabaseConfig.usersTable)
          .update(userData)
          .eq('auth_user_id', userId);
    }
    if (profileData.isNotEmpty) {
      await _client
          .from(profileTable)
          .update(profileData)
          .eq('user_id', userId);
    }
    return true;
  }

  /// Upload a profile avatar image to Supabase storage and save public URL to user profile
  Future<String?> uploadProfileImage({
    required String userId,
    required File file,
  }) async {
    final bucket = SupabaseConfig.avatarsBucket;
    final fileId = const Uuid().v4();
    final path = 'avatars/$userId/$fileId.jpg';

    final bytes = await file.readAsBytes();

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    await updateUserProfile(userId: userId, data: {'profile_image': publicUrl});

    return publicUrl;
  }

  /// Upload a private resume image and return a temporary signed URL.
  Future<String?> uploadResumeImage({
    required String userId,
    required File file,
  }) async {
    const bucket = SupabaseConfig.resumesBucket;
    final fileId = const Uuid().v4();
    final extension = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = 'resumes/$userId/$fileId.$extension';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );

    try {
      await updateUserProfile(
        userId: userId,
        data: {
          'resume_image_file_name': file.path.split(RegExp(r'[/\\]')).last,
          'resume_image_url': path,
          'resume_file_name': null,
          'resume_url': null,
        },
      );
      return _signedResumeUrl(path);
    } catch (error, stackTrace) {
      try {
        await _client.storage.from(bucket).remove([path]);
      } catch (cleanupError) {
        debugPrint('Could not remove an unlinked resume upload: $cleanupError');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Delete a user's private resume image and clear its profile fields.
  Future<bool> deleteResumeImage({required String userId, String? url}) async {
    final path = _resumeObjectPath(url);
    if (path != null) {
      await _client.storage.from(SupabaseConfig.resumesBucket).remove([path]);
    }

    await updateUserProfile(
      userId: userId,
      data: {
        'resume_image_file_name': null,
        'resume_image_url': null,
        'resume_file_name': null,
        'resume_url': null,
      },
    );
    return true;
  }

  // ==================== JOB OPERATIONS ====================

  /// Fetch all jobs
  Future<List<Job>> fetchJobs({String? category, String? location}) async {
    const pageSize = 500;
    var query = _client.from(SupabaseConfig.jobsTable).select();

    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }

    if (location != null && location != 'All') {
      query = query.eq('location', location);
    }

    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await query
          .order('posted_date', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);
      rows.addAll(page as List);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return _hydrateJobs(rows);
  }

  /// Fetch job by ID
  Future<Job?> getJobById(String jobId) async {
    final jobData = await _client
        .from(SupabaseConfig.jobsTable)
        .select()
        .eq('id', jobId)
        .maybeSingle();
    if (jobData == null) return null;

    final jobs = await _hydrateJobs([jobData]);
    return jobs.first;
  }

  /// Create a job owned by the active employer or administrator.
  Future<bool> createJob(Job job) async {
    final user = await getCurrentUser();
    if (user == null ||
        !user.canAccessRoleActions ||
        (user.role != AppConstants.roleEmployer &&
            user.role != AppConstants.roleAdmin)) {
      throw StateError(
        'An active employer or administrator account is required to post jobs.',
      );
    }

    final String? employerProfileId;
    final String? adminProfileId;
    if (user.role == AppConstants.roleEmployer) {
      if (job.employerId != user.id) {
        throw StateError('Employers may only post jobs for their own profile.');
      }
      employerProfileId = await _getEmployerProfileId(user.id);
      adminProfileId = null;
      if (employerProfileId == null) {
        throw StateError(
          'Your employer profile is missing. Sign out and sign in again, or contact support.',
        );
      }
    } else {
      adminProfileId = await _getAdminProfileId(user.id);
      employerProfileId = null;
      if (adminProfileId == null) {
        throw StateError(
          'Your administrator profile is missing. Contact support to restore it.',
        );
      }
    }

    await _client.from(SupabaseConfig.jobsTable).insert({
      ...job.toJson(),
      'employer_id': employerProfileId,
      'admin_id': adminProfileId,
    });
    return true;
  }

  /// Delete a job when permitted by the database owner/admin policy.
  Future<bool> deleteJob(String jobId) async {
    final deletedRows = await _client
        .from(SupabaseConfig.jobsTable)
        .delete()
        .eq('id', jobId)
        .select('id');
    if ((deletedRows as List).isEmpty) {
      throw StateError('The job was not found or you cannot delete it.');
    }
    return true;
  }

  /// Search jobs by title or description
  Future<List<Job>> searchJobs(String query) async {
    final jobs = await _client
        .from(SupabaseConfig.jobsTable)
        .select()
        .ilike('title', '%$query%')
        .or('description.ilike.%$query%');

    return _hydrateJobs(jobs as List);
  }

  Future<List<Job>> _hydrateJobs(List<dynamic> rows) async {
    final employerIds = rows
        .map((row) => (row as Map<String, dynamic>)['employer_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final adminIds = rows
        .map((row) => (row as Map<String, dynamic>)['admin_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final employersById = <String, Map<String, dynamic>>{};
    if (employerIds.isNotEmpty) {
      final employers = await _client.rpc(
        'public_employer_profiles',
        params: {'p_employer_ids': employerIds},
      );
      for (final rawEmployer in employers as List) {
        final employer = Map<String, dynamic>.from(rawEmployer as Map);
        employersById[employer['employer_id'] as String] = employer;
      }
    }
    final adminsById = <String, Map<String, dynamic>>{};
    if (adminIds.isNotEmpty) {
      final admins = await _client.rpc(
        'public_admin_job_profiles',
        params: {'p_admin_ids': adminIds},
      );
      for (final rawAdmin in admins as List) {
        final admin = Map<String, dynamic>.from(rawAdmin as Map);
        adminsById[admin['admin_id'] as String] = admin;
      }
    }

    return rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow as Map<String, dynamic>);
      final employer = employersById[row['employer_id']];
      final admin = adminsById[row['admin_id']];
      row['employer_user_id'] = employer?['user_id'] as String?;
      row['employer_name'] =
          employer?['name'] as String? ??
          admin?['name'] as String? ??
          'WorkNests Admin';
      row['employer_profile_image'] =
          employer?['profile_image'] as String? ??
          admin?['profile_image'] as String?;
      return Job.fromJson(row);
    }).toList();
  }

  Future<List<Job>> fetchSavedJobs(String userId) async {
    final seekerProfileId = await _getJobSeekerProfileId(userId);
    if (seekerProfileId == null) {
      throw StateError('The job seeker profile is missing.');
    }

    final rows = await _client
        .from('saved_jobs')
        .select('jobs(*)')
        .eq('job_seeker_id', seekerProfileId)
        .order('created_at', ascending: false);
    final jobs = (rows as List)
        .map((row) => row['jobs'])
        .whereType<Map<String, dynamic>>()
        .toList();
    return _hydrateJobs(jobs);
  }

  Future<void> saveJobForUser(String userId, String jobId) async {
    final seekerProfileId = await _getJobSeekerProfileId(userId);
    if (seekerProfileId == null) {
      throw StateError('A job seeker profile is required to save jobs.');
    }
    await _client
        .from('saved_jobs')
        .upsert(
          {'job_seeker_id': seekerProfileId, 'job_id': jobId},
          onConflict: 'job_seeker_id,job_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> unsaveJobForUser(String userId, String jobId) async {
    final seekerProfileId = await _getJobSeekerProfileId(userId);
    if (seekerProfileId == null) return;
    await _client
        .from('saved_jobs')
        .delete()
        .eq('job_seeker_id', seekerProfileId)
        .eq('job_id', jobId);
  }

  // ==================== APPLICATION OPERATIONS ====================

  /// Apply for a job
  Future<bool> applyForJob(JobApplication application) async {
    try {
      final user = await getCurrentUser();
      if (user == null ||
          !user.canAccessRoleActions ||
          user.role != AppConstants.roleJobSeeker) {
        throw StateError(
          'This account is suspended and cannot apply for jobs.',
        );
      }

      final seekerProfileId = await _getJobSeekerProfileId(
        application.jobSeekerId,
      );
      if (seekerProfileId == null) {
        throw StateError('A job seeker profile is required to apply.');
      }

      await _client.from(SupabaseConfig.applicationsTable).insert({
        ...application.toJson(),
        'job_seeker_id': seekerProfileId,
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get applications for a job seeker
  Future<List<JobApplication>> getJobSeekerApplications(String userId) async {
    final seekerProfileId = await _getJobSeekerProfileId(userId);
    if (seekerProfileId == null) {
      throw StateError('The job seeker profile is missing.');
    }
    final applications = await _client
        .from(SupabaseConfig.applicationsTable)
        .select('*, jobs(employer_id)')
        .eq('job_seeker_id', seekerProfileId);

    return _hydrateApplications(applications as List);
  }

  /// Get applications received by employer
  Future<List<JobApplication>> getEmployerApplications(
    String employerId,
  ) async {
    final employerProfileId = await _getEmployerProfileId(employerId);
    if (employerProfileId == null) {
      throw StateError('The employer profile is missing.');
    }
    final applications = await _client
        .from(SupabaseConfig.applicationsTable)
        .select('*, jobs!inner(employer_id)')
        .eq('jobs.employer_id', employerProfileId);

    return _hydrateApplications(applications as List);
  }

  /// Fetch all applications
  Future<List<JobApplication>> fetchApplications() async {
    final applications = await _client
        .from(SupabaseConfig.applicationsTable)
        .select('*, jobs(employer_id)')
        .order('created_at', ascending: false);

    return _hydrateApplications(applications as List);
  }

  Future<List<JobApplication>> _hydrateApplications(List<dynamic> rows) async {
    if (rows.isEmpty) return [];

    final seekerProfileIds = rows
        .map((row) => (row as Map<String, dynamic>)['job_seeker_id'] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('job_seekers')
        .select('id, user_id')
        .inFilter('id', seekerProfileIds);
    final authIdsByProfileId = {
      for (final profile in profiles as List)
        profile['id'] as String: profile['user_id'] as String,
    };

    return rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow as Map<String, dynamic>);
      row['job_seeker_id'] =
          authIdsByProfileId[row['job_seeker_id']] ?? row['job_seeker_id'];
      return JobApplication.fromJson(row);
    }).toList();
  }

  /// Update application status
  Future<bool> updateApplicationStatus({
    required String applicationId,
    required String status,
    DateTime? interviewDate,
  }) async {
    final user = await getCurrentUser();
    if (user == null ||
        !user.canAccessRoleActions ||
        (user.role != AppConstants.roleEmployer &&
            user.role != AppConstants.roleAdmin)) {
      throw StateError(
        'An active employer or administrator account is required to update applicants.',
      );
    }

    final updatedRows = await _client
        .from(SupabaseConfig.applicationsTable)
        .update({
          'status': status,
          'reviewed_date': DateTime.now().toIso8601String(),
          if (interviewDate != null)
            'interview_date': interviewDate.toIso8601String(),
        })
        .eq('id', applicationId)
        .select('id');
    if ((updatedRows as List).isEmpty) {
      throw StateError(
        'The application was not found or you cannot update it.',
      );
    }
    return true;
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// Send message
  Future<bool> sendMessage(Message message) async {
    try {
      await _client.from(SupabaseConfig.messagesTable).insert(message.toJson());
      return true;
    } catch (e) {
      // Handle error silently for production
      return false;
    }
  }

  /// Get conversation messages
  Future<List<Message>> getConversationMessages(String conversationId) async {
    try {
      final messages = await _client
          .from(SupabaseConfig.messagesTable)
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: true);

      final conversation = await _client
          .from(SupabaseConfig.conversationsTable)
          .select('participant1_id, participant2_id')
          .eq('id', conversationId)
          .single();
      final participantIds = [
        conversation['participant1_id'] as String,
        conversation['participant2_id'] as String,
      ];
      final users = await getUsersByIds(participantIds);
      final names = {for (final user in users) user.id: user.name};
      return (messages as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final senderId = row['sender_id'] as String;
        row['sender_name'] = names[senderId] ?? '';
        row['receiver_id'] = participantIds.firstWhere(
          (id) => id != senderId,
          orElse: () => '',
        );
        return Message.fromJson(row);
      }).toList();
    } catch (e) {
      // Handle error silently for production
      return [];
    }
  }

  /// Get user conversations
  Future<List<Conversation>> getUserConversations(String userId) async {
    try {
      final conversations = await _client
          .from(SupabaseConfig.conversationsTable)
          .select()
          .or('participant1_id.eq.$userId,participant2_id.eq.$userId')
          .order('last_message_timestamp', ascending: false);

      final conversationList = (conversations as List)
          .map(
            (conversation) =>
                Conversation.fromJson(conversation as Map<String, dynamic>),
          )
          .toList();

      final userIds = conversationList
          .expand(
            (conversation) => [
              conversation.participant1Id,
              conversation.participant2Id,
            ],
          )
          .toSet()
          .toList();

      if (userIds.isNotEmpty) {
        final users = await getUsersByIds(userIds);
        final userMap = {for (var user in users) user.id: user};

        return conversationList
            .map(
              (conversation) => conversation.copyWith(
                participant1Name: userMap[conversation.participant1Id]?.name,
                participant2Name: userMap[conversation.participant2Id]?.name,
                participant1Role: userMap[conversation.participant1Id]?.role,
                participant2Role: userMap[conversation.participant2Id]?.role,
                participant1ProfileImage:
                    userMap[conversation.participant1Id]?.profileImage,
                participant2ProfileImage:
                    userMap[conversation.participant2Id]?.profileImage,
              ),
            )
            .toList();
      }

      return conversationList;
    } catch (e) {
      // Handle error silently for production
      return [];
    }
  }

  /// Get users by a list of IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      final users = await _client.rpc(
        'public_user_profiles',
        params: {'p_user_ids': userIds},
      );
      return (users as List).map((rawUser) {
        final user = rawUser as Map<String, dynamic>;
        return UserModel(
          id: user['auth_user_id'] as String,
          name: user['name'] as String,
          email: '',
          role: user['role'] as String,
          profileImage: user['profile_image'] as String?,
          createdAt: DateTime.parse(user['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Message> hydrateMessageRecord(Map<String, dynamic> record) async {
    final conversation = await _client
        .from(SupabaseConfig.conversationsTable)
        .select('participant1_id, participant2_id')
        .eq('id', record['conversation_id'] as String)
        .maybeSingle();
    if (conversation == null) return Message.fromJson(record);

    final senderId = record['sender_id'] as String;
    final participantIds = [
      conversation['participant1_id'] as String,
      conversation['participant2_id'] as String,
    ];
    final senders = await getUsersByIds([senderId]);
    return Message.fromJson({
      ...record,
      'sender_name': senders.isEmpty ? '' : senders.first.name,
      'receiver_id': participantIds.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      ),
    });
  }

  Future<Map<String, String>?> getAppPolicy() async {
    try {
      final policy = await _client
          .from(SupabaseConfig.appPoliciesTable)
          .select('title, body, created_by')
          .eq('policy_key', 'default')
          .maybeSingle();
      if (policy == null) return null;
      final result = <String, String>{
        'title': policy['title'] as String,
        'body': policy['body'] as String,
      };
      final createdBy = policy['created_by'] as String?;
      if (createdBy != null) result['created_by'] = createdBy;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateAppPolicy({
    required String title,
    required String body,
  }) async {
    try {
      final policyData = <String, dynamic>{
        'policy_key': 'default',
        'title': title,
        'body': body,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final authUserId = _client.auth.currentUser?.id;
      if (authUserId != null) {
        final adminProfileId = await _getAdminProfileId(authUserId);
        if (adminProfileId == null) {
          throw StateError('An admin profile is required to update policies.');
        }
        policyData['created_by'] = adminProfileId;
      }
      await _client.from(SupabaseConfig.appPoliciesTable).upsert(policyData);
      return true;
    } catch (e) {
      debugPrint('Unable to update app policy: $e');
      return false;
    }
  }

  /// Get or create a conversation between two users
  Future<Conversation?> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final existingConversation = await _client
          .from(SupabaseConfig.conversationsTable)
          .select()
          .or(
            'and(participant1_id.eq.$currentUserId,participant2_id.eq.$otherUserId),and(participant1_id.eq.$otherUserId,participant2_id.eq.$currentUserId)',
          )
          .maybeSingle();

      final now = DateTime.now();
      if (existingConversation != null) {
        final conversation = Conversation.fromJson(existingConversation);
        final users = await getUsersByIds([currentUserId, otherUserId]);
        final userMap = {for (var user in users) user.id: user};

        return conversation.copyWith(
          participant1Name: userMap[conversation.participant1Id]?.name,
          participant2Name: userMap[conversation.participant2Id]?.name,
          participant1Role: userMap[conversation.participant1Id]?.role,
          participant2Role: userMap[conversation.participant2Id]?.role,
        );
      }

      final newConversationId = const Uuid().v4();
      await _client.from(SupabaseConfig.conversationsTable).insert({
        'id': newConversationId,
        'participant1_id': currentUserId,
        'participant2_id': otherUserId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final users = await getUsersByIds([currentUserId, otherUserId]);
      final userMap = {for (var user in users) user.id: user};

      return Conversation(
        id: newConversationId,
        participant1Id: currentUserId,
        participant2Id: otherUserId,
        participant1Name: userMap[currentUserId]?.name,
        participant2Name: userMap[otherUserId]?.name,
        participant1Role: userMap[currentUserId]?.role,
        participant2Role: userMap[otherUserId]?.role,
        lastMessage: null,
        lastMessageTimestamp: null,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update the last message metadata for a conversation
  Future<bool> updateConversationLastMessage(
    String conversationId,
    String message,
    DateTime timestamp,
  ) async {
    try {
      await _client
          .from(SupabaseConfig.conversationsTable)
          .update({
            'last_message': message,
            'last_message_timestamp': timestamp.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ANNOUNCEMENT OPERATIONS ====================

  /// Get announcements visible to a specific role.
  /// If the announcement target list is empty, or contains an "all" alias,
  /// the announcement is visible to every account.
  Future<List<Announcement>> getAnnouncements({String? role}) async {
    try {
      final announcements = await _client
          .from(SupabaseConfig.announcementsTable)
          .select()
          .order('publish_date', ascending: false);

      final allAnnouncements = (announcements as List)
          .map((ann) => Announcement.fromJson(ann))
          .toList();

      if (role == null || role.isEmpty) {
        return allAnnouncements;
      }

      return allAnnouncements
          .where((announcement) => announcement.isVisibleTo(role))
          .toList();
    } catch (e) {
      // Handle error silently for production
      return [];
    }
  }

  /// Create announcement (admin only)
  Future<bool> createAnnouncement(Announcement announcement) async {
    try {
      final announcementData = announcement.toJson();
      final authUserId = _client.auth.currentUser?.id;
      if (authUserId != null) {
        final adminProfileId = await _getAdminProfileId(authUserId);
        if (adminProfileId == null) {
          throw StateError(
            'An admin profile is required to create announcements.',
          );
        }
        announcementData['created_by'] = adminProfileId;
      }
      await _client
          .from(SupabaseConfig.announcementsTable)
          .insert(announcementData);
      return true;
    } catch (e) {
      // Handle error silently for production
      return false;
    }
  }

  /// Delete announcement (admin only)
  Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      await _client
          .from(SupabaseConfig.announcementsTable)
          .delete()
          .eq('id', announcementId);
      return true;
    } catch (e) {
      // Handle error silently for production
      return false;
    }
  }

  // ==================== REPORT OPERATIONS ====================

  /// Create a new report
  Future<bool> createReport({
    required String reporterId,
    required String reportType,
    String? subjectId,
    required String category,
    required String title,
    required String description,
  }) async {
    try {
      final subjectColumn = switch (reportType) {
        'job_report' => 'subject_job_id',
        'applicant_violation' || 'user_report' => 'subject_user_id',
        _ => null,
      };
      await _client.from('reports').insert({
        'reporter_id': reporterId,
        'report_type': reportType,
        if (subjectColumn != null && subjectId != null)
          subjectColumn: subjectId,
        'category': category,
        'title': title,
        'description': description,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all reports (admin only)
  Future<List<Map<String, dynamic>>> getReports({String? status}) async {
    try {
      var query = _client.from('reports').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final reports = await query.order('created_at', ascending: false);
      return (reports as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get reports by reporter (user can see their own reports)
  Future<List<Map<String, dynamic>>> getUserReports(String userId) async {
    try {
      final reports = await _client
          .from('reports')
          .select()
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);

      return (reports as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Update report status (admin only)
  Future<bool> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
    String? reviewedByAdminId,
  }) async {
    try {
      final update = {
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) {
        update['admin_notes'] = adminNotes;
      }

      if (reviewedByAdminId != null) {
        final adminProfileId = await _getAdminProfileId(reviewedByAdminId);
        if (adminProfileId == null) {
          throw StateError('An admin profile is required to review reports.');
        }
        update['reviewed_by_admin_id'] = adminProfileId;
      }

      await _client.from('reports').update(update).eq('id', reportId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ACCOUNT MANAGEMENT OPERATIONS ====================

  /// Suspend a user account (admin only)
  Future<bool> suspendUser(String userId) async {
    try {
      await _client
          .from(SupabaseConfig.usersTable)
          .update({'account_status': 'suspended'})
          .eq('auth_user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reactivate a suspended user account (admin only)
  Future<bool> reactivateUser(String userId) async {
    try {
      await _client
          .from(SupabaseConfig.usersTable)
          .update({'account_status': 'active'})
          .eq('auth_user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a user account (admin only)
  /// This soft-deletes by marking account as deleted
  Future<bool> deleteUser(String userId) async {
    try {
      await _client
          .from(SupabaseConfig.usersTable)
          .update({'account_status': 'deleted'})
          .eq('auth_user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user account status
  Future<String?> getUserAccountStatus(String userId) async {
    try {
      final user = await _client
          .from(SupabaseConfig.usersTable)
          .select('account_status')
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (user != null) {
        return user['account_status'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUserAccountStatusByEmail(String email) async {
    try {
      final user = await _client
          .from(SupabaseConfig.usersTable)
          .select('account_status')
          .eq('email', email.trim())
          .maybeSingle();

      if (user != null) {
        return user['account_status'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== NOTIFICATION READ STATE ====================

  /// Save notification read state to Supabase for syncing across devices
  Future<void> saveNotificationReadState({
    required String userId,
    required List<String> readKeys,
    required DateTime lastReadAt,
  }) async {
    try {
      await _client.from(SupabaseConfig.notificationReadStateTable).upsert({
        'user_id': userId,
        'read_keys': readKeys,
        'last_read_at': lastReadAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      // Log but don't fail if persistence fails; local cache will still work
      debugPrint('Failed to save notification read state: $e');
    }
  }

  /// Load notification read state from Supabase for a user
  Future<Map<String, dynamic>?> loadNotificationReadState(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.notificationReadStateTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Failed to load notification read state: $e');
      return null;
    }
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  /// Subscribe to job updates
  final Map<String, supabase.RealtimeChannel> _jobChannels = {};

  void subscribeToJobs({
    required void Function(Map<String, dynamic> record) onChange,
  }) {
    const channelName = 'jobs';
    if (_jobChannels.containsKey(channelName)) return;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.jobsTable,
          callback: (payload) {
            try {
              final dynamic newRec = payload.newRecord;
              final dynamic oldRec = payload.oldRecord;
              final record = (newRec ?? oldRec) as Map<String, dynamic>?;
              if (record == null) return;
              onChange(record);
            } catch (_) {
              // ignore
            }
          },
        )
        .subscribe();

    _jobChannels[channelName] = channel;
  }

  final Map<String, supabase.RealtimeChannel> _messageChannels = {};

  void subscribeToMessages({
    required String conversationId,
    required void Function(Map<String, dynamic> record) onChange,
  }) {
    final channelName = 'messages:$conversationId';
    if (_messageChannels.containsKey(channelName)) return;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.messagesTable,
          callback: (payload) {
            try {
              final record = payload.newRecord as Map<String, dynamic>?;
              if (record == null) return;
              onChange(record);
            } catch (_) {
              // ignore
            }
          },
        )
        .subscribe();

    _messageChannels[channelName] = channel;
  }

  /// Subscribe to announcements table changes so users see admin announcements in realtime.
  supabase.RealtimeChannel? _announcementsChannel;

  final Map<String, supabase.RealtimeChannel> _conversationChannels = {};

  void subscribeToConversations({
    required String userId,
    required void Function(Map<String, dynamic> record) onChange,
  }) {
    final channelName = 'conversations:$userId';
    if (_conversationChannels.containsKey(channelName)) return;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.conversationsTable,
          callback: (payload) {
            try {
              final dynamic newRec = payload.newRecord;
              final dynamic oldRec = payload.oldRecord;
              final record = (newRec ?? oldRec) as Map<String, dynamic>?;
              if (record == null) return;
              onChange(record);
            } catch (_) {
              // ignore
            }
          },
        )
        .subscribe();

    _conversationChannels[channelName] = channel;
  }

  void subscribeToAnnouncements({required void Function() onChange}) {
    if (_announcementsChannel != null) return;

    _announcementsChannel = _client
        .channel('announcements')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.announcementsTable,
          callback: (_) {
            onChange();
          },
        )
        .subscribe();
  }

  /// Subscribe to application table changes for a specific user (employer or job seeker).
  final Map<String, supabase.RealtimeChannel> _applicationChannels = {};

  void subscribeToApplications({
    required String userId,
    required String role,
    required void Function(Map<String, dynamic> record) onChange,
  }) {
    final channelName = 'applications:$userId';
    if (_applicationChannels.containsKey(channelName)) return;

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.applicationsTable,
          callback: (payload) {
            try {
              final dynamic newRec = payload.newRecord;
              final dynamic oldRec = payload.oldRecord;
              final record = (newRec ?? oldRec) as Map<String, dynamic>?;
              if (record == null) return;

              if (role == AppConstants.roleEmployer) {
                unawaited(
                  () async {
                    final employerProfileId = await _getEmployerProfileId(
                      userId,
                    );
                    if (employerProfileId == null) return;
                    final job = await _client
                        .from(SupabaseConfig.jobsTable)
                        .select('employer_id')
                        .eq('id', record['job_id'] as String)
                        .maybeSingle();
                    if (job?['employer_id'] == employerProfileId) {
                      onChange({...record, 'employer_id': userId});
                    }
                  }().catchError((Object error, StackTrace stackTrace) {
                    debugPrint('Application realtime lookup failed: $error');
                  }),
                );
              } else if (role == AppConstants.roleJobSeeker) {
                unawaited(
                  () async {
                    final seekerProfileId = await _getJobSeekerProfileId(
                      userId,
                    );
                    if (seekerProfileId == null ||
                        record['job_seeker_id'] != seekerProfileId) {
                      return;
                    }
                    onChange(record);
                  }().catchError((Object error, StackTrace stackTrace) {
                    debugPrint('Application realtime lookup failed: $error');
                  }),
                );
              }
            } catch (error) {
              debugPrint('Application realtime event failed: $error');
            }
          },
        )
        .subscribe();

    _applicationChannels[channelName] = channel;
  }

  Future<void> unsubscribeFromApplications(String userId) async {
    final channelName = 'applications:$userId';
    final channel = _applicationChannels[channelName];
    if (channel == null) return;
    await channel.unsubscribe();
    _applicationChannels.remove(channelName);
  }

  Future<void> unsubscribeFromAnnouncements() async {
    if (_announcementsChannel == null) return;
    await _announcementsChannel?.unsubscribe();
    _announcementsChannel = null;
  }
}
