import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensdroid/views/pages/dashboard_page.dart';
import 'package:sensdroid/views/pages/statistics_page.dart';

/// Main navigation page with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const StatisticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: colorScheme.primary.withOpacity(0.2),
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined, 
                      color: colorScheme.onSurface.withOpacity(0.6)),
                    selectedIcon: Icon(Icons.dashboard_rounded, 
                      color: colorScheme.primary),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.analytics_outlined,
                      color: colorScheme.onSurface.withOpacity(0.6)),
                    selectedIcon: Icon(Icons.analytics_rounded,
                      color: colorScheme.primary),
                    label: 'Statistics',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
