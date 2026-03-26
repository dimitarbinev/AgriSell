import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/status_chip.dart';

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('My Reservations',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _reservations.length,
                itemBuilder: (ctx, i) {
                  final r = _reservations[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: glassDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                color: AppTheme.cardSurfaceLight,
                              ),
                              child: const Icon(Icons.eco, color: AppTheme.accentGreen, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.productName ?? 'Product',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  Text('${r.city ?? ''} · ${DateFormat('MMM d').format(r.attendanceDate)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            StatusChip(status: r.status, small: true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DetailItem(label: 'Quantity', value: '${r.quantity.toStringAsFixed(0)} kg'),
                            _DetailItem(label: 'Deposit', value: '${r.deposit.toStringAsFixed(2)} лв'),
                            _DetailItem(label: 'Price', value: '${(r.pricePerKg ?? 0).toStringAsFixed(2)} лв/kg'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label, value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}

final _reservations = [
  Reservation(id: 'r1', buyerId: 'b1', listingId: '1', quantity: 10, deposit: 35, attendanceDate: DateTime.now().add(const Duration(days: 2)),
    status: 'confirmed', productName: 'Fresh Tomatoes', city: 'Sofia', pricePerKg: 3.50),
  Reservation(id: 'r2', buyerId: 'b1', listingId: '2', quantity: 5, deposit: 14, attendanceDate: DateTime.now().add(const Duration(days: 3)),
    status: 'pending', productName: 'Organic Apples', city: 'Plovdiv', pricePerKg: 2.80),
  Reservation(id: 'r3', buyerId: 'b1', listingId: '4', quantity: 8, deposit: 17.60, attendanceDate: DateTime.now().subtract(const Duration(days: 5)),
    status: 'completed', productName: 'Fresh Carrots', city: 'Burgas', pricePerKg: 2.20),
];
