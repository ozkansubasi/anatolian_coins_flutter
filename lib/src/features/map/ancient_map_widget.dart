import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/coin_format.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import 'map_locations_api.dart';
import 'map_marker_icons.dart';

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

/// Tam ekrandaki "konuma git" gibi dış komutlar için (eski flutter_map `MapController` yerine).
class AncientMapController {
  _AncientMapWidgetState? _state;

  Future<void> moveTo(LatLng target, double zoom) async => _state?._moveTo(target, zoom);
}

/// Antik harita — sitedeki `/tr/antik-harita` ile aynı yöntem: Google haritası, aynı stil
/// (`assets/data/ancient_map_style.json`: tüm etiketler kapalı, toprak/su renkleri); üstünde
/// antik bölge adları ve `/v1/locations` yerleşimleri. Site arazi türünü kullanır; Android'de
/// stil yalnız normal türde çalıştığı için burada kabartma yok. Güncel yer adları hiç
/// görünmez: güncel harita yalnız Pro'nun "Google Haritalar'da göster" bağlantısıyla açılır.
///
/// Sitenin zoom'a göre katman değiştirmesi yok; harita sikkenin darphanesine odaklanır.
class AncientMapWidget extends ConsumerStatefulWidget {
  /// Odaklanılacak koordinatlar (sikkenin darphanesi)
  final LatLng? focusPoint;

  /// Vurgulanacak darphane adı (kartta başlık)
  final String? highlightMint;

  /// Tam ekran modunda mı (değilse hareketsiz, hafif "lite" önizleme)
  final bool isFullScreen;

  final AncientMapController? controller;

  const AncientMapWidget({
    super.key,
    this.focusPoint,
    this.highlightMint,
    this.isFullScreen = false,
    this.controller,
  });

  @override
  ConsumerState<AncientMapWidget> createState() => _AncientMapWidgetState();
}

/// Bilgi kartında gösterilen yer: bir yerleşim ya da sikkenin kendi darphanesi.
class _Selection {
  final String title;
  final MapLocation? location;
  final bool isHighlight;
  final String? summary;
  final bool loadingSummary;

  const _Selection({
    required this.title,
    this.location,
    this.isHighlight = false,
    this.summary,
    this.loadingSummary = false,
  });

  _Selection copyWith({MapLocation? location, String? summary, bool? loadingSummary}) => _Selection(
        title: title,
        location: location ?? this.location,
        isHighlight: isHighlight,
        summary: summary ?? this.summary,
        loadingSummary: loadingSummary ?? this.loadingSummary,
      );
}

class _AncientMapWidgetState extends ConsumerState<AncientMapWidget> {
  static const _anatolia = LatLng(38.5, 32.0);

  /// Sitedeki `POINTS_MIN_ZOOM`: altında yalnız bölge etiketleri.
  static const _pointsMinZoom = 6.0;

  /// Sikkenin koordinatına bu kadar yakın darphane kaydı aynı yer sayılır (Cremna → LOC-0368).
  static const _sameMintKm = 8.0;

  AncientMapData? _mapData;
  String? _style;
  bool _loading = true;
  String? _error;
  GoogleMapController? _map;
  double _zoom = 8;

  // Görüntüleme seçenekleri
  bool _showRegionLabels = true;
  bool _showPoints = true;

  /// Lejant varsayılan kapalı; açıkken bilgi kartıyla çakışmasın diye kart
  /// açılınca gizlenir (2026-09-26 cihaz testi: lejant kartın üstüne biniyordu).
  bool _showLegend = false;

  final Map<String, MapLocation> _locations = {};
  final List<LatLngBounds> _loadedAreas = [];
  MapLocation? _highlightLocation;
  _Selection? _selected;

  Map<String, BitmapDescriptor> _regionIcons = const {};
  BitmapDescriptor? _mintIcon;
  BitmapDescriptor? _highlightIcon;
  BitmapDescriptor? _settlementIcon;
  String? _iconsKey;

  Timer? _idleTimer;
  int _fetchSeq = 0;

  String get _lang => Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'tr';

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _zoom = widget.focusPoint != null ? 8.0 : 6.0;
    final mint = widget.highlightMint?.trim();
    if (widget.isFullScreen && widget.focusPoint != null && mint != null && mint.isNotEmpty) {
      _selected = _Selection(title: CoinFormat.titleCase(mint), isHighlight: true);
    }
    _loadMapData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildIcons();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  Future<void> _loadMapData() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/data/ancient_map_data.json'),
        rootBundle.loadString('assets/data/ancient_map_style.json'),
      ]);
      if (!mounted) return;
      setState(() {
        _mapData = AncientMapData.fromJson(json.decode(results[0]));
        _style = results[1];
        _loading = false;
      });
      _buildIcons();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Bölge etiketleri dile ve ekran yoğunluğuna göre çizilir; ikisi değişirse yeniden.
  Future<void> _buildIcons() async {
    final data = _mapData;
    if (data == null) return;
    final l10n = AppLocalizations.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final key = '$_lang|$dpr|$font';
    if (key == _iconsKey) return;
    _iconsKey = key;

    final labels = <String, BitmapDescriptor>{};
    for (final r in data.regions) {
      labels[r.regionCode] = await MapMarkerIcons.regionLabel(
        r.displayName(l10n),
        getRegionColor(r.regionCode.replaceAll('-coins', '')),
        dpr,
        fontFamily: font,
      );
    }
    final mint = await MapMarkerIcons.mintDot(MapMarkerIcons.mintColor, dpr);
    final highlight = await MapMarkerIcons.coinMarker(dpr);
    final settlement = await MapMarkerIcons.settlementRing(dpr);
    if (!mounted || key != _iconsKey) return;
    setState(() {
      _regionIcons = labels;
      _mintIcon = mint;
      _highlightIcon = highlight;
      _settlementIcon = settlement;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _map = controller;
    final f = widget.focusPoint;
    if (!widget.isFullScreen) {
      // Önizleme hareketsiz: darphanenin çevresi bir kez yüklenir.
      if (f != null) {
        _fetch(LatLngBounds(
          southwest: LatLng(f.latitude - 1.2, f.longitude - 1.6),
          northeast: LatLng(f.latitude + 1.2, f.longitude + 1.6),
        ));
      }
      return;
    }
    _scheduleFetch();
  }

  void _onCameraIdle() {
    if (!widget.isFullScreen) return;
    setState(() {}); // zoom eşiği (_pointsMinZoom) geçildiyse işaretler güncellensin
    _scheduleFetch();
  }

  void _scheduleFetch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 350), () async {
      final map = _map;
      if (map == null || !mounted || _zoom < _pointsMinZoom) return;
      try {
        _fetch(await map.getVisibleRegion());
      } catch (_) {
        // harita kapanırken çağrıldı
      }
    });
  }

  bool _covered(LatLngBounds b) => _loadedAreas.any((a) => a.contains(b.southwest) && a.contains(b.northeast));

  Future<void> _fetch(LatLngBounds b) async {
    if (_covered(b)) return;
    final seq = ++_fetchSeq;
    final list = await ref.read(mapLocationsApiProvider).inBounds(
          swLat: b.southwest.latitude,
          swLng: b.southwest.longitude,
          neLat: b.northeast.latitude,
          neLng: b.northeast.longitude,
          lang: _lang,
        );
    if (!mounted || seq != _fetchSeq) return;
    if (list.isNotEmpty) _loadedAreas.add(b);
    setState(() {
      for (final l in list) {
        _locations[l.id] = l;
      }
    });
    _matchHighlight();
  }

  /// Sikkenin koordinatına en yakın darphane kaydı: kartta onun özeti ve makalesi gösterilir,
  /// haritada ayrıca çizilmez (vurgulu işaret zaten orada).
  void _matchHighlight() {
    final f = widget.focusPoint;
    if (f == null || _highlightLocation != null) return;
    MapLocation? best;
    var bestKm = _sameMintKm;
    for (final l in _locations.values) {
      if (!l.hasCoins) continue;
      final km = _km(f, LatLng(l.lat, l.lng));
      if (km <= bestKm) {
        best = l;
        bestKm = km;
      }
    }
    if (best == null) return;
    setState(() => _highlightLocation = best);
    final sel = _selected;
    if (sel != null && sel.isHighlight && sel.location == null) _loadSummary(sel.copyWith(location: best));
  }

  static double _km(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Ad ANINDA gösterilir; özet gelince eklenir (sitedeki açılır kartla aynı davranış).
  Future<void> _loadSummary(_Selection sel) async {
    final loc = sel.location;
    if (loc == null) {
      setState(() => _selected = sel);
      return;
    }
    setState(() {
      _selected = sel.copyWith(loadingSummary: true);
      _showLegend = false;
    });
    final summary = await ref.read(mapLocationsApiProvider).summary(loc.id, _lang);
    if (!mounted || _selected?.location?.id != loc.id) return;
    setState(() => _selected = _selected!.copyWith(summary: summary ?? '', loadingSummary: false));
  }

  void _selectHighlight() {
    final mint = widget.highlightMint?.trim();
    final title = (mint != null && mint.isNotEmpty)
        ? CoinFormat.titleCase(mint)
        : (_highlightLocation?.name ?? AppLocalizations.of(context).translate('highlighted_mint'));
    _loadSummary(_Selection(title: title, location: _highlightLocation, isHighlight: true));
  }

  Future<void> _moveTo(LatLng target, double zoom) async {
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    final data = _mapData;
    if (data != null && _showRegionLabels) {
      for (final r in data.regions) {
        final icon = _regionIcons[r.regionCode];
        if (icon == null) continue;
        markers.add(Marker(
          markerId: MarkerId('region_${r.regionCode}'),
          position: LatLng(r.lat, r.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          consumeTapEvents: true,
        ));
      }
    }

    final showPoints = _showPoints && (!widget.isFullScreen || _zoom >= _pointsMinZoom);
    if (showPoints && _mintIcon != null && _settlementIcon != null) {
      for (final l in _locations.values) {
        if (l.id == _highlightLocation?.id) continue;
        // Önizleme sade: yalnız darphaneler (yerleşimler tam ekranda; cihazda kalabalıktı)
        if (!widget.isFullScreen && !l.hasCoins) continue;
        markers.add(Marker(
          markerId: MarkerId('loc_${l.id}'),
          position: LatLng(l.lat, l.lng),
          icon: l.hasCoins ? _mintIcon! : _settlementIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: l.hasCoins ? 3 : 2,
          consumeTapEvents: true,
          onTap: widget.isFullScreen ? () => _loadSummary(_Selection(title: l.name, location: l)) : null,
        ));
      }
    }

    final f = widget.focusPoint;
    if (f != null && _highlightIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('highlight'),
        position: f,
        icon: _highlightIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10,
        consumeTapEvents: true,
        onTap: widget.isFullScreen ? _selectHighlight : null,
      ));
    }
    return markers;
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
    final initialCenter = widget.focusPoint ?? _anatolia;
    final initialZoom = widget.focusPoint != null ? 8.0 : 6.0;

    return Stack(
      children: [
        // Harita: sitedeki antik harita stili (etiketsiz, aynı renkler). Android'de JSON stil
        // (bulut stili dahil) yalnız normal türde uygulanır; arazi türünde stil tümüyle
        // yok sayılıyor, güncel adlar görünüyordu (2026-09-27 cihaz + Cloud önizleme).
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialCenter, zoom: initialZoom),
          style: _style,
          mapType: MapType.normal,
          liteModeEnabled: !widget.isFullScreen,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: widget.isFullScreen,
          zoomGesturesEnabled: widget.isFullScreen,
          minMaxZoomPreference: const MinMaxZoomPreference(4, 12),
          markers: _markers(),
          onMapCreated: _onMapCreated,
          onCameraMove: (position) => _zoom = position.zoom,
          onCameraIdle: _onCameraIdle,
          onTap: (_) {
            if (_selected != null) setState(() => _selected = null);
          },
        ),

        // Kontrol paneli (tam ekran modunda). Yatayda yükseklik az: sığmazsa kayar.
        if (widget.isFullScreen)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  // Sabit genişlik: paneldeki Divider'lar verilen tüm genişliği
                  // kaplıyordu, panel haritanın üstünü örttü (cihazda görüldü).
                  child: SizedBox(
                    width: 52,
                    child: SingleChildScrollView(child: _buildControlPanel(l10n)),
                  ),
                ),
              ),
            ),
          ),

        // Seçili yerin bilgi kartı (yalnız tam ekran; önizlemede 'Haritada
        // göster' katmanıyla çakışıyordu). Yatayda tüm genişliği kaplamasın.
        if (widget.isFullScreen && _selected != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _buildInfoCard(l10n),
              ),
            ),
          ),

        // Lejant: istek üzerine, kart açık değilken
        if (widget.isFullScreen && _showLegend && _selected == null)
          Positioned(
            bottom: 12,
            left: 12,
            child: SafeArea(child: _buildLegend(l10n)),
          ),
      ],
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
            onPressed: () => _map?.animateCamera(CameraUpdate.zoomIn()),
          ),
          4.height,
          _buildControlButton(
            icon: Icons.zoom_out,
            onPressed: () => _map?.animateCamera(CameraUpdate.zoomOut()),
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
            isActive: _showPoints,
            onPressed: () => setState(() => _showPoints = !_showPoints),
            tooltip: l10n.translate('show_mints'),
          ),
          4.height,
          _buildToggleButton(
            icon: Icons.info_outline,
            isActive: _showLegend,
            onPressed: () => setState(() {
              _showLegend = !_showLegend;
              if (_showLegend) _selected = null;
            }),
            tooltip: l10n.translate('legend'),
          ),
          const Divider(height: 16),
          _buildControlButton(
            icon: Icons.center_focus_strong,
            onPressed: () => _moveTo(_anatolia, 6.0),
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

  /// Bilgi kartı: sitedeki açılır kartla aynı içerik — ad, özet, "Makaleyi aç".
  Widget _buildInfoCard(AppLocalizations l10n) {
    final sel = _selected;
    if (sel == null) return const SizedBox.shrink();

    final isMint = sel.isHighlight || (sel.location?.hasCoins ?? false);
    final color = sel.isHighlight
        ? MapMarkerIcons.coinHighlightColor
        : isMint
            ? MapMarkerIcons.mintColor
            : MapMarkerIcons.settlementColor;
    final c = context.numColors;
    final articleId = sel.location?.articleId;
    final summary = sel.loadingSummary ? l10n.translate('loading') : sel.summary;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(isMint ? Icons.account_balance : Icons.place_outlined, color: color, size: 18),
          ),
          12.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sel.title, style: boldTextStyle(size: 15, color: c.text)),
                if (summary != null && summary.isNotEmpty) ...[
                  4.height,
                  Text(
                    summary,
                    style: secondaryTextStyle(size: 12, color: c.textMuted),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (articleId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        foregroundColor: c.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openArticle(articleId),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: Text(l10n.translate('open_article')),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selected = null),
            iconSize: 20,
            color: c.textMuted,
          ),
        ],
      ),
    );
  }

  /// Makale uygulama içinde açılır. Tam ekran harita yatay ve kök navigatörde: önce kapanır,
  /// makale sikke detayının üstüne gelir (geri → sikke).
  void _openArticle(int articleId) {
    final router = GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).maybePop();
    router.push('/article/$articleId');
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
          _buildLegendItem(Icons.account_balance, MapMarkerIcons.coinHighlightColor, l10n.translate('highlighted_mint')),
          4.height,
          _buildLegendItem(Icons.location_on, MapMarkerIcons.mintColor, l10n.translate('mint_location')),
          4.height,
          _buildLegendItem(Icons.radio_button_unchecked, MapMarkerIcons.settlementColor,
              l10n.translate('settlement_location')),
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

  const FullScreenAncientMapPage({
    super.key,
    this.coordinates,
    this.mintName,
  });

  @override
  State<FullScreenAncientMapPage> createState() => _FullScreenAncientMapPageState();
}

class _FullScreenAncientMapPageState extends State<FullScreenAncientMapPage> {
  LatLng? _focusPoint;
  final AncientMapController _mapController = AncientMapController();

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
    // Uygulamanın varsayılanına dön (main.dart: edgeToEdge). `manual`
    // gezinme çubuğunu siyah bırakıyordu (cihazda görüldü).
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
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
                      onPressed: () => _mapController.moveTo(_focusPoint!, 9.0),
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
