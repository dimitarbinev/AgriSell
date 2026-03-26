import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/providers/providers.dart';

class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const Text('Ivan Petrov',
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
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RatingStars(rating: 4.7, size: 20),
                  SizedBox(width: 8),
                  Text('4.7', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(width: 4),
                  Text('(23 reviews)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 28),

              // Stats
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Completed', value: '47', icon: Icons.check_circle_outline)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Cancel Rate', value: '4%', icon: Icons.cancel_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Products', value: '8', icon: Icons.eco)),
                ],
              ),
              const SizedBox(height: 28),

              // Menu items
              _MenuItem(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () {}),
              _MenuItem(icon: Icons.inventory_2_outlined, label: 'My Products', onTap: () {}),
              _MenuItem(icon: Icons.history, label: 'Order History', onTap: () {}),
              _MenuItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
              _MenuItem(
                icon: Icons.shopping_bag_outlined,
                label: 'Switch to Buyer',
                onTap: () async {
                  try {
                    await ref.read(userRoleProvider.notifier).switchRole('buyer');
                    if (context.mounted) {
                      context.go('/buyer/home');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to switch role: $e')),
                      );
                    }
                  }
                },
              ),
              _MenuItem(
                icon: Icons.logout,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
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
