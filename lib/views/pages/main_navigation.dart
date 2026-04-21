import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensdroid/views/pages/dashboard_page.dart';
import 'package:sensdroid/views/pages/sensors_page.dart';
import 'package:sensdroid/views/pages/statistics/statistics_page.dart';

/// Main navigation with 3 tabs: Dashboard, Sensors, Statistics.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    SensorsPage(),
    StatisticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onSelected: (i) => setState(() => _currentIndex = i),
        colorScheme: colorScheme,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ColorScheme colorScheme;

  const _BottomNav({
    required this.currentIndex,
    required this.onSelected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withOpacity(0.12),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: colorScheme.surface.withOpacity(0.85),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelected,
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 68,
              animationDuration: const Duration(milliseconds: 300),
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    Icons.dashboard_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    Icons.dashboard_rounded,
                    color: colorScheme.primary,
                  ),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.sensors_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    Icons.sensors_rounded,
                    color: colorScheme.primary,
                  ),
                  label: 'Sensors',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.analytics_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    Icons.analytics_rounded,
                    color: colorScheme.primary,
                  ),
                  label: 'Statistics',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
