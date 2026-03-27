import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/providers/providers.dart';

class SavedSellersScreen extends ConsumerWidget {
  const SavedSellersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSellersAsync = ref.watch(savedSellersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Sellers'),
      ),
      body: savedSellersAsync.when(
        data: (ids) {
          if (ids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: AppTheme.textTertiary),
                  SizedBox(height: 16),
                  Text(
                    'No saved sellers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sellers you like will appear here.',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final sellerId = ids[index];
              return _SavedSellerCard(sellerId: sellerId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _SavedSellerCard extends ConsumerWidget {
  final String sellerId;

  const _SavedSellerCard({required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(sellerProfileProvider(sellerId));

    return profileAsync.when(
      data: (data) {
        final profile = data['profile'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: glassDecoration(),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              profile['name'] ?? 'Seller',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text(profile['mainCity'] ?? 'Unknown', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      (profile['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Text('(${profile['reviewCount'] ?? 0})', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: AppTheme.statusCancelled),
              onPressed: () => ref.read(productServiceProvider).toggleSaveSeller(sellerId),
            ),
            onTap: () => context.go('/buyer/seller/$sellerId'),
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => ListTile(title: Text('Error loading seller: $err')),
    );
  }
}
