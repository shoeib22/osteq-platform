import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_repository.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.pushNamed('login'),
            child: const Text('Log in'),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(profile?.email ?? '', style: Theme.of(context).textTheme.titleMedium),
            if (profile?.businessName != null) Text(profile!.businessName!),
            const SizedBox(height: 8),
            Text('Trade status: ${profile?.accountStatus ?? 'PENDING'}'),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Trade account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('tradeApplication'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('addresses'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('orderHistory'),
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text('Projector calculator'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('projectorCalculator'),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.goNamed('catalog');
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}
