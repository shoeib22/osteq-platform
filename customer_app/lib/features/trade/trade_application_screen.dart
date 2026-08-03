import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../auth/auth_provider.dart';
import '../addresses/address_model.dart';
import '../addresses/address_repository.dart';
import '../addresses/address_form_screen.dart';
import 'trade_application_repository.dart';

class TradeApplicationScreen extends ConsumerStatefulWidget {
  const TradeApplicationScreen({super.key});

  @override
  ConsumerState<TradeApplicationScreen> createState() => _TradeApplicationScreenState();
}

class _TradeApplicationScreenState extends ConsumerState<TradeApplicationScreen> {
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _submitted = false;
  String? _selectedAddressId;

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _addNewAddress() async {
    final address = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (context) => const AddressFormScreen()),
    );
    if (address != null && mounted) {
      setState(() => _selectedAddressId = address.id);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(tradeApplicationRepositoryProvider).submit(
            businessName: _businessNameController.text.trim(),
            businessType: _businessTypeController.text.trim(),
            phone: _phoneController.text.trim(),
            taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
            addressId: _selectedAddressId,
          );
      if (mounted) setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildAddressSection() {
    final addressesAsync = ref.watch(addressListProvider);
    return addressesAsync.when(
      data: (addresses) {
        if (_selectedAddressId != null && !addresses.any((a) => a.id == _selectedAddressId)) {
          _selectedAddressId = null;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (addresses.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _selectedAddressId,
                decoration: const InputDecoration(labelText: 'Business address (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('None')),
                  ...addresses.map(
                    (a) => DropdownMenuItem<String?>(value: a.id, child: Text('${a.label} — ${a.city}')),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedAddressId = value),
              ),
            TextButton.icon(
              onPressed: _addNewAddress,
              icon: const Icon(Icons.add),
              label: const Text('Add new address'),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => TextButton.icon(
        onPressed: _addNewAddress,
        icon: const Icon(Icons.add),
        label: const Text('Add new address'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trade account')),
      body: profileAsync.when(
        data: (profile) {
          if (_submitted || profile?.hasPendingTradeApplication == true) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your trade application is under review.'),
            );
          }
          if (profile?.accountStatus == 'TRADE_APPROVED') {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your trade account is approved — trade pricing is active.'),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile?.accountStatus == 'REJECTED')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Your previous application was not approved. You can reapply below.'),
                  ),
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _businessTypeController,
                  decoration: const InputDecoration(labelText: 'Business type (e.g. installer)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(labelText: 'Tax ID (optional)'),
                ),
                const SizedBox(height: 12),
                _buildAddressSection(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit application'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}
