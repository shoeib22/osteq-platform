import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'address_model.dart';
import 'address_repository.dart';
import 'address_form_screen.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Address address) async {
    try {
      await ref.read(addressRepositoryProvider).delete(address.id);
      ref.invalidate(addressListProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete address.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<Address>(
            MaterialPageRoute(builder: (context) => const AddressFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return const Center(child: Text('No saved addresses yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListTile(
                title: Row(
                  children: [
                    Text(address.label, style: Theme.of(context).textTheme.titleMedium),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Default', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(address.summary),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.of(context).push<Address>(
                        MaterialPageRoute(builder: (context) => AddressFormScreen(existing: address)),
                      );
                    } else if (value == 'delete') {
                      await _delete(context, ref, address);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load addresses: $error')),
      ),
    );
  }
}
