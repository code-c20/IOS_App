import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/job_provider.dart';
import 'providers/application_provider.dart';
import 'providers/message_provider.dart';
import 'providers/announcement_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/email_verified_screen.dart';
import 'screens/job_seeker/navigation_screen.dart' as job_seeker;
import 'screens/employer/navigation_screen.dart';
import 'screens/admin/navigation_screen.dart';
import 'services/supabase_service.dart';

bool isEmailVerificationCallback(Uri uri) {
  if (uri.scheme == 'worknest' && uri.host == 'email-verified') {
    return true;
  }

  if (uri.path == '/email-verified') return true;
  return Uri.tryParse(uri.fragment)?.path == '/email-verified';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService().initialize();

  final initialUri = kIsWeb ? Uri.base : await AppLinks().getInitialLink();
  final openedFromEmailVerification =
      initialUri != null && isEmailVerificationCallback(initialUri);

  runApp(
    MyApp(
      showSplash: !openedFromEmailVerification,
      showEmailVerified: openedFromEmailVerification,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.showSplash = false,
    this.showEmailVerified = false,
  });

  final bool showSplash;
  final bool showEmailVerified;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showEmailVerified;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _showEmailVerified = widget.showEmailVerified;
    if (!kIsWeb) {
      _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
        if (isEmailVerificationCallback(uri)) {
          setState(() => _showEmailVerified = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, JobProvider>(
          create: (_) => JobProvider(),
          update: (_, authProvider, jobProvider) {
            final provider = jobProvider ?? JobProvider();
            provider.setUserId(authProvider.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProxyProvider5<
          AuthProvider,
          MessageProvider,
          ApplicationProvider,
          AnnouncementProvider,
          JobProvider,
          NotificationProvider
        >(
          create: (context) => NotificationProvider(
            authProvider: context.read<AuthProvider>(),
            messageProvider: context.read<MessageProvider>(),
            applicationProvider: context.read<ApplicationProvider>(),
            announcementProvider: context.read<AnnouncementProvider>(),
            jobProvider: context.read<JobProvider>(),
          ),
          update:
              (
                _,
                authProvider,
                messageProvider,
                appProvider,
                announcementProvider,
                jobProvider,
                previous,
              ) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'WorkNests',
        theme: AppTheme.lightTheme(),
        debugShowCheckedModeBanner: false,
        home: _showEmailVerified
            ? const EmailVerifiedScreen()
            : AuthCheckScreen(showSplash: widget.showSplash),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/jobs': (context) => const AuthCheckScreen(jobSeekerInitialIndex: 1),
          '/applications': (context) =>
              const AuthCheckScreen(jobSeekerInitialIndex: 2),
          // AuthCheckScreen chooses the correct dashboard from the profile role.
          '/home': (context) => const AuthCheckScreen(),
          '/role-selection': (context) => const RoleSelectionScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
          '/email-verified': (context) => const EmailVerifiedScreen(),
        },
        onGenerateRoute: (settings) {
          final routeUri = Uri.tryParse(settings.name ?? '');
          final routeName = routeUri?.path ?? settings.name;

          if (routeName == '/email-verified') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const EmailVerifiedScreen(),
            );
          }
          if (routeName == '/reset-password') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const ResetPasswordScreen(),
            );
          }
          if (routeName == '/signup') {
            final args = settings.arguments as String?;
            // Admin accounts are provisioned privately, never from this route.
            if (args == AppConstants.roleAdmin) {
              return MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (context) =>
                  SignUpScreen(role: args ?? AppConstants.roleJobSeeker),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({
    super.key,
    this.showSplash = false,
    this.jobSeekerInitialIndex = 0,
  });

  final bool showSplash;
  final int jobSeekerInitialIndex;

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.showSplash;
    // Load stored user session on app start
    Future.microtask(() {
      if (!mounted) return;
      context.read<AuthProvider>().loadStoredUser();
    });
  }

  void _dismissSplash() {
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final Widget destination;
        if (authProvider.currentUser == null) {
          destination = const LoginScreen();
        } else {
          // Route to appropriate screen based on role
          final role = authProvider.currentUser!.role;
          switch (role) {
            case AppConstants.roleJobSeeker:
              destination = job_seeker.JobSeekerNavigationScreen(
                initialIndex: widget.jobSeekerInitialIndex,
              );
              break;
            case AppConstants.roleEmployer:
              destination = const EmployerNavigationScreen();
              break;
            case AppConstants.roleAdmin:
              destination = const AdminNavigationScreen();
              break;
            default:
              destination = const LoginScreen();
          }
        }

        final protectedDestination = authProvider.currentUser == null
            ? destination
            : SessionTimeout(child: destination);

        return Stack(
          fit: StackFit.expand,
          children: [
            protectedDestination,
            if (_showSplash) SplashScreen(onComplete: _dismissSplash),
          ],
        );
      },
    );
  }
}

class SessionTimeout extends StatefulWidget {
  const SessionTimeout({super.key, required this.child});

  final Widget child;

  @override
  State<SessionTimeout> createState() => _SessionTimeoutState();
}

class _SessionTimeoutState extends State<SessionTimeout> {
  static const _idleLimit = Duration(minutes: 5);
  static const _warningLimit = Duration(seconds: 30);

  Timer? _idleTimer;
  Timer? _warningTimer;
  int _remainingSeconds = _warningLimit.inSeconds;
  late final ValueNotifier<int> _remainingNotifier = ValueNotifier(
    _remainingSeconds,
  );
  bool _warningVisible = false;

  @override
  void initState() {
    super.initState();
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleLimit, _showTimeoutWarning);
  }

  void _handleActivity() {
    if (_warningVisible) {
      _warningTimer?.cancel();
      _warningVisible = false;
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
    _restartIdleTimer();
  }

  void _showTimeoutWarning() {
    if (!mounted || _warningVisible) return;
    _warningVisible = true;
    _remainingSeconds = _warningLimit.inSeconds;
    _warningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _remainingNotifier.value = --_remainingSeconds;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _logoutForInactivity();
      }
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you still there?'),
        content: ValueListenableBuilder<int>(
          valueListenable: _remainingNotifier,
          builder: (context, seconds, _) => Text(
            'You have been inactive. You will be signed out in '
            '$seconds seconds for your security.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _logoutForInactivity,
            child: const Text('Log out now'),
          ),
          FilledButton.icon(
            onPressed: _handleActivity,
            icon: const Icon(Icons.touch_app_outlined),
            label: const Text('Stay signed in'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutForInactivity() async {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    _warningVisible = false;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    await context.read<AuthProvider>().logout();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    _remainingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, _) {
        _handleActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _handleActivity(),
        onPointerSignal: (_) => _handleActivity(),
        child: widget.child,
      ),
    );
  }
}
