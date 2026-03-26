import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class BuyerShell extends StatelessWidget {
  final Widget child;
  const BuyerShell({super.key, required this.child});

  int _getIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/buyer/map')) return 1;
    if (location.startsWith('/buyer/reservations')) return 2;
    if (location.startsWith('/buyer/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _getIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            switch (i) {
              case 0: context.go('/buyer/home');
              case 1: context.go('/buyer/map');
              case 2: context.go('/buyer/reservations');
              case 3: context.go('/buyer/profile');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Reservations'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
