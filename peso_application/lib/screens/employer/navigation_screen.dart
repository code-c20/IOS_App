import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';
import 'applicants_screen.dart';
import 'messages_screen.dart';
import '../announcement_screen.dart';
import 'profile_screen.dart';
import '../../widgets/responsive_navigation_shell.dart';
import 'create_job_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/navigation_state_service.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';

class EmployerNavigationScreen extends StatefulWidget {
  const EmployerNavigationScreen({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<EmployerNavigationScreen> createState() =>
      _EmployerNavigationScreenState();
}

class _EmployerNavigationScreenState extends State<EmployerNavigationScreen> {
  late int _currentIndex;

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    if (widget.initialIndex == null) Future.microtask(_restoreLastTab);
    screens = [
      const EmployerHomeScreen(),
      const EmployerJobsScreen(),
      const EmployerApplicantsScreen(),
      const EmployerMessagesScreen(),
      EmployerProfileScreen(
        onNavigate: (index) {
          _selectTab(index);
        },
      ),
    ];
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
      accentColor: const Color(AppConstants.primaryColor),
      railColor: const Color(0xFF0A5BC7),
      bottomNavigationColor: const Color(0xFF0A5BC7),
      accountLabel: 'EMPLOYER ACCOUNT',
      destinations: const [
        NavigationDestinationItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        NavigationDestinationItem(
          label: 'Jobs',
          icon: Icons.business_center_outlined,
          selectedIcon: Icons.business_center,
        ),
        NavigationDestinationItem(
          label: 'Applications',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
        ),
        NavigationDestinationItem(
          label: 'Messages',
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
        ),
        NavigationDestinationItem(
          label: 'Profile',
          icon: Icons.account_circle_outlined,
          selectedIcon: Icons.account_circle,
        ),
      ],
      railActions: [
        NavigationRailAction(
          label: 'Post a Job',
          icon: Icons.post_add_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmployerCreateJobScreen()),
          ),
        ),
        NavigationRailAction(
          label: 'Manage Jobs',
          icon: Icons.assignment_outlined,
          onTap: () => _selectTab(1),
        ),
        NavigationRailAction(
          label: 'Candidates',
          icon: Icons.people_outline,
          onTap: () => _selectTab(2),
        ),
        NavigationRailAction(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AnnouncementScreen())),
        ),
        NavigationRailAction(
          label: 'Company Profile',
          icon: Icons.business_outlined,
          onTap: () => _selectTab(4),
        ),
        NavigationRailAction(
          label: 'Settings',
          icon: Icons.settings_outlined,
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
      child: IndexedStack(index: _currentIndex, children: screens),
    );
  }
}
