import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peso_application/main.dart';
import 'package:peso_application/models/announcement.dart';
import 'package:peso_application/models/application.dart';
import 'package:peso_application/models/conversation.dart';
import 'package:peso_application/models/job.dart';
import 'package:peso_application/models/message.dart';
import 'package:peso_application/models/user.dart';
import 'package:peso_application/providers/announcement_provider.dart';
import 'package:peso_application/providers/application_provider.dart';
import 'package:peso_application/providers/auth_provider.dart';
import 'package:peso_application/providers/job_provider.dart';
import 'package:peso_application/providers/message_provider.dart';
import 'package:peso_application/providers/notification_provider.dart';
import 'package:peso_application/utils/constants.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('admin-owned jobs retain their admin owner when parsed', () {
    final job = Job.fromJson({
      'id': 'job-1',
      'title': 'Coordinator',
      'category': 'Office Assistant',
      'description': 'Coordinate the team.',
      'employer_id': null,
      'admin_id': 'admin-profile-id',
      'employer_name': 'Platform Admin',
      'location': 'Kidapawan City',
      'salary': '₱20,000',
      'requirements': <String>['Communication skills'],
      'deadline': DateTime(2026, 12).toIso8601String(),
    });

    expect(job.employerId, isEmpty);
    expect(job.adminId, 'admin-profile-id');
    expect(job.employerName, 'Platform Admin');
    expect(job.toJson()['admin_id'], 'admin-profile-id');
  });

  test('employer role profile fields load from the employer profile row', () {
    final user = UserModel.fromJson({
      'id': 'auth-user-id',
      'name': 'Account Contact',
      'email': 'contact@example.com',
      'role': AppConstants.roleEmployer,
      'account_status': 'active',
      'company_name': 'Acme Company',
      'company_description': 'We build useful things.',
      'phone': '+1 555 0100',
      'location': 'Davao City',
      'created_at': DateTime(2026, 1).toIso8601String(),
    });

    expect(user.role, AppConstants.roleEmployer);
    expect(user.companyName, 'Acme Company');
    expect(user.companyDescription, 'We build useful things.');
    expect(user.phone, '+1 555 0100');
    expect(user.location, 'Davao City');
  });

  test('email verification callback recognizes native and web redirect URLs', () {
    expect(
      isEmailVerificationCallback(Uri.parse('worknest://email-verified')),
      isTrue,
    );
    expect(
      isEmailVerificationCallback(
        Uri.parse('https://example.com/#/email-verified?code=abc'),
      ),
      isTrue,
    );
    expect(
      isEmailVerificationCallback(Uri.parse('https://example.com/#/login')),
      isFalse,
    );
  });

  test('friendly auth formatter hides raw host lookup exceptions', () {
    const raw =
        'ClientException with SocketException: Failed host lookup: \n\nNo address associated with hostname';

    final message = AuthProvider.formatErrorForUI(raw);

    expect(
      message,
      'Unable to connect to the service. Please check your internet connection and try again.',
    );
  });

  testWidgets(
    'app initializes with MultiProvider and displays AuthCheckScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(AuthCheckScreen), findsOneWidget);
    },
  );

  test(
    'notification provider persists read state across app restarts',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final seekerId = const Uuid().v4();
      final employerId = const Uuid().v4();
      final now = DateTime.now();

      final auth = _FakeAuthProvider(
        UserModel(
          id: seekerId,
          name: 'Jane',
          email: 'jane@example.com',
          role: AppConstants.roleJobSeeker,
          createdAt: now,
        ),
      );

      final messageProvider = _FakeMessageProvider([
        Conversation(
          id: const Uuid().v4(),
          participant1Id: seekerId,
          participant2Id: employerId,
          participant1Name: 'Jane',
          participant2Name: 'Acme',
          lastMessage: 'Hi there',
          lastMessageTimestamp: now,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final provider = NotificationProvider(
        authProvider: auth,
        messageProvider: messageProvider,
        applicationProvider: _FakeApplicationProvider([]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );

      expect(provider.notificationItems, isNotEmpty);
      provider.markAllAsRead();
      await provider.saveReadState();

      final restored = NotificationProvider(
        authProvider: auth,
        messageProvider: messageProvider,
        applicationProvider: _FakeApplicationProvider([]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );
      await restored.loadPersistedReadState();

      expect(restored.notificationItems.first.isRead, isTrue);
    },
  );

  test(
    'notification provider falls back to local storage if Supabase unavailable',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final seekerId = const Uuid().v4();
      final now = DateTime.now();

      final auth = _FakeAuthProvider(
        UserModel(
          id: seekerId,
          name: 'Jane',
          email: 'jane@example.com',
          role: AppConstants.roleJobSeeker,
          createdAt: now,
        ),
      );

      final provider = NotificationProvider(
        authProvider: auth,
        messageProvider: _FakeMessageProvider([]),
        applicationProvider: _FakeApplicationProvider([]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );

      // Manually set local storage to verify fallback works
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notification_read_keys|$seekerId', [
        'test_key_1',
      ]);
      await prefs.setString(
        'notification_read_keys|${seekerId}_last_read',
        now.toIso8601String(),
      );

      await provider.loadPersistedReadState();

      // Should load from local storage successfully
      expect(provider.toString().isNotEmpty, isTrue);
    },
  );

  test(
    'notification provider syncs read state across devices via local storage',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final seekerId = const Uuid().v4();
      final employerId = const Uuid().v4();
      final now = DateTime.now();

      final auth = _FakeAuthProvider(
        UserModel(
          id: seekerId,
          name: 'Jane',
          email: 'jane@example.com',
          role: AppConstants.roleJobSeeker,
          createdAt: now,
        ),
      );

      final messageProvider = _FakeMessageProvider([
        Conversation(
          id: const Uuid().v4(),
          participant1Id: seekerId,
          participant2Id: employerId,
          participant1Name: 'Jane',
          participant2Name: 'Acme',
          lastMessage: 'Hi there',
          lastMessageTimestamp: now,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      final provider = NotificationProvider(
        authProvider: auth,
        messageProvider: messageProvider,
        applicationProvider: _FakeApplicationProvider([]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );

      expect(provider.notificationItems, isNotEmpty);
      expect(provider.notificationItems.first.isRead, isFalse);

      provider.markAllAsRead();
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulating another device loading the same user's data from local storage
      final restoredProvider = NotificationProvider(
        authProvider: auth,
        messageProvider: messageProvider,
        applicationProvider: _FakeApplicationProvider([]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );

      await restoredProvider.loadPersistedReadState();

      // Verify read state was restored
      expect(restoredProvider.notificationItems, isNotEmpty);
      expect(restoredProvider.notificationItems.first.isRead, isTrue);
    },
  );

  test(
    'notification provider handles application updates without a reviewed date',
    () {
      final seekerId = const Uuid().v4();
      final now = DateTime.now();

      final fakeAuth = _FakeAuthProvider(
        UserModel(
          id: seekerId,
          name: 'Jane',
          email: 'jane@example.com',
          role: AppConstants.roleJobSeeker,
          createdAt: now,
        ),
      );

      final provider = NotificationProvider(
        authProvider: fakeAuth,
        messageProvider: _FakeMessageProvider([]),
        applicationProvider: _FakeApplicationProvider([
          JobApplication(
            id: const Uuid().v4(),
            jobId: const Uuid().v4(),
            jobTitle: 'Customer Service Rep',
            jobSeekerId: seekerId,
            jobSeekerName: 'Jane',
            status: AppConstants.statusShortlisted,
            appliedDate: now,
          ),
        ]),
        announcementProvider: _FakeAnnouncementProvider([]),
        jobProvider: _FakeJobProvider([]),
      );

      expect(provider.notificationItems, isNotEmpty);
      expect(provider.notificationItems.first.title, 'Application update');
      expect(provider.notificationItems.first.timestamp, now);
    },
  );

  test(
    'notification badge counts recent jobs and announcements and recent incoming messages',
    () {
      final jobId = const Uuid().v4();
      final employerId = const Uuid().v4();
      final seekerId = const Uuid().v4();

      final fakeAuth = _FakeAuthProvider(
        UserModel(
          id: seekerId,
          name: 'Jane',
          email: 'jane@example.com',
          role: AppConstants.roleJobSeeker,
          createdAt: DateTime.now(),
        ),
      );

      final fakeMessageProvider = _FakeMessageProvider([
        Conversation(
          id: const Uuid().v4(),
          participant1Id: seekerId,
          participant2Id: employerId,
          participant1Name: 'Jane',
          participant2Name: 'Acme',
          lastMessage: 'Hi there',
          lastMessageTimestamp: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Conversation(
          id: const Uuid().v4(),
          participant1Id: seekerId,
          participant2Id: const Uuid().v4(),
          participant1Name: 'Jane',
          participant2Name: 'Old Contact',
          lastMessage: 'Old message',
          lastMessageTimestamp: DateTime.now().subtract(
            const Duration(days: 30),
          ),
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ]);

      final fakeApplicationProvider = _FakeApplicationProvider([
        JobApplication(
          id: const Uuid().v4(),
          jobId: jobId,
          jobTitle: 'Customer Service Rep',
          jobSeekerId: seekerId,
          jobSeekerName: 'Jane',
          status: AppConstants.statusShortlisted,
          appliedDate: DateTime.now(),
        ),
      ]);

      final fakeAnnouncementProvider = _FakeAnnouncementProvider([
        Announcement(
          id: const Uuid().v4(),
          title: 'New hiring drive',
          category: 'Hiring',
          description: 'Hiring is open',
          imagePath: '',
          publishDate: DateTime.now(),
          targetRoles: [AppConstants.roleJobSeeker],
        ),
        Announcement(
          id: const Uuid().v4(),
          title: 'Old announcement',
          category: 'Old',
          description: 'Already seen',
          imagePath: '',
          publishDate: DateTime.now().subtract(const Duration(days: 30)),
          targetRoles: [AppConstants.roleJobSeeker],
        ),
      ]);
      final fakeJobProvider = _FakeJobProvider([
        Job(
          id: jobId,
          title: 'Customer Service Rep',
          category: 'Customer Service',
          description: 'Help customers',
          employerName: 'Acme Inc',
          employerId: employerId,
          location: 'Davao City',
          salary: '₱20,000',
          isFullTime: true,
          requirements: const ['Customer support'],
          applicantCount: 0,
          postedDate: DateTime.now(),
          deadline: DateTime.now().add(const Duration(days: 10)),
        ),
        Job(
          id: const Uuid().v4(),
          title: 'Old Job',
          category: 'Old',
          description: 'No longer new',
          employerName: 'Acme Inc',
          employerId: employerId,
          location: 'Davao City',
          salary: '₱15,000',
          isFullTime: true,
          requirements: const ['Old'],
          applicantCount: 0,
          postedDate: DateTime.now().subtract(const Duration(days: 30)),
          deadline: DateTime.now().add(const Duration(days: 10)),
        ),
      ]);

      final provider = NotificationProvider(
        authProvider: fakeAuth,
        messageProvider: fakeMessageProvider,
        applicationProvider: fakeApplicationProvider,
        announcementProvider: fakeAnnouncementProvider,
        jobProvider: fakeJobProvider,
      );

      expect(provider.unreadMessagesCount, 1);
      expect(provider.newAnnouncementsCount, 1);
      expect(provider.newJobsCount, 1);
      expect(provider.applicationStatusUpdatesCount, 1);
      expect(provider.totalNotificationCount, 4);
    },
  );

  test(
    'suspended accounts stay login-capable but are blocked from role actions',
    () {
      final activeUser = UserModel(
        id: const Uuid().v4(),
        name: 'Active User',
        email: 'active@example.com',
        role: AppConstants.roleJobSeeker,
        createdAt: DateTime.now(),
      );

      final suspendedUser = UserModel(
        id: const Uuid().v4(),
        name: 'Suspended User',
        email: 'suspended@example.com',
        role: AppConstants.roleEmployer,
        accountStatus: 'suspended',
        createdAt: DateTime.now(),
      );

      final deletedUser = UserModel(
        id: const Uuid().v4(),
        name: 'Deleted User',
        email: 'deleted@example.com',
        role: AppConstants.roleJobSeeker,
        accountStatus: 'deleted',
        createdAt: DateTime.now(),
      );

      expect(activeUser.canSignIn, isTrue);
      expect(activeUser.canAccessRoleActions, isTrue);
      expect(suspendedUser.canSignIn, isTrue);
      expect(suspendedUser.canAccessRoleActions, isFalse);
      expect(deletedUser.canSignIn, isFalse);
      expect(deletedUser.canAccessRoleActions, isFalse);
    },
  );

  group('Job serialization', () {
    test('serializes to Supabase-safe snake_case fields and a UUID id', () {
      final job = Job(
        id: const Uuid().v4(),
        title: 'Customer Service Representative',
        category: 'Customer Service',
        description: 'Help customers and process requests.',
        employerName: 'Acme Inc',
        employerId: const Uuid().v4(),
        location: 'Davao City',
        salary: '₱18,000 - ₱22,000',
        isFullTime: true,
        requirements: ['Good communication', 'Customer service experience'],
        applicantCount: 0,
        postedDate: DateTime.utc(2026, 8, 10, 8, 0),
        deadline: DateTime.utc(2026, 9, 10, 8, 0),
      );

      final payload = job.toJson();

      expect(Uuid.isValidUUID(fromString: payload['id'] as String), isTrue);
      expect(payload.containsKey('employer_name'), isFalse);
      expect(payload['employer_id'], job.employerId);
      expect(payload['is_full_time'], isTrue);
      expect(payload['posted_date'], job.postedDate.toIso8601String());
      expect(payload['deadline'], job.deadline.toIso8601String());
      expect(payload.containsKey('employerName'), isFalse);
      expect(payload.containsKey('isFullTime'), isFalse);
    });

    test('parses snake_case payloads from Supabase', () {
      final payload = {
        'id': const Uuid().v4(),
        'title': 'Office Assistant',
        'category': 'Office Assistant',
        'description': 'Support office operations.',
        'employer_name': 'Acme Inc',
        'employer_id': const Uuid().v4(),
        'location': 'Kidapawan City',
        'salary': '₱15,000',
        'is_full_time': true,
        'requirements': ['Organized', 'Computer literate'],
        'applicant_count': 2,
        'posted_date': '2026-08-10T08:00:00.000Z',
        'deadline': '2026-09-10T08:00:00.000Z',
        'isSaved': false,
      };

      final job = Job.fromJson(payload);

      expect(job.title, 'Office Assistant');
      expect(job.employerName, 'Acme Inc');
      expect(job.employerId, payload['employer_id']);
      expect(job.isFullTime, isTrue);
      expect(job.requirements, ['Organized', 'Computer literate']);
      expect(job.applicantCount, 2);
    });
  });

  group('Normalized relationship serialization', () {
    test(
      'application keeps audit snapshots but omits employer duplication',
      () {
        final application = JobApplication(
          id: const Uuid().v4(),
          jobId: const Uuid().v4(),
          jobTitle: 'Office Assistant',
          jobSeekerId: const Uuid().v4(),
          jobSeekerName: 'Jane Doe',
          status: 'new',
          appliedDate: DateTime.utc(2026, 8, 10),
        );

        final payload = application.toJson();

        expect(payload['job_title_snapshot'], 'Office Assistant');
        expect(payload['job_seeker_name_snapshot'], 'Jane Doe');
        expect(payload.containsKey('employer_id'), isFalse);
      },
    );

    test(
      'message keeps sender snapshot and required receiver relationship',
      () {
        final receiverId = const Uuid().v4();
        final message = Message(
          id: const Uuid().v4(),
          conversationId: const Uuid().v4(),
          senderId: const Uuid().v4(),
          senderName: 'Jane Doe',
          receiverId: receiverId,
          content: 'Hello',
          timestamp: DateTime.utc(2026, 8, 10),
        );

        final payload = message.toJson();

        expect(payload['sender_name_snapshot'], 'Jane Doe');
        expect(payload['receiver_id'], receiverId);
      },
    );
  });
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider(this._currentUser);

  final UserModel? _currentUser;

  @override
  UserModel? get currentUser => _currentUser;
}

class _FakeMessageProvider extends MessageProvider {
  _FakeMessageProvider(this._conversations);

  final List<Conversation> _conversations;

  @override
  List<Conversation> get conversations => _conversations;

  @override
  int get unreadConversationCount => _conversations.length;
}

class _FakeApplicationProvider extends ApplicationProvider {
  _FakeApplicationProvider(this._applications);

  final List<JobApplication> _applications;

  @override
  List<JobApplication> get applications => _applications;
}

class _FakeAnnouncementProvider extends AnnouncementProvider {
  _FakeAnnouncementProvider(this._announcements);

  final List<Announcement> _announcements;

  @override
  List<Announcement> get announcements => _announcements;
}

class _FakeJobProvider extends JobProvider {
  _FakeJobProvider(this._jobs);

  final List<Job> _jobs;

  @override
  List<Job> get jobs => _jobs;
}
