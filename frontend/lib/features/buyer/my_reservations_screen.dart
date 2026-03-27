import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsProvider);

    return NatureScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('Моите резервации',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          Expanded(
            child: reservationsAsync.when(
              data: (reservations) {
                if (reservations.isEmpty) {
                  return Center(
                    child: Text('Все още нямате резервации.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: reservations.length,
                  itemBuilder: (ctx, i) {
                    final r = reservations[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: glassDecoration(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        onTap: () => context.go('/buyer/reservation/${r.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                    child: const Icon(Icons.eco, color: AppTheme.accentGreen, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.productName?.isNotEmpty == true ? r.productName! : 'Продукт',
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                                        Text('${r.city ?? 'Местно'} · ${DateFormat('MMM d').format(r.startDate)} - ${DateFormat('MMM d').format(r.endDate)}',
                                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
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
                                  _DetailItem(label: 'Количество', value: '${r.quantity.toStringAsFixed(0)} кг'),
                                  _DetailItem(label: 'Депозит', value: '${r.deposit.toStringAsFixed(2)} лв'),
                                  _DetailItem(label: 'Цена', value: '${(r.pricePerKg ?? 0).toStringAsFixed(2)} лв/кг'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Грешка: $err', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
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
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}
