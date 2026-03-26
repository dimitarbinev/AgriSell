import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class BuyerOnboardingScreen extends StatefulWidget {
  const BuyerOnboardingScreen({super.key});

  @override
  State<BuyerOnboardingScreen> createState() => _BuyerOnboardingScreenState();
}

class _BuyerOnboardingScreenState extends State<BuyerOnboardingScreen> {
  final _nameController = TextEditingController();
  String? _selectedCity;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    // TODO: Save buyer profile to Firestore
    context.go('/buyer/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/register'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shopping_bag_rounded,
                size: 64,
                color: AppTheme.accentGreen,
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'Preferred City',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      dropdownColor: AppTheme.cardSurface,
                      items: AppConstants.cities
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCity = v),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: ElevatedButton(
                        onPressed: _handleComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Start Exploring'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
