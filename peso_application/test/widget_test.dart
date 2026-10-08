// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:peso_application/main.dart';
import 'package:peso_application/models/application.dart';
import 'package:peso_application/models/job.dart';
import 'package:peso_application/models/user.dart';
import 'package:peso_application/providers/announcement_provider.dart';
import 'package:peso_application/providers/application_provider.dart';
import 'package:peso_application/providers/auth_provider.dart';
import 'package:peso_application/providers/job_provider.dart';
import 'package:peso_application/providers/message_provider.dart';
import 'package:peso_application/providers/notification_provider.dart';
import 'package:peso_application/screens/employer/home_screen.dart';
import 'package:peso_application/screens/employer/profile_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class TestAuthProvider extends AuthProvider {
  UserModel? _testUser;

  void setCurrentUser(UserModel user) => _testUser = user;

  @override
  UserModel? get currentUser => _testUser;
}

class TestJobProvider extends JobProvider {
  List<Job> _testJobs = const [];

  void setJobs(List<Job> jobs) => _testJobs = jobs;

  @override
  List<Job> get jobs => _testJobs;
}

class TestApplicationProvider extends ApplicationProvider {
  List<JobApplication> _testApplications = const [];

  void setApplications(List<JobApplication> applications) =>
      _testApplications = applications;

  @override
  List<JobApplication> get applications => _testApplications;
}

void main() {
  testWidgets('app loads the login screen by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('application feedback closes after five seconds', (
    WidgetTester tester,
  ) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            messenger = ScaffoldMessenger.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    messenger.showAppSnackBar(
      const SnackBar(content: Text('Temporary feedback')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Temporary feedback'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Temporary feedback'), findsNothing);
  });

  testWidgets('employer dashboard renders a branded hiring overview', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final authProvider = AuthProvider();
    final jobProvider = JobProvider();
    final appProvider = ApplicationProvider();
    final announcementProvider = AnnouncementProvider();
    final messageProvider = MessageProvider();
    final notificationProvider = NotificationProvider(
      authProvider: authProvider,
      messageProvider: messageProvider,
      applicationProvider: appProvider,
      announcementProvider: announcementProvider,
      jobProvider: jobProvider,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<JobProvider>.value(value: jobProvider),
          ChangeNotifierProvider<ApplicationProvider>.value(value: appProvider),
          ChangeNotifierProvider<AnnouncementProvider>.value(
            value: announcementProvider,
          ),
          ChangeNotifierProvider<MessageProvider>.value(value: messageProvider),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: notificationProvider,
          ),
        ],
        child: const MaterialApp(home: EmployerHomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Hiring overview'), findsOneWidget);
    expect(find.text('Employer'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Post Job')).dy,
      tester.getTopLeft(find.text('Applicants')).dy,
    );
    expect(
      tester.getTopLeft(find.text('New')).dy,
      tester.getTopLeft(find.text('Shortlisted')).dy,
    );
  });

  testWidgets('employer profile shows live job and applicant totals', (
    WidgetTester tester,
  ) async {
    final authProvider = TestAuthProvider();
    authProvider.setCurrentUser(
      UserModel(
        id: 'emp-1',
        name: 'Acme Hiring',
        email: 'acme@example.com',
        role: 'employer',
        createdAt: DateTime.now(),
      ),
    );

    final jobProvider = TestJobProvider();
    jobProvider.setJobs([
      Job(
        id: 'job-1',
        title: 'QA Engineer',
        category: 'Technology',
        description: 'desc',
        employerName: 'Acme Hiring',
        employerId: 'emp-1',
        location: 'Cebu',
        salary: '120000',
        isFullTime: true,
        requirements: const ['Testing'],
        applicantCount: 3,
        postedDate: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 7)),
      ),
      Job(
        id: 'job-2',
        title: 'Designer',
        category: 'Design',
        description: 'desc',
        employerName: 'Acme Hiring',
        employerId: 'emp-1',
        location: 'Davao',
        salary: '90000',
        isFullTime: true,
        requirements: const ['Figma'],
        applicantCount: 2,
        postedDate: DateTime.now(),
        deadline: DateTime.now().add(const Duration(days: 10)),
      ),
    ]);

    final appProvider = TestApplicationProvider();
    appProvider.setApplications([
      JobApplication(
        id: 'app-1',
        jobId: 'job-1',
        jobTitle: 'QA Engineer',
        jobSeekerId: 'seek-1',
        jobSeekerName: 'Jane',
        status: 'new',
        appliedDate: DateTime.now(),
      ),
      JobApplication(
        id: 'app-2',
        jobId: 'job-2',
        jobTitle: 'Designer',
        jobSeekerId: 'seek-2',
        jobSeekerName: 'John',
        status: 'shortlisted',
        appliedDate: DateTime.now(),
      ),
      JobApplication(
        id: 'app-3',
        jobId: 'job-2',
        jobTitle: 'Designer',
        jobSeekerId: 'seek-3',
        jobSeekerName: 'Ana',
        status: 'accepted',
        appliedDate: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<JobProvider>.value(value: jobProvider),
          ChangeNotifierProvider<ApplicationProvider>.value(value: appProvider),
        ],
        child: MaterialApp(home: EmployerProfileScreen(onNavigate: (_) {})),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
