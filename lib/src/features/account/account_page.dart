import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: auth.loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(auth.authenticated ? 'Signed in' : 'Signed out'),
                  const SizedBox(height: 12),
                  if (!auth.authenticated)
                    FilledButton(
                      onPressed: () => ref.read(authControllerProvider.notifier).signIn(),
                      child: const Text('Sign in'),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                      child: const Text('Sign out'),
                    ),
                ],
              ),
      ),
    );
  }
}
