import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/listing_card.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final listingsAsync = ref.watch(sellerListingsProvider(user.uid));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('My Listings',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    onPressed: () => context.go('/seller/create-listing'),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(label: 'All', isSelected: _filterStatus == null, onTap: () => setState(() => _filterStatus = null)),
                  _FilterChip(label: 'Active', isSelected: _filterStatus == 'active', onTap: () => setState(() => _filterStatus = 'active')),
                  _FilterChip(label: 'Threshold', isSelected: _filterStatus == 'threshold_reached', onTap: () => setState(() => _filterStatus = 'threshold_reached')),
                  _FilterChip(label: 'Confirmed', isSelected: _filterStatus == 'confirmed', onTap: () => setState(() => _filterStatus = 'confirmed')),
                  _FilterChip(label: 'Cancelled', isSelected: _filterStatus == 'cancelled', onTap: () => setState(() => _filterStatus = 'cancelled')),
                  _FilterChip(label: 'Completed', isSelected: _filterStatus == 'completed', onTap: () => setState(() => _filterStatus = 'completed')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: listingsAsync.when(
                data: (listings) {
                  final filtered = _filterStatus == null
                      ? listings
                      : listings.where((l) => l.status == _filterStatus).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No listings found', style: TextStyle(color: AppTheme.textTertiary)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => ListingCard(
                      listing: filtered[i],
                      showSellerInfo: false,
                      onTap: () => context.go('/seller/listing/${filtered[i].id}'),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        )),
      ),
    );
  }
}
