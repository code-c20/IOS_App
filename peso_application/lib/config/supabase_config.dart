/// Supabase Configuration
///
/// Replace these values with your actual Supabase project credentials
/// You can find them at: https://app.supabase.com/project/[YOUR_PROJECT]/settings/api
class SupabaseConfig {
  /// Your Supabase project URL
  /// Example: https://xyzabc.supabase.co
  static const String supabaseUrl = 'https://rvecrnwwjaclusqzokgl.supabase.co';

  /// Your Supabase anonymous key (public key)
  /// Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2ZWNybnd3amFjbHVzcXpva2dsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxOTk1MDYsImV4cCI6MjEwMTc3NTUwNn0.52NN0-t4UNcnlnX6gHmRNNltoDm9og5jqau1vt9tepw';

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultSupabaseAnonKey,
  );

  // Database Table Names
  static const String usersTable = 'users';
  static const String jobsTable = 'jobs';
  static const String applicationsTable = 'applications';
  static const String messagesTable = 'messages';
  static const String announcementsTable = 'announcements';
  static const String conversationsTable = 'conversations';
  static const String notificationReadStateTable = 'notification_read_state';
  static const String appPoliciesTable = 'app_policies';

  /// Storage buckets provisioned by database_schema.sql.
  static const String avatarsBucket = 'avatars';
  static const String resumesBucket = 'resumes';
}
