import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4), width: 3),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('Maria Ivanova',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                  SizedBox(width: 4),
                  Text('Sofia', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 28),

              // Stats
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Orders', value: '12', icon: Icons.shopping_bag_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Reviews', value: '8', icon: Icons.rate_review_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Saved', value: '5', icon: Icons.bookmark_outline)),
                ],
              ),
              const SizedBox(height: 28),

              // Menu items
              _MenuItem(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () {}),
              _MenuItem(icon: Icons.receipt_long, label: 'Reservation History', onTap: () {}),
              _MenuItem(icon: Icons.favorite_outline, label: 'Saved Sellers', onTap: () {}),
              _MenuItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
              _MenuItem(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
              _MenuItem(
                icon: Icons.logout,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentGreen, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: glassDecoration(),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDestructive ? AppTheme.statusCancelled : AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500,
              color: isDestructive ? AppTheme.statusCancelled : AppTheme.textPrimary,
            ))),
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
