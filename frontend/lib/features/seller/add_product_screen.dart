import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';

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
  File? _imageFile;

  // Price suggestion state
  double? _overallAvgPrice;      // annual average BGN
  double? _overallAvgPriceEur;   // annual average EUR
  double? _suggestedPrice;       // suggested BGN
  double? _suggestedPriceEur;    // suggested EUR
  bool _userEditedPrice = false;
  bool _isFetchingPrice = false;

  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minThresholdController.dispose();
    _maxCapacityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Fetch price suggestion from the AI / Excel backend ───
  Future<void> _fetchPriceSuggestion(String name, {String? season}) async {
    if (name.length < 3) return;
    setState(() => _isFetchingPrice = true);
    final data = await ref
        .read(productServiceProvider)
        .getPriceSuggestion(name, season: season);
    if (!mounted) return;
    setState(() {
      _isFetchingPrice = false;
      if (data != null) {
        _overallAvgPrice    = (data['overall_average_bgn'] as num?)?.toDouble();
        _overallAvgPriceEur = (data['overall_average_eur'] as num?)?.toDouble();
        _suggestedPrice     = (data['suggested_price_bgn'] as num?)?.toDouble();
        _suggestedPriceEur  = (data['suggested_price_eur'] as num?)?.toDouble();
        if (!_userEditedPrice && _suggestedPrice != null) {
          _priceController.text = _suggestedPrice!.toStringAsFixed(2);
        }
      } else {
        _overallAvgPrice    = null;
        _overallAvgPriceEur = null;
        _suggestedPrice     = null;
        _suggestedPriceEur  = null;
      }
    });
  }

  void _onNameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (value.length > 2) {
        // Classify category
        final category = await ref.read(productServiceProvider).classifyProduct(value);
        if (category != null && mounted) {
          setState(() => _selectedCategory = category);
        }
        // Fetch price suggestion (pass current season if already chosen)
        await _fetchPriceSuggestion(value, season: _selectedSeason);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final origin = _originController.text.trim();
    final priceStr = _priceController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final minThresholdStr = _minThresholdController.text.trim();
    final maxCapacityStr = _maxCapacityController.text.trim();

    if (name.isEmpty ||
        origin.isEmpty ||
        priceStr.isEmpty ||
        quantityStr.isEmpty ||
        minThresholdStr.isEmpty ||
        maxCapacityStr.isEmpty ||
        _selectedCategory == null ||
        _selectedSeason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Моля, попълнете всички полета')),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    final quantity = double.tryParse(quantityStr);
    final minThreshold = double.tryParse(minThresholdStr);
    final maxCapacity = double.tryParse(maxCapacityStr);

    if (price == null || quantity == null || minThreshold == null || maxCapacity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Моля, въведете валидни числови стойности')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('No authenticated user');

      const String imageUrl = 'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?q=80&w=500&auto=format&fit=crop';

      await ref.read(productServiceProvider).addProduct(
            productName: name,
            minThreshold: minThreshold,
            maxCapacity: maxCapacity,
            availableQuantity: quantity,
            category: _selectedCategory!,
            origin: origin,
            image: imageUrl,
            pricePerKg: price,
            season: _selectedSeason!,
          );

      invalidateProductListingCaches(ref);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Продуктът е добавен успешно')),
        );
        context.go('/seller/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неуспешно добавяне: ${e.toString()}')),
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
    return NatureScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/seller/dashboard'),
        ),
        title: const Text('Добави продукт'),
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
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: AppTheme.accentGreen),
                            const SizedBox(height: 8),
                            Text('Добави снимка',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              _buildFieldLabel('Име на продукт'),
              TextField(
                controller: _nameController,
                onChanged: _onNameChanged,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Напр. Розови домати'),
              ),
              const SizedBox(height: 18),

              

              _buildFieldLabel('Произход'),
              TextField(
                controller: _originController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Напр. Розова долина'),
              ),
              const SizedBox(height: 18),

              _buildFieldLabel('Цена за кг (лв)'),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() => _userEditedPrice = true),
                decoration: _inputDecoration(
                  _isFetchingPrice
                      ? 'Зарежда препоръчана цена...'
                      : _suggestedPrice != null
                          ? 'Препоръчана: ${_suggestedPrice!.toStringAsFixed(2)} лв/кг'
                          : '0.00',
                ).copyWith(
                  prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.accentGreen, size: 20),
                  suffixIcon: _isFetchingPrice
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                          ),
                        )
                      : null,
                ),
              ),
              // EUR price chip shown when we have a suggestion
              if (!_isFetchingPrice && _suggestedPrice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.euro_rounded, size: 13, color: AppTheme.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        _suggestedPriceEur != null
                            ? '${_suggestedPrice!.toStringAsFixed(2)} лв/кг  ·  ${_suggestedPriceEur!.toStringAsFixed(2)} €/кг'
                            : '${_suggestedPrice!.toStringAsFixed(2)} лв/кг',
                        style: TextStyle(
                          color: AppTheme.accentGreen.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // "Средната пазарна цена е X" when user edits the field
              if (_userEditedPrice && _overallAvgPrice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.accentGreen),
                      const SizedBox(width: 6),
                      Text(
                        _overallAvgPriceEur != null
                            ? 'Средната пазарна цена е ${_overallAvgPrice!.toStringAsFixed(2)} лв/кг  ·  ${_overallAvgPriceEur!.toStringAsFixed(2)} €/кг'
                            : 'Средната пазарна цена е ${_overallAvgPrice!.toStringAsFixed(2)} лв/кг',
                        style: TextStyle(
                          color: AppTheme.accentGreen.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Налично (кг)'),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Мин. праг (кг)'),
                        TextField(
                          controller: _minThresholdController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Макс. капацитет'),
                        TextField(
                          controller: _maxCapacityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          _buildFieldLabel('Сезон'),

                        DropdownButtonFormField<String>(
                          value: _selectedSeason,
                          isExpanded: true, // 🔥 IMPORTANT FIX
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Избери'),
                          dropdownColor: Colors.black87,
                          iconEnabledColor: AppTheme.accentGreen,
                          items: AppConstants.seasons
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedSeason = v;
                              _userEditedPrice = false;
                            });

                            if (_nameController.text.length > 2) {
                              _fetchPriceSuggestion(_nameController.text, season: v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildFieldLabel('Категория'),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Избери категория'),
                dropdownColor: Colors.black87,
                items: AppConstants.productCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 18),
              

              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
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
                      : const Text('Запази продукт',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
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
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentGreen, width: 1),
      ),
    );
  }
}
