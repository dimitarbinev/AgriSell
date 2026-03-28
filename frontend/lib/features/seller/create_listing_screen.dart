import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/nature_scaffold.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();

  Product? _selectedProduct;
  String? _selectedCity;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _priceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? now.add(const Duration(days: 1))
        : (_startDate?.add(const Duration(days: 1)) ??
            now.add(const Duration(days: 2)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: AppTheme.darkTheme.copyWith(
          colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
            primary: AppTheme.primaryGreen,
            surface: AppTheme.cardSurface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(date)) {
            _endDate = date.add(const Duration(days: 1));
          }
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _handleCreate() async {
    final city = _cityController.text.trim();

    if (_selectedProduct == null ||
        city.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Моля, попълнете всички полета')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(productServiceProvider).confirmListing(
            productId: _selectedProduct!.id,
            city: city,
            startDate: _startDate!,
            endDate: _endDate!,
          );

      invalidateProductListingCaches(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обявата е създадена успешно')),
        );
        context.go('/seller/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неуспешно създаване: $e')),
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
    final productsAsync = ref.watch(sellerProductsProvider);

    return NatureScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/seller/dashboard'),
        ),
        title: const Text('Създай обява'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFieldLabel('Избери продукт'),

              productsAsync.when(
                data: (products) => DropdownButtonFormField<Product>(
                  value: _selectedProduct,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Продукт').copyWith(
                    prefixIcon: const Icon(Icons.eco,
                        size: 20, color: AppTheme.accentGreen),
                  ),
                  dropdownColor: Colors.black87,
                  items: products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name,
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedProduct = v;
                      if (v != null) {
                        _priceController.text =
                            v.pricePerKg.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text(
                  'Грешка при зареждане: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

              const SizedBox(height: 18),

              /// 🔥 CITY AUTOCOMPLETE
              _buildFieldLabel('Град'),

              Autocomplete<String>(
                optionsBuilder: (text) {
                  if (text.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return AppConstants.cities.where(
                    (c) => c.toLowerCase().contains(
                          text.text.toLowerCase(),
                        ),
                  );
                },
                onSelected: (value) {
                  _cityController.text = value;
                  _selectedCity = value;
                },
                fieldViewBuilder: (context, controller, focusNode, _) {
                  controller.text = _cityController.text;

                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (val) {
                      _cityController.text = val;
                      _selectedCity = val;
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration('Започни да пишеш град...'),
                  );
                },
              ),

              const SizedBox(height: 18),

              /// 🔥 FIXED DATE SECTION (NO OVERFLOW)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Начална дата'),
                        GestureDetector(
                          onTap: () => _pickDate(true),
                          child: _dateBox(_startDate, 'Начало'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Крайна дата'),
                        GestureDetector(
                          onTap: () => _pickDate(false),
                          child: _dateBox(_endDate, 'Край'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text('Създай обява'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔥 FIXED DATE BOX (NO OVERFLOW)
  Widget _dateBox(DateTime? date, String placeholder) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              size: 18, color: AppTheme.accentGreen),
          const SizedBox(width: 8),

          Expanded(
            child: Text(
              date != null
                  ? DateFormat('MMM d, y').format(date)
                  : placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: date != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}