import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../events/ui/explore_screen.dart';
import '../events/ui/my_events_screen.dart';
import '../home/home_placeholder_screen.dart';

/// The signed in app: four bottom tabs (Explore, My Events, Alerts, Profile).
///
/// IndexedStack keeps every tab alive, so switching tabs never loses the
/// Explore search/filters or the scroll position of a list.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const ExploreScreen(),
          MyEventsScreen(onBrowse: () => setState(() => _index = 0)),
          const _ComingSoonTab(title: 'Alerts'),
          const HomePlaceholderScreen(), // Profile: replaced by the profile feature.
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'My Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '$title will be built next.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
