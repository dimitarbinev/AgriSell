import 'package:flutter/material.dart';
import '../../core/theme.dart';

class RoutePlanningScreen extends StatelessWidget {
  const RoutePlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Route Planning',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 16),
            // Map Placeholder
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  color: AppTheme.cardSurface,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 48, color: AppTheme.textTertiary),
                          SizedBox(height: 8),
                          Text('Map View', style: TextStyle(color: AppTheme.textTertiary)),
                          Text('Google Maps loads here', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Demand dots overlay simulation
                    ..._demandDots.map((d) => Positioned(
                      left: d.x,
                      top: d.y,
                      child: Container(
                        width: d.size,
                        height: d.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentGreen.withValues(alpha: 0.4),
                          border: Border.all(color: AppTheme.accentGreen, width: 2),
                        ),
                        child: Center(
                          child: Text('${d.quantity}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ranked stops
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text('Ranked Stops',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  ..._rankedStops.asMap().entries.map((e) => _StopCard(
                    rank: e.key + 1,
                    city: e.value.city,
                    demand: e.value.demand,
                    distance: e.value.distance,
                    profit: e.value.profit,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final int rank;
  final String city;
  final int demand;
  final int distance;
  final double profit;

  const _StopCard({
    required this.rank,
    required this.city,
    required this.demand,
    required this.distance,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text('$demand kg demand · $distance km',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('~${profit.toStringAsFixed(0)} лв',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
        ],
      ),
    );
  }
}

class _DemandDot {
  final double x, y, size;
  final int quantity;
  const _DemandDot(this.x, this.y, this.size, this.quantity);
}

const _demandDots = [
  _DemandDot(80, 60, 40, 75),
  _DemandDot(180, 100, 50, 85),
  _DemandDot(120, 180, 30, 40),
  _DemandDot(250, 70, 25, 20),
];

class _RankedStop {
  final String city;
  final int demand, distance;
  final double profit;
  const _RankedStop(this.city, this.demand, this.distance, this.profit);
}

const _rankedStops = [
  _RankedStop('Plovdiv', 85, 145, 238),
  _RankedStop('Sofia', 75, 32, 262),
  _RankedStop('Stara Zagora', 40, 230, 112),
  _RankedStop('Burgas', 20, 380, 56),
];
