import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../auth/auth_provider.dart';
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
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trade account')),
      body: profileAsync.when(
        data: (profile) {
          if (_submitted || profile?.accountStatus == 'PENDING') {
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
