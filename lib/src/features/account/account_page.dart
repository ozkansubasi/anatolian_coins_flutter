import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_controller.dart';
import '../recognition/recognition_service.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: auth.loading
          ? const Center(child: CircularProgressIndicator())
          : auth.authenticated
              ? _buildAuthenticatedView(context, ref)
              : _buildUnauthenticatedView(context, ref),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Sign in to access all features',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).signIn(),
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(scanQuotaProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Signed In',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Scan quota card
        quotaAsync.when(
          data: (quota) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        quota.isPro ? Icons.star : Icons.camera_alt,
                        color: quota.isPro ? Colors.amber : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        quota.isPro ? 'Pro Plan' : 'Free Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quota info
                  if (!quota.isPro) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Scans this month:',
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          '${quota.used} / ${quota.limit}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: quota.used / quota.limit,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        quota.remaining > 3 ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${quota.remaining} scans remaining',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (quota.resetDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Resets: ${_formatResetDate(quota.resetDate!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/subscription'),
                        icon: const Icon(Icons.upgrade),
                        label: const Text('Upgrade to Pro'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '✓ Unlimited scans',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '✓ Offline database access',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '✓ High-resolution images',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '✓ Advanced recognition',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ],
              ),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load quota: $error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.refresh(scanQuotaProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatResetDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
