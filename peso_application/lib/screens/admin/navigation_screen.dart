import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'users_management_screen.dart';
import 'announcements_management_screen.dart';
import 'reports_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import '../../widgets/responsive_navigation_shell.dart';
import '../../providers/auth_provider.dart';
import '../../services/navigation_state_service.dart';
import 'package:provider/provider.dart';
import 'create_job_screen.dart';

class AdminNavigationScreen extends StatefulWidget {
  /// [initialIndex] allows launching this navigation screen focused on a
  /// particular tab (e.g. 1 = Users, 2 = Announcements).
  const AdminNavigationScreen({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<AdminNavigationScreen> createState() => _AdminNavigationScreenState();
}

class _AdminNavigationScreenState extends State<AdminNavigationScreen> {
  late int _currentIndex;

  late final List<Widget> screens = [
    AdminHomeScreen(onNavigateToTab: _selectTab),
    const UsersManagementScreen(),
    const AnnouncementsManagementScreen(),
    const ReportsScreen(),
    const MessagesScreen(),
    AdminProfileScreen(onNavigate: _selectTab),
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
      accentColor: const Color(0xFF0F3D7A),
      railColor: const Color(0xFF0B1F3A),
      accountLabel: 'ADMIN ACCOUNT',
      destinations: const [
        NavigationDestinationItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        NavigationDestinationItem(
          label: 'Users',
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
        ),
        NavigationDestinationItem(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
        ),
        NavigationDestinationItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
        ),
        NavigationDestinationItem(
          label: 'Messages',
          icon: Icons.mark_email_unread_outlined,
          selectedIcon: Icons.mark_email_unread,
        ),
        NavigationDestinationItem(
          label: 'Profile',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield,
        ),
      ],
      railActions: [
        NavigationRailAction(
          label: 'Post a Job',
          icon: Icons.post_add_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminCreateJobScreen()),
          ),
        ),
        NavigationRailAction(
          label: 'Employers',
          icon: Icons.business_outlined,
          onTap: () => _selectTab(1),
        ),
        NavigationRailAction(
          label: 'Job Posts',
          icon: Icons.work_outline,
          onTap: () => _selectTab(0),
        ),
        NavigationRailAction(
          label: 'System Settings',
          icon: Icons.settings_outlined,
          onTap: () => _selectTab(5),
        ),
        NavigationRailAction(
          label: 'Audit Logs',
          icon: Icons.receipt_long_outlined,
          onTap: () => _selectTab(3),
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
