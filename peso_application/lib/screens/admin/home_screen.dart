import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../widgets/user_avatar.dart';
import 'jobs_management_screen.dart';
import '../notification_center_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, this.onNavigateToTab});

  final void Function(int index)? onNavigateToTab;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  int _userCount = 0;
  int _employerCount = 0;
  int _jobCount = 0;
  int _announcementCount = 0;
  int _reportCount = 0;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshDashboardData(),
    );
  }

  Future<void> _refreshDashboardData() async {
    final user = context.read<AuthProvider>().currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final stats = await _supabaseService.fetchAdminDashboardStats();
      if (!mounted) return;

      setState(() {
        _userCount = stats['users']!;
        _employerCount = stats['employers']!;
        _jobCount = stats['jobs']!;
        _announcementCount = stats['announcements']!;
        _reportCount = stats['reports']!;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    try {
      await context.read<MessageProvider>().loadConversations(user.id);
    } catch (error) {
      debugPrint('Unable to load admin dashboard conversations: $error');
    }
  }

  String _metricValue(int value) {
    if (_isLoading) return '…';
    if (_loadError != null) return '!';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.name ?? 'Admin';
    final firstName = name.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B1F3A), Color(0xFF0F3D7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: AppBar(
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0B1F3A), Color(0xFF0F3D7A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            name:
                                context
                                    .read<AuthProvider>()
                                    .currentUser
                                    ?.name ??
                                '',
                            imageUrl: context
                                .read<AuthProvider>()
                                .currentUser
                                ?.profileImage,
                            radius: 26,
                            backgroundColor: Colors.white.withAlpha(30),
                            foregroundColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$firstName!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Platform control center',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context
                                  .read<NotificationProvider>()
                                  .markAllAsRead();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationCenterScreen(),
                                ),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                Consumer<NotificationProvider>(
                                  builder:
                                      (context, notificationProvider, child) {
                                        final unreadCount = notificationProvider
                                            .totalNotificationCount;
                                        if (unreadCount == 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF3B30),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Manage users, announcements, reports, and moderation updates from one dashboard.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_loadError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard statistics could not be loaded.',
                          style: TextStyle(
                            color: Color(0xFF9B1C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _loadError!,
                          style: const TextStyle(
                            color: Color(0xFF9B1C1C),
                            fontSize: 12,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _refreshDashboardData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                _AdminOverviewCard(
                  users: _metricValue(_userCount),
                  employers: _metricValue(_employerCount),
                  jobs: _metricValue(_jobCount),
                  onViewUsers: () => widget.onNavigateToTab?.call(1),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const actionWidth = 142.0;

                    return Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: actionWidth,
                                child: _AdminActionCard(
                                  icon: Icons.people,
                                  label: 'Users',
                                  onTap: () => widget.onNavigateToTab?.call(1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: actionWidth,
                                child: _AdminActionCard(
                                  icon: Icons.campaign,
                                  label: 'Announcements',
                                  onTap: () => widget.onNavigateToTab?.call(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: actionWidth,
                                child: _AdminActionCard(
                                  icon: Icons.analytics,
                                  label: 'Reports',
                                  onTap: () => widget.onNavigateToTab?.call(3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: actionWidth,
                                child: _AdminActionCard(
                                  icon: Icons.work_outline,
                                  label: 'My Jobs',
                                  value: _metricValue(_jobCount),
                                  accentColor: const Color(
                                    AppConstants.adminColor,
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminJobsManagementScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: _AdminMetricCard(
                                icon: Icons.people_alt_rounded,
                                label: 'Users',
                                value: _metricValue(_userCount),
                                color: const Color(0xFFECF7FF),
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: _AdminMetricCard(
                                icon: Icons.campaign_rounded,
                                label: 'Announcements',
                                value: _metricValue(_announcementCount),
                                color: const Color(0xFFEFFAF2),
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: _AdminMetricCard(
                                icon: Icons.report_problem_rounded,
                                label: 'Reports',
                                value: _metricValue(_reportCount),
                                color: const Color(0xFFFFF5E6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AdminMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(AppConstants.primaryColor)),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1F2A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewCard extends StatelessWidget {
  const _AdminOverviewCard({
    required this.users,
    required this.employers,
    required this.jobs,
    required this.onViewUsers,
  });

  final String users;
  final String employers;
  final String jobs;
  final VoidCallback onViewUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1F3A), Color(0xFF0F3D7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3D7A).withAlpha(38),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Platform activity at a glance',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewUsers,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('View users'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AdminOverviewMetric(label: 'Total users', value: users),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminOverviewMetric(
                  label: 'Employers',
                  value: employers,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminOverviewMetric(label: 'Job posts', value: jobs),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewMetric extends StatelessWidget {
  const _AdminOverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color accentColor;
  final VoidCallback? onTap;

  const _AdminActionCard({
    required this.icon,
    required this.label,
    this.value,
    this.accentColor = const Color(AppConstants.primaryColor),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1C1F2A),
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value!,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
