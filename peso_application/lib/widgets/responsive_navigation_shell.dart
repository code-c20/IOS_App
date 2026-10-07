import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'user_avatar.dart';

class NavigationDestinationItem {
  const NavigationDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class NavigationRailAction {
  const NavigationRailAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class ResponsiveNavigationShell extends StatelessWidget {
  const ResponsiveNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
    this.accentColor = const Color(0xFF1A7CFF),
    this.railColor = const Color(0xFF092B55),
    this.bottomNavigationColor = const Color(0xFF0B1F3A),
    this.accountLabel = 'ACCOUNT',
    this.railActions = const [],
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget child;
  final Color accentColor;
  final Color railColor;
  final Color bottomNavigationColor;
  final String accountLabel;
  final List<NavigationRailAction> railActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        if (!useRail) {
          return Scaffold(
            body: child,
            bottomNavigationBar: _bottomNavigationBar(),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _sideNavigationBar(context),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _sideNavigationBar(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'Account user';
    return Container(
      width: 238,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: railColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_center, color: accentColor),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'WorkNests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                UserAvatar(
                  name: name,
                  imageUrl: user?.profileImage,
                  radius: 30,
                  backgroundColor: Colors.white,
                  foregroundColor: railColor,
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  accountLabel
                      .replaceAll(' ACCOUNT', '')
                      .toLowerCase()
                      .split(' ')
                      .map(
                        (word) => word.isEmpty
                            ? word
                            : '${word[0].toUpperCase()}${word.substring(1)}',
                      )
                      .join(' '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              accountLabel,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Expanded(
            child: ListView.separated(
              itemCount: destinations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = currentIndex == index;
                return InkWell(
                  onTap: () => onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          color: selected ? Colors.white : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),
          for (final action in railActions)
            InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(action.icon, color: Colors.white70, size: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              'Connecting opportunities.\nBuilding futures.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavigationBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            backgroundColor: bottomNavigationColor,
            selectedItemColor: const Color(0xFFFF9F43),
            unselectedItemColor: const Color(0xFFB7C4D8),
            elevation: 8,
            onTap: onDestinationSelected,
            items: [
              for (final destination in destinations)
                BottomNavigationBarItem(
                  icon: Icon(destination.icon),
                  activeIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
