import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/coin_format.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';

/// Antik Anadolu haritası için veri modelleri
///
/// Veri dosyası (`assets/data/ancient_map_data.json`) yalnız kimlik ve
/// koordinat taşır; görünen ad/açıklama çeviri dosyalarındadır: bölge adı
/// `region_<kod>`, darphane adı `map_mint_<id>`, açıklaması `map_mint_<id>_desc`.
class AncientMapRegion {
  final double lat;
  final double lng;
  final String regionCode;

  AncientMapRegion({
    required this.lat,
    required this.lng,
    required this.regionCode,
  });

  factory AncientMapRegion.fromJson(Map<String, dynamic> json) {
    return AncientMapRegion(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      regionCode: json['regionCode'] ?? '',
    );
  }

  String displayName(AppLocalizations l10n) => RegionData.getRegionName(regionCode, l10n);
}

class AncientMapMint {
  final String id;

  /// Latince/kanonik ad — sikkenin darphane adıyla eşleştirmede kullanılır.
  final String name;

  /// Eşleştirmede kabul edilen diğer yazımlar (görüntü metni değil).
  final List<String> aliases;
  final double lat;
  final double lng;
  final String region;

  AncientMapMint({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.lat,
    required this.lng,
    required this.region,
  });

  factory AncientMapMint.fromJson(Map<String, dynamic> json) {
    return AncientMapMint(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      aliases: (json['aliases'] as List?)?.cast<String>() ?? const [],
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      region: json['region'] ?? '',
    );
  }

  String displayName(AppLocalizations l10n) => l10n.translate('map_mint_$id');
  String description(AppLocalizations l10n) => l10n.translate('map_mint_${id}_desc');

  /// Sikkenin darphane adı bu darphaneye mi ait? (büyük/küçük harf duyarsız)
  bool matches(String mintName) {
    final wanted = mintName.toLowerCase();
    return name.toLowerCase() == wanted || aliases.any((a) => a.toLowerCase() == wanted);
  }
}

class AncientMapData {
  final List<AncientMapRegion> regions;
  final List<AncientMapMint> mints;

  AncientMapData({required this.regions, required this.mints});

  factory AncientMapData.fromJson(Map<String, dynamic> json) {
    return AncientMapData(
      regions: (json['regions'] as List?)
              ?.map((r) => AncientMapRegion.fromJson(r))
              .toList() ??
          [],
      mints: (json['mints'] as List?)
              ?.map((m) => AncientMapMint.fromJson(m))
              .toList() ??
          [],
    );
  }
}

/// Antik harita widget'ı - flutter_map kullanarak OpenStreetMap tabanlı
class AncientMapWidget extends StatefulWidget {
  /// Odaklanılacak koordinatlar (opsiyonel)
  final LatLng? focusPoint;

  /// Vurgulanacak darphane adı (opsiyonel)
  final String? highlightMint;

  /// Bölge filtreleme (opsiyonel)
  final String? filterRegion;

  /// Tam ekran modunda mı
  final bool isFullScreen;

  /// Dışarıdan paylaşılan harita kontrolcüsü (opsiyonel).
  /// Verilmezse widget kendi kontrolcüsünü oluşturur.
  final MapController? controller;

  const AncientMapWidget({
    super.key,
    this.focusPoint,
    this.highlightMint,
    this.filterRegion,
    this.isFullScreen = false,
    this.controller,
  });

  @override
  State<AncientMapWidget> createState() => _AncientMapWidgetState();
}

class _AncientMapWidgetState extends State<AncientMapWidget> {
  AncientMapData? _mapData;
  bool _loading = true;
  String? _error;
  // Dışarıdan kontrolcü verilmişse onu kullan, yoksa kendi kontrolcümüzü oluştur.
  late final MapController _mapController = widget.controller ?? MapController();

  // Görüntüleme seçenekleri
  bool _showRegionLabels = true;
  bool _showMintMarkers = true;

  /// Lejant varsayılan kapalı; açıkken bilgi kartıyla çakışmasın diye kart
  /// açılınca gizlenir (2026-09-26 cihaz testi: lejant kartın üstüne biniyordu).
  bool _showLegend = false;

  // Seçili marker
  AncientMapMint? _selectedMint;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/ancient_map_data.json');
      final jsonData = json.decode(jsonString);
      setState(() {
        _mapData = AncientMapData.fromJson(jsonData);
        _loading = false;
      });

      // Vurgulu mint varsa onu bul ve seç. Bulunamazsa HİÇBİR ŞEY seçilmez:
      // eskiden `orElse: mints.first` listedeki ilk darphaneyi (Kyzikos) seçiyor,
      // Aezanis sikkesinde Kyzikos kartı gösteriyordu (cihazda görüldü).
      if (widget.highlightMint != null && _mapData != null) {
        final matches = _mapData!.mints.where((m) => m.matches(widget.highlightMint!));
        if (matches.isNotEmpty) setState(() => _selectedMint = matches.first);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: numPrimary),
      );
    }

    if (_error != null || _mapData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            16.height,
            Text(
              l10n.translate('map_load_error'),
              style: boldTextStyle(size: 16),
            ),
            8.height,
            Text(
              l10n.translate('error_generic'),
              style: secondaryTextStyle(size: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Başlangıç konumu
    final initialCenter = widget.focusPoint ?? const LatLng(38.5, 32.0); // Anadolu merkezi
    final initialZoom = widget.focusPoint != null ? 8.0 : 6.0;

    return Stack(
      children: [
        // Harita
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            minZoom: 4,
            maxZoom: 12,
            onTap: (_, __) {
              setState(() => _selectedMint = null);
            },
          ),
          children: [
            // Antik harita görünümü - Stamen Watercolor benzeri
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.anatoliancoins.app',
              tileBuilder: _antiqueTileBuilder,
            ),

            // Bölge etiketleri
            if (_showRegionLabels) _buildRegionLabels(),

            // Darphane markerları
            if (_showMintMarkers) _buildMintMarkers(),
          ],
        ),

        // Kontrol paneli (tam ekran modunda). Yatayda yükseklik az: sığmazsa kayar.
        if (widget.isFullScreen)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(child: _buildControlPanel(l10n)),
                ),
              ),
            ),
          ),

        // Seçili darphane bilgi kartı (yalnız tam ekran; önizlemede 'Haritada
        // göster' katmanıyla çakışıyordu). Yatayda tüm genişliği kaplamasın.
        if (widget.isFullScreen && _selectedMint != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _buildMintInfoCard(l10n),
              ),
            ),
          ),

        // Lejant: istek üzerine, kart açık değilken
        if (widget.isFullScreen && _showLegend && _selectedMint == null)
          Positioned(
            bottom: 12,
            left: 12,
            child: SafeArea(child: _buildLegend(l10n)),
          ),
      ],
    );
  }

  /// Tile'ları antik görünümlü yapar
  Widget _antiqueTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  /// Bölge etiketlerini oluşturur
  Widget _buildRegionLabels() {
    final filteredRegions = widget.filterRegion != null
        ? _mapData!.regions.where((r) => r.regionCode == widget.filterRegion).toList()
        : _mapData!.regions;

    return MarkerLayer(
      markers: filteredRegions.map((region) {
        final color = getRegionColor(region.regionCode.replaceAll('-coins', ''));
        return Marker(
          point: LatLng(region.lat, region.lng),
          width: 120,
          height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              region.displayName(AppLocalizations.of(context)),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Darphane markerlarını oluşturur
  Widget _buildMintMarkers() {
    final filteredMints = widget.filterRegion != null
        ? _mapData!.mints.where((m) => m.region == widget.filterRegion).toList()
        : _mapData!.mints;

    return MarkerLayer(
      markers: filteredMints.map((mint) {
        final isHighlighted =
            widget.highlightMint != null && mint.matches(widget.highlightMint!);
        final isSelected = _selectedMint == mint;
        final color = getRegionColor(mint.region.replaceAll('-coins', ''));

        return Marker(
          point: LatLng(mint.lat, mint.lng),
          width: isHighlighted || isSelected ? 40 : 28,
          height: isHighlighted || isSelected ? 40 : 28,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedMint = mint);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isHighlighted || isSelected
                    ? numPrimary
                    : color.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isHighlighted || isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isHighlighted || isSelected ? numPrimary : color).withValues(alpha: 0.4),
                    blurRadius: isHighlighted || isSelected ? 8 : 4,
                    spreadRadius: isHighlighted || isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.location_on,
                size: isHighlighted || isSelected ? 24 : 16,
                color: Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Kontrol paneli
  Widget _buildControlPanel(AppLocalizations l10n) {
    final c = context.numColors;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.zoom_in,
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            ),
          ),
          4.height,
          _buildControlButton(
            icon: Icons.zoom_out,
            onPressed: () => _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            ),
          ),
          const Divider(height: 16),
          _buildToggleButton(
            icon: Icons.label,
            isActive: _showRegionLabels,
            onPressed: () => setState(() => _showRegionLabels = !_showRegionLabels),
            tooltip: l10n.translate('show_regions'),
          ),
          4.height,
          _buildToggleButton(
            icon: Icons.location_on,
            isActive: _showMintMarkers,
            onPressed: () => setState(() => _showMintMarkers = !_showMintMarkers),
            tooltip: l10n.translate('show_mints'),
          ),
          4.height,
          _buildToggleButton(
            icon: Icons.info_outline,
            isActive: _showLegend,
            onPressed: () => setState(() {
              _showLegend = !_showLegend;
              if (_showLegend) _selectedMint = null;
            }),
            tooltip: l10n.translate('legend'),
          ),
          const Divider(height: 16),
          _buildControlButton(
            icon: Icons.center_focus_strong,
            onPressed: () => _mapController.move(
              const LatLng(38.5, 32.0),
              6.0,
            ),
            tooltip: l10n.translate('reset_view'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.brown.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final c = context.numColors;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? numPrimary : c.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: isActive ? Colors.white : c.textMuted),
          ),
        ),
      ),
    );
  }

  /// Darphane bilgi kartı
  Widget _buildMintInfoCard(AppLocalizations l10n) {
    if (_selectedMint == null) return const SizedBox.shrink();

    final mint = _selectedMint!;
    final color = getRegionColor(mint.region.replaceAll('-coins', ''));
    final c = context.numColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bölge rengi göstergesi
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(Icons.account_balance, color: color, size: 18),
          ),
          12.width,
          // Darphane bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mint.displayName(l10n),
                  style: boldTextStyle(size: 15, color: c.text),
                ),
                4.height,
                Text(
                  mint.description(l10n),
                  style: secondaryTextStyle(size: 12, color: c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Kapat butonu
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedMint = null),
            iconSize: 20,
            color: c.textMuted,
          ),
        ],
      ),
    );
  }

  /// Lejant
  Widget _buildLegend(AppLocalizations l10n) {
    final c = context.numColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.translate('legend'),
            style: boldTextStyle(size: 12, color: c.text),
          ),
          8.height,
          _buildLegendItem(Icons.location_on, numPrimary, l10n.translate('highlighted_mint')),
          4.height,
          _buildLegendItem(Icons.location_on, Colors.blue, l10n.translate('mint_location')),
          4.height,
          _buildLegendItem(Icons.label, Colors.brown, l10n.translate('region_label')),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        6.width,
        Text(label, style: secondaryTextStyle(size: 10, color: context.numColors.textMuted)),
      ],
    );
  }
}

/// Tam ekran antik harita sayfası - yatay modda gösterim
class FullScreenAncientMapPage extends StatefulWidget {
  final String? coordinates;
  final String? mintName;
  final String? regionCode;

  const FullScreenAncientMapPage({
    super.key,
    this.coordinates,
    this.mintName,
    this.regionCode,
  });

  @override
  State<FullScreenAncientMapPage> createState() => _FullScreenAncientMapPageState();
}

class _FullScreenAncientMapPageState extends State<FullScreenAncientMapPage> {
  LatLng? _focusPoint;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Yatay moda zorla; durum çubuğu gizlenir (harita tüm ekranı kullanır).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Koordinatları parse et
    if (widget.coordinates != null) {
      try {
        final coords = widget.coordinates!.split(',');
        if (coords.length == 2) {
          final lat = double.parse(coords[0].trim());
          final lng = double.parse(coords[1].trim());
          _focusPoint = LatLng(lat, lng);
        }
      } catch (e) {
        // Parse hatası - varsayılan konum kullan
      }
    }
  }

  @override
  void dispose() {
    // Normal oryantasyona ve sistem çubuklarına geri dön
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final title = widget.mintName != null && widget.mintName!.trim().isNotEmpty
        ? CoinFormat.titleCase(widget.mintName!.trim())
        : l10n.translate('ancient_map');

    // Başlık çubuğu yok: yatayda ekranın ~%20'sini kaplıyordu (2026-09-26
    // cihaz testi). Geri + başlık + konum haritanın üstünde yüzer.
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3), // Antik kağıt rengi
      body: Stack(
        children: [
          AncientMapWidget(
            controller: _mapController,
            focusPoint: _focusPoint,
            highlightMint: widget.mintName,
            filterRegion: widget.regionCode,
            isFullScreen: true,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FloatingIconButton(
                    icon: Icons.arrow_back,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  8.width,
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.card.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: boldTextStyle(size: 14, color: c.text),
                    ),
                  ),
                  if (_focusPoint != null) ...[
                    8.width,
                    _FloatingIconButton(
                      icon: Icons.my_location,
                      tooltip: l10n.translate('go_to_location'),
                      onPressed: () => _mapController.move(_focusPoint!, 9.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Harita üstünde yüzen yuvarlak düğme (geri, konum).
class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FloatingIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return Material(
      color: c.card.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: c.text),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
