import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'recognition_service.dart';

/// Recognition results screen
/// Displays top matches from AI recognition
class RecognitionResultsScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const RecognitionResultsScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<RecognitionResultsScreen> createState() =>
      _RecognitionResultsScreenState();
}

class _RecognitionResultsScreenState
    extends ConsumerState<RecognitionResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger recognition on init
    Future.microtask(() async {
      await ref.read(recognitionServiceProvider).recognize(File(widget.imagePath));
      // Refresh quota after successful scan
      ref.invalidate(scanQuotaProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = ref.watch(recognitionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recognition Results'),
        centerTitle: true,
      ),
      body: recognitionState.when(
        data: (results) => _buildResults(results),
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(error),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Analyzing coin...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Recognition Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Retry recognition
                ref
                    .read(recognitionServiceProvider)
                    .recognize(File(widget.imagePath));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(RecognitionResponse results) {
    if (results.matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No matches found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a clearer photo with better lighting',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Another Photo'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Scan info banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Showing top matches',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Found ${results.matches.length} similar coins',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.matches.length,
            itemBuilder: (context, index) {
              final match = results.matches[index];
              return _buildMatchCard(match, index + 1);
            },
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Pop twice to go back to camera
                    context.pop();
                    context.pop();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'Scan Another Coin',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(CoinMatch match, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navigate to variant detail
          context.push('/variant/${match.articleId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getRankColor(rank),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Coin image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: match.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          match.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      )
                    : const Icon(Icons.monetization_on, size: 40),
              ),
              const SizedBox(width: 12),

              // Coin info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (match.region != null)
                      Text(
                        match.region!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    if (match.dateRange != null)
                      Text(
                        match.dateRange!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    const SizedBox(height: 8),
                    // Confidence bar
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: match.confidence,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getConfidenceColor(match.confidence),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(match.confidence * 100).toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getConfidenceColor(match.confidence),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[300]!;
      default:
        return Colors.blue[300]!;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
