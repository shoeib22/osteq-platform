import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import 'address_model.dart';
import 'address_repository.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final Address? existing;
  const AddressFormScreen({super.key, this.existing});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late bool _isDefault;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _line1Controller = TextEditingController(text: existing?.line1 ?? '');
    _line2Controller = TextEditingController(text: existing?.line2 ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _stateController = TextEditingController(text: existing?.state ?? '');
    _postalCodeController = TextEditingController(text: existing?.postalCode ?? '');
    _countryController = TextEditingController(text: existing?.country ?? 'India');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(addressRepositoryProvider);
      final existing = widget.existing;
      final address = existing == null
          ? await repo.create(
              label: _labelController.text.trim(),
              line1: _line1Controller.text.trim(),
              line2: _line2Controller.text.trim(),
              city: _cityController.text.trim(),
              state: _stateController.text.trim(),
              postalCode: _postalCodeController.text.trim(),
              country: _countryController.text.trim(),
              phone: _phoneController.text.trim(),
              isDefault: _isDefault,
            )
          : await repo.update(
              existing.id,
              label: _labelController.text.trim(),
              line1: _line1Controller.text.trim(),
              line2: _line2Controller.text.trim(),
              city: _cityController.text.trim(),
              state: _stateController.text.trim(),
              postalCode: _postalCodeController.text.trim(),
              country: _countryController.text.trim(),
              phone: _phoneController.text.trim(),
              isDefault: _isDefault,
            );
      ref.invalidate(addressListProvider);
      if (mounted) Navigator.of(context).pop(address);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canSave =>
      _labelController.text.trim().isNotEmpty &&
      _line1Controller.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty &&
      _stateController.text.trim().isNotEmpty &&
      _postalCodeController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add address' : 'Edit address')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label (e.g. Warehouse, Shop)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _line1Controller,
              decoration: const InputDecoration(labelText: 'Address line 1'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _line2Controller,
              decoration: const InputDecoration(labelText: 'Address line 2 (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'State'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postalCodeController,
              decoration: const InputDecoration(labelText: 'Postal code'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(labelText: 'Country'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              title: const Text('Set as default address'),
              onChanged: (value) => setState(() => _isDefault = value ?? false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting || !_canSave ? null : _save,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save address'),
            ),
          ],
        ),
      ),
    );
  }
}
