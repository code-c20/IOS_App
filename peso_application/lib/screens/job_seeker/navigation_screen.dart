import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';
import 'applications_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import '../../widgets/responsive_navigation_shell.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/navigation_state_service.dart';
import '../../utils/constants.dart';

class JobSeekerNavigationScreen extends StatefulWidget {
  /// [initialIndex] allows launching this navigation screen focused on a
  /// particular tab (e.g. 1 = Job Search, 2 = Applications).
  const JobSeekerNavigationScreen({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<JobSeekerNavigationScreen> createState() =>
      _JobSeekerNavigationScreenState();
}

class _JobSeekerNavigationScreenState extends State<JobSeekerNavigationScreen> {
  late int _currentIndex;

  late final List<Widget> screens = [
    const JobSeekerHomeScreen(),
    const JobsScreen(),
    const ApplicationsScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    if (widget.initialIndex == null) Future.microtask(_restoreLastTab);
  }

  Future<void> _restoreLastTab() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final savedTab = await NavigationStateService.loadTab(
      userId: user.id,
      role: user.role,
    );
    if (!mounted || savedTab == null || savedTab >= screens.length) return;
    setState(() => _currentIndex = savedTab);
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      unawaited(
        NavigationStateService.saveTab(
          userId: user.id,
          role: user.role,
          tab: index,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavigationShell(
      currentIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      accentColor: const Color(AppConstants.jobSeekerColor),
      railColor: const Color(0xFF075443),
      bottomNavigationColor: const Color(0xFF075443),
      accountLabel: 'JOB SEEKER ACCOUNT',
      railActions: [
        NavigationRailAction(
          label: 'Resume Builder',
          icon: Icons.description_outlined,
          onTap: () => _selectTab(4),
        ),
        NavigationRailAction(
          label: 'Career Settings',
          icon: Icons.tune_rounded,
          onTap: () => _selectTab(4),
        ),
        NavigationRailAction(
          label: 'Logout',
          icon: Icons.logout_outlined,
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (_) => false);
          },
        ),
      ],
      destinations: const [
        NavigationDestinationItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        NavigationDestinationItem(
          label: 'Jobs',
          icon: Icons.search_rounded,
          selectedIcon: Icons.search_rounded,
        ),
        NavigationDestinationItem(
          label: 'Applications',
          icon: Icons.work_history_outlined,
          selectedIcon: Icons.work_history,
        ),
        NavigationDestinationItem(
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
        ),
        NavigationDestinationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
        ),
      ],
      child: IndexedStack(index: _currentIndex, children: screens),
    );
  }
}
