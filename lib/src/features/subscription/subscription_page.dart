import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/subscription_provider.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Üyelik'),
      ),
      body: subscription.isPro 
          ? _buildProActiveView(context, ref)
          : _buildUpgradeView(context, ref),
    );
  }

  Widget _buildProActiveView(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.verified,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          Text(
            'Pro Üyelik Aktif',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (subscription.expiryDate != null)
            Text(
              'Geçerlilik: ${_formatDate(subscription.expiryDate!)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          const SizedBox(height: 32),
          _buildFeaturesList(isActive: true),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // Test için deaktif et
              ref.read(subscriptionProvider.notifier).deactivatePro();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pro üyelik deaktif edildi (Test)')),
              );
            },
            icon: const Icon(Icons.science),
            label: const Text('Deaktif Et (Test)'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeView(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber[700]!,
                  Colors.orange[800]!,
                ],
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Anatolian Coins Pro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Koleksiyonunuzu üst seviyeye taşıyın',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Özellikler listesi
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Özellikler',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildFeaturesList(isActive: false),
                const SizedBox(height: 32),

                // Fiyatlandırma kartları
                _buildPricingCards(context, ref),

                const SizedBox(height: 24),

                // Ücretsiz vs Pro karşılaştırma
                _buildComparisonTable(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList({required bool isActive}) {
    final features = [
      _Feature(
        icon: Icons.favorite,
        title: 'Sınırsız Favoriler',
        description: 'İstediğiniz kadar sikke favorilerinize ekleyin',
        color: Colors.red,
      ),
      _Feature(
        icon: Icons.offline_bolt,
        title: 'Çevrimdışı Erişim',
        description: 'Sikkelerinizi cihazınıza indirin ve internetsiz kullanın',
        color: Colors.blue,
      ),
      _Feature(
        icon: Icons.camera_alt,
        title: 'Sikke Tanıma (AI)',
        description: 'Fotoğraf çekerek sikke tanımlayın',
        color: Colors.purple,
      ),
      _Feature(
        icon: Icons.high_quality,
        title: 'Yüksek Çözünürlük',
        description: 'Görselleri en yüksek kalitede görüntüleyin',
        color: Colors.green,
      ),
      _Feature(
        icon: Icons.support_agent,
        title: 'Uzman Desteği',
        description: 'Nümizmatik uzmanlarından yardım alın',
        color: Colors.orange,
      ),
      _Feature(
        icon: Icons.block,
        title: 'Reklamsız Deneyim',
        description: 'Hiç reklam görmeden uygulamayı kullanın',
        color: Colors.grey,
      ),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricingCards(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildPricingCard(
          context: context,
          title: 'Aylık',
          price: '₺49,99',
          period: '/ay',
          features: ['Tüm Pro özellikler', 'İstediğiniz zaman iptal'],
          onTap: () => _handlePurchase(context, ref, 'monthly'),
          isPopular: false,
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          context: context,
          title: 'Yıllık',
          price: '₺399,99',
          period: '/yıl',
          badge: '%33 İndirim',
          features: [
            'Tüm Pro özellikler',
            '₺599,99 yerine ₺399,99',
            'Aylık ₺33,33',
          ],
          onTap: () => _handlePurchase(context, ref, 'yearly'),
          isPopular: true,
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          context: context,
          title: 'Yaşam Boyu',
          price: '₺999,99',
          period: 'bir kez',
          badge: 'En İyi Değer',
          features: [
            'Tüm Pro özellikler',
            'Sınırsız süre',
            'Gelecekteki tüm özellikler',
          ],
          onTap: () => _handlePurchase(context, ref, 'lifetime'),
          isPopular: false,
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    String? badge,
    required List<String> features,
    required VoidCallback onTap,
    required bool isPopular,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular ? Colors.amber : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Özellik Karşılaştırması',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          children: [
            _buildTableRow(['Özellik', 'Ücretsiz', 'Pro'], isHeader: true),
            _buildTableRow(['Sikke Kataloğu', '✓', '✓']),
            _buildTableRow(['Arama & Filtreleme', '✓', '✓']),
            _buildTableRow(['Favoriler', '10 adet', 'Sınırsız']),
            _buildTableRow(['Koleksiyonlar', '1 adet', 'Sınırsız']),
            _buildTableRow(['Çevrimdışı Erişim', '✗', '✓']),
            _buildTableRow(['Sikke Tanıma (AI)', '✗', '✓']),
            _buildTableRow(['Yüksek Çözünürlük', '✗', '✓']),
            _buildTableRow(['Uzman Desteği', '✗', '✓']),
            _buildTableRow(['Reklamlar', 'Var', 'Yok']),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[100] : null,
      ),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: isHeader ? 14 : 13,
            ),
            textAlign: cells.indexOf(cell) == 0 ? TextAlign.left : TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  void _handlePurchase(BuildContext context, WidgetRef ref, String planType) {
    // Test için Pro'yu aktif et
    ref.read(subscriptionProvider.notifier).activatePro(
      expiryDate: planType == 'lifetime' 
          ? null 
          : DateTime.now().add(
              planType == 'monthly' 
                  ? const Duration(days: 30)
                  : const Duration(days: 365),
            ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Modu'),
        content: Text(
          'Gerçek ödeme entegrasyonu henüz eklenmedi.\n\n'
          'Pro üyelik test için aktif edildi ($planType).\n\n'
          'Gerçek uygulamada burada:\n'
          '• Google Play Billing\n'
          '• App Store IAP\n'
          'entegrasyonu olacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}