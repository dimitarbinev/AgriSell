import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/providers/providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _nameController = TextEditingController();
  final _originController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minThresholdController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSeason;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minThresholdController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final origin = _originController.text.trim();
    final priceStr = _priceController.text.trim();
    // final quantityStr = _quantityController.text.trim(); // Ignored per backend spec
    final minThresholdStr = _minThresholdController.text.trim();
    final maxCapacityStr = _maxCapacityController.text.trim();

    if (name.isEmpty ||
        origin.isEmpty ||
        priceStr.isEmpty ||
        minThresholdStr.isEmpty ||
        maxCapacityStr.isEmpty ||
        _selectedCategory == null ||
        _selectedSeason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    final minThreshold = double.tryParse(minThresholdStr);
    final maxCapacity = double.tryParse(maxCapacityStr);

    if (price == null || minThreshold == null || maxCapacity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric values')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(productServiceProvider).addProduct(
            productName: name,
            minThreshold: minThreshold,
            maxCapacity: maxCapacity,
            category: _selectedCategory!,
            origin: origin,
            image: "https://via.placeholder.com/150", // Temporary placeholder
            pricePerKg: price,
            season: _selectedSeason!,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product listed successfully')),
        );
        context.go('/seller/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/seller/dashboard'),
        ),
        title: const Text('Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image upload area
              GestureDetector(
                onTap: () {/* TODO */},
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    color: AppTheme.cardSurfaceLight,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: AppTheme.accentGreen),
                      SizedBox(height: 8),
                      Text('Add Product Photo',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                dropdownColor: AppTheme.cardSurface,
                items: AppConstants.productCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _originController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Origin (e.g. Kazanlak Valley)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Price per kg (лв)',
                  prefixText: '  лв ',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Available Qty (kg)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minThresholdController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Min Threshold (kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxCapacityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Max Capacity (kg)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSeason,
                      decoration: const InputDecoration(labelText: 'Season'),
                      dropdownColor: AppTheme.cardSurface,
                      items: AppConstants.seasons
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSeason = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
