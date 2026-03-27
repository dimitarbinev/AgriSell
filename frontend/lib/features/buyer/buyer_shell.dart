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
    if (location.startsWith('/buyer/profile') || location.contains('saved-sellers')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _getIndex(context);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface.withValues(alpha: 0.85),
          border: Border(top: BorderSide(color: AppTheme.accentGreen.withValues(alpha: 0.15))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
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
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Начало'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Карта'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Резервации'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Профил'),
          ],
        ),
      ),
    );
  }
}
