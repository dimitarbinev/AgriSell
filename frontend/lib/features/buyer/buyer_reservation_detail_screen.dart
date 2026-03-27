import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/nature_scaffold.dart';

class BuyerReservationDetailScreen extends ConsumerWidget {
  final String reservationId;
  const BuyerReservationDetailScreen({super.key, required this.reservationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsProvider);

    return reservationsAsync.when(
      data: (reservations) {
        final reservation = reservations.cast<Reservation?>().firstWhere(
              (r) => r?.id == reservationId,
              orElse: () => null,
            );

        if (reservation == null) {
          return NatureScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.go('/buyer/reservations'),
              ),
              title: const Text('Детайли за резервация'),
            ),
            body: const Center(child: Text('Резервацията не е намерена', style: TextStyle(color: Colors.white))),
          );
        }

        final canCancel = reservation.status == 'active' || reservation.status == 'pending';

        return NatureScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.go('/buyer/reservations'),
            ),
            title: const Text('Детайли за резервация'),
            actions: [
              StatusChip(status: reservation.status),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: glassDecoration(),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.shopping_basket_outlined,
                            color: AppTheme.accentGreen, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reservation.productName ?? 'Продукт',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(reservation.city ?? 'Местно',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Details Grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: glassDecoration(),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.scale_outlined,
                        label: 'Количество',
                        value: '${reservation.quantity.toStringAsFixed(0)} кг',
                      ),
                      const Divider(height: 32, color: Colors.white10),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Цена за кг',
                        value: '${(reservation.pricePerKg ?? 0).toStringAsFixed(2)} лв',
                      ),
                      const Divider(height: 32, color: Colors.white10),
                      _DetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Платен депозит',
                        value: '${reservation.deposit.toStringAsFixed(2)} лв',
                      ),
                      const Divider(height: 32, color: Colors.white10),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Създадено на',
                        value: DateFormat('MMM d, yyyy').format(reservation.createdAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Availability Range
                const Text('Период за получаване',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: glassDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, color: AppTheme.accentGreen),
                      const SizedBox(width: 16),
                      Text(
                        '${DateFormat('MMM d').format(reservation.startDate)} - ${DateFormat('MMM d, yyyy').format(reservation.endDate)}',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Cancel Button
                if (canCancel)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _showCancelDialog(context, ref, reservation.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                      ),
                      child: const Text('Откажи резервация',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
      loading: () => const NatureScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => NatureScaffold(body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white)))),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String reservationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface.withValues(alpha: 0.95),
        title: const Text('Отказване на резервация?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Сигурни ли сте, че искате да откажете тази резервация? Това действие не може да бъде отменено.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Не, почакай', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await ref.read(productServiceProvider).cancelReservation(reservationId);

                // Refresh all affected screens immediately
                ref.invalidate(myReservationsProvider);
                ref.invalidate(activeListingsProvider);
                if (context.mounted) {
                  context.go('/buyer/reservations');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Резервацията е отказана успешно')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Да, откажи', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.accentGreen),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}
