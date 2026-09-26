import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'ticker_api.dart';

/// Fade transition ticker widget for displaying coin facts
/// Similar to the Joomla mod_numistr_ticker module (fade effect, not marquee)
class NumistrTicker extends ConsumerStatefulWidget {
  final String? region;
  final String? category;
  final String? language; // Language code: 'tr-TR', 'en-GB', or '*' for all
  final int itemCount;
  final double height;

  /// Olgu metninin en çok satırı (bölge listesinde 3, varsayılan 4).
  final int maxLines;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration fadeInterval;
  final Duration fadeDuration;

  const NumistrTicker({
    super.key,
    this.region,
    this.category,
    this.language,
    this.itemCount = 20,
    this.height = 88, // Height for 4 lines of text
    this.maxLines = 4,
    this.backgroundColor,
    this.textColor,
    this.fadeInterval = const Duration(seconds: 8), // Time between transitions
    this.fadeDuration = const Duration(milliseconds: 600), // Fade animation duration
  });

  @override
  ConsumerState<NumistrTicker> createState() => _NumistrTickerState();
}

class _NumistrTickerState extends ConsumerState<NumistrTicker>
    with SingleTickerProviderStateMixin {
  List<TickerItem> _items = [];
  bool _loading = true;
  bool _hasError = false;

  int _currentIndex = 0;
  Timer? _autoAdvanceTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _loadItems();
  }

  /// Bölge/kategori/dil değişince yeniden yükle. Keşfet sekmesi canlı kaldığı
  /// için (StatefulShellRoute) sayfa yeniden kurulmaz; bu olmadan Frigya
  /// başlığının altında Bitinya bilgileri dönmeye devam ediyordu (cihazda görüldü).
  @override
  void didUpdateWidget(covariant NumistrTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region != widget.region ||
        oldWidget.category != widget.category ||
        oldWidget.language != widget.language) {
      _autoAdvanceTimer?.cancel();
      _fadeController.value = 0;
      setState(() {
        _items = [];
        _currentIndex = 0;
        _loading = true;
        _hasError = false;
      });
      _loadItems();
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  /// Son isteğin sırası: geç dönen eski bölge yanıtı yenisinin üstüne yazmasın.
  int _request = 0;

  Future<void> _loadItems() async {
    final request = ++_request;
    try {
      final api = ref.read(tickerApiProvider);
      debugPrint('🎫 Ticker loading for region: ${widget.region}, language: ${widget.language}');
      final items = await api.getTickerItems(
        region: widget.region,
        category: widget.category,
        language: widget.language,
        limit: widget.itemCount,
      );
      debugPrint('🎫 Ticker loaded ${items.length} items');

      if (mounted && request == _request) {
        setState(() {
          _items = items;
          _loading = false;
          _hasError = false;
        });

        if (_items.isNotEmpty) {
          // Start with fade in
          _fadeController.forward();
          // Start auto-advance timer
          _startAutoAdvance();
        }
      }
    } catch (e) {
      debugPrint('❌ Ticker error: $e');
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(widget.fadeInterval, (_) {
      _goToNext();
    });
  }

  Future<void> _goToNext() async {
    if (_items.isEmpty || !mounted) return;

    // Fade out current
    await _fadeController.reverse();

    // Beklerken bölge değişmiş olabilir (didUpdateWidget listeyi boşaltır).
    if (!mounted || _items.isEmpty) return;

    // Update index
    setState(() {
      _currentIndex = (_currentIndex + 1) % _items.length;
    });

    // Fade in next
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? numPrimary;
    final txtColor = widget.textColor ?? Colors.white;

    // Don't show ticker if no items and not loading
    if (_items.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _loading
          ? _buildLoadingState(txtColor)
          : _hasError
              ? const SizedBox.shrink()
              : _buildTickerContent(txtColor),
    );
  }

  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(textColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _buildTickerContent(Color textColor) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _items[_currentIndex];
    // Debug: Print what ticker is showing
    debugPrint('🎫 Ticker showing: ${currentItem.factTitle}: ${currentItem.factDescription}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: currentItem.factTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
                TextSpan(
                  text: ': ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
                TextSpan(
                  text: currentItem.factDescription,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: textColor.withValues(alpha: 0.95),
                    letterSpacing: 0.1,
                    height: 1.3, // Better line height for readability
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Compact ticker for region headers
/// Filters ticker content by region code and app language
class RegionTicker extends ConsumerWidget {
  final String region; // Region code (e.g., 'lydia-coins', 'pisidia-coins')
  final double height;
  final int maxLines;

  const RegionTicker({
    super.key,
    required this.region,
    this.height = 88, // Height for 4 lines of text
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current app locale and convert to Joomla language format
    final locale = Localizations.localeOf(context);
    final joomlaLanguage = _getJoomlaLanguageCode(locale);

    // Pass region and language to filter ticker items
    return NumistrTicker(
      region: region,
      language: joomlaLanguage,
      height: height,
      maxLines: maxLines,
      backgroundColor: numPrimary.withValues(alpha: 0.95),
      fadeInterval: const Duration(seconds: 8),
      fadeDuration: const Duration(milliseconds: 600),
    );
  }

  /// Convert Flutter Locale to Joomla language code format
  /// Flutter: tr, en | Joomla: tr-TR, en-GB
  String _getJoomlaLanguageCode(Locale locale) {
    switch (locale.languageCode) {
      case 'tr':
        return 'tr-TR';
      case 'en':
        return 'en-GB';
      default:
        return '*'; // All languages if unknown
    }
  }
}
