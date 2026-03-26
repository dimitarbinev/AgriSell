import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _priceController = TextEditingController();
  String? _selectedProduct;
  String? _selectedCity;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: AppTheme.darkTheme.copyWith(
          colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
            primary: AppTheme.primaryGreen,
            surface: AppTheme.cardSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  void _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 14, minute: 0),
      builder: (ctx, child) => Theme(
        data: AppTheme.darkTheme,
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  void _handleCreate() {
    // TODO: Create listing in Firestore
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product selection
              DropdownButtonFormField<String>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  prefixIcon: Icon(Icons.eco, size: 20),
                ),
                dropdownColor: AppTheme.cardSurface,
                items: ['Fresh Tomatoes', 'Organic Apples', 'Sunflower Honey']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProduct = v),
              ),
              const SizedBox(height: 16),

              // City
              DropdownButtonFormField<String>(
                initialValue: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
                dropdownColor: AppTheme.cardSurface,
                items: AppConstants.cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
              ),
              const SizedBox(height: 16),

              // Date
              GestureDetector(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('EEEE, MMM d, y').format(_selectedDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time range
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          prefixIcon: Icon(Icons.access_time, size: 20),
                        ),
                        child: Text(
                          _startTime != null
                              ? _startTime!.format(context)
                              : 'Start',
                          style: TextStyle(
                            color: _startTime != null
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          prefixIcon: Icon(Icons.access_time, size: 20),
                        ),
                        child: Text(
                          _endTime != null
                              ? _endTime!.format(context)
                              : 'End',
                          style: TextStyle(
                            color: _endTime != null
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Price
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Price per kg (лв)',
                  prefixIcon: Icon(Icons.attach_money, size: 20),
                ),
              ),
              const SizedBox(height: 28),

              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ElevatedButton(
                  onPressed: _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text('Create Listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
