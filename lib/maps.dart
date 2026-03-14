// ==========================================
// 5. MAP SCREEN
// ==========================================
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:blankmap_mobile/shared.dart';
import 'package:latlong2/latlong.dart';

// ==========================================
// MAP PIN MODEL
// ==========================================
class MapPin {
  final String id;
  final LatLng location;
  final String layer;
  MapPin({required this.id, required this.location, required this.layer});
}

class MapScreen extends StatefulWidget {
  final String activeLayer;
  final Function(String) onLayerChanged;
  const MapScreen({
    super.key,
    required this.activeLayer,
    required this.onLayerChanged,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  final _storage = const FlutterSecureStorage();

  LatLng _userLoc = const LatLng(28.6315, 77.2167);
  bool _locLoaded = false;

  List<MapPin> _pins = [];
  bool _pinsLoading = false;

  final Map<String, String> _layerNameToId = {};

  @override
  void initState() {
    super.initState();
    _initLoc();
    _loadBlankMapIds().then((_) => _fetchPins());
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (old.activeLayer != widget.activeLayer) _fetchPins();
  }

  Future<String?> _getToken() => _storage.read(key: 'jwt');

  // ── Resolve layer name → blank-map UUID ─────────────────────────────────
  Future<void> _loadBlankMapIds() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/blank-maps'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        for (final m in data) {
          final name = (m['name'] ?? m['tag'] ?? '') as String;
          final id = (m['id'] ?? '') as String;
          if (name.isNotEmpty && id.isNotEmpty) _layerNameToId[name] = id;
        }
      }
    } catch (e) {
      debugPrint('Load blank-map IDs error: $e');
    }
  }

  String? get _activeBlankMapId => _layerNameToId[widget.activeLayer];

  // ── Location ─────────────────────────────────────────────────────────────
  Future<void> _initLoc() async {
    try {
      bool svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _userLoc = loc;
          _locLoaded = true;
        });
        _mapCtrl.move(loc, 15.5);
      }
    } catch (_) {}
  }

  // ── Fetch pins ────────────────────────────────────────────────────────────
  Future<void> _fetchPins() async {
    final mapId = _activeBlankMapId;
    if (mapId == null || mapId.isEmpty) return;
    setState(() => _pinsLoading = true);
    try {
      final token = await _getToken();
      final uri = Uri.parse(
        '$baseUrl/pins',
      ).replace(queryParameters: {'blank_map_id': mapId});
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final pins = data
            .map(
              (json) => MapPin(
                id: json['id'] as String,
                location: LatLng(
                  (json['latitude'] as num).toDouble(),
                  (json['longitude'] as num).toDouble(),
                ),
                layer: widget.activeLayer,
              ),
            )
            .toList();
        if (mounted) setState(() => _pins = pins);
      }
    } catch (e) {
      debugPrint('Fetch pins exception: $e');
    } finally {
      if (mounted) setState(() => _pinsLoading = false);
    }
  }

  // ── Drop pin ──────────────────────────────────────────────────────────────
  void _dropPin() async {
    final mapId = _activeBlankMapId;
    if (mapId == null || mapId.isEmpty) {
      _toast('Select a map layer first');
      return;
    }
    final center = _mapCtrl.camera.center;
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('$baseUrl/pins'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': 'Pin on ${widget.activeLayer}',
          'blank_map_id': mapId,
          'latitude': center.latitude,
          'longitude': center.longitude,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final newPin = MapPin(
          id: json['id'] as String,
          location: LatLng(
            (json['latitude'] as num).toDouble(),
            (json['longitude'] as num).toDouble(),
          ),
          layer: widget.activeLayer,
        );
        if (mounted) setState(() => _pins.add(newPin));
        _toast('Pinned to ${widget.activeLayer}  ·  +10 Karma');
      } else {
        _toast('Failed to drop pin');
      }
    } catch (e) {
      _toast('Failed to drop pin');
    }
  }

  // ── POST /feedback  { pin_id, rating: 1–5 } ──────────────────────────────
  Future<void> _submitRating(String pinId, int rating) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$baseUrl/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pin_id': pinId, 'rating': rating}),
      );
    } catch (e) {
      debugPrint('Submit rating error: $e');
    }
  }

  // ── GET /pins/:id/rating  → { total_reviews, average_rating } ───────────
  Future<Map<String, dynamic>?> _fetchRating(String pinId) async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/pins/$pinId/rating'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Fetch rating error: $e');
    }
    return null;
  }

  // ── Delete pin ────────────────────────────────────────────────────────────
  Future<void> _deletePin(MapPin pin) async {
    try {
      final token = await _getToken();
      final res = await http.delete(
        Uri.parse('$baseUrl/pins/${pin.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        if (mounted) setState(() => _pins.remove(pin));
        _toast('Pin removed');
      } else {
        _toast('Failed to remove pin');
      }
    } catch (e) {
      _toast('Failed to remove pin');
    }
  }

  // ── Toast ─────────────────────────────────────────────────────────────────
  void _toast(String msg) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Align(
        alignment: const Alignment(0, 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: BM.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: BM.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: BM.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: BM.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  // ── Pin sheet ─────────────────────────────────────────────────────────────
  void _showPinSheet(MapPin pin) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _PinSheet(
        pin: pin,
        fetchRating: () => _fetchRating(pin.id),
        onRate: (rating) => _submitRating(pin.id, rating),
        onDelete: () {
          Navigator.pop(ctx);
          _deletePin(pin);
        },
        onRated: () => _toast('Thanks for rating!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePins = _pins
        .where((p) => p.layer == widget.activeLayer)
        .toList();
    final topPad = MediaQuery.of(context).padding.top;

    return CupertinoPageScaffold(
      backgroundColor: BM.bg,
      child: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(initialCenter: _userLoc, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hackathon.blankmap',
              ),
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: const DefaultLocationMarker(
                    color: BM.accent,
                    child: Icon(
                      CupertinoIcons.location_fill,
                      color: BM.bg,
                      size: 12,
                    ),
                  ),
                  markerSize: const Size(30, 30),
                  accuracyCircleColor: BM.accentSoft,
                  headingSectorColor: BM.accentGlow,
                ),
              ),
              MarkerLayer(
                markers: activePins.map((pin) {
                  return Marker(
                    point: pin.location,
                    width: 44,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _showPinSheet(pin),
                      child: const Column(
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            color: BM.accent,
                            size: 38,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // ── CROSSHAIR ────────────────────────────────────────────────
          const Center(
            child: Icon(CupertinoIcons.plus, color: Colors.black54, size: 26),
          ),
          // ── LOCATE ME ────────────────────────────────────────────────
          Positioned(
            bottom: 85,
            right: 20,
            child: GestureDetector(
              onTap: () {
                if (_locLoaded) _mapCtrl.move(_userLoc, 16.0);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: BM.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: BM.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _locLoaded
                      ? CupertinoIcons.location_fill
                      : CupertinoIcons.location,
                  color: _locLoaded ? BM.accent : BM.textTer,
                  size: 18,
                ),
              ),
            ),
          ),
          // ── PINS LOADING ──────────────────────────────────────────────
          if (_pinsLoading)
            Positioned(
              top: topPad + 58,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: BM.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BM.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(color: BM.accent, radius: 7),
                    SizedBox(width: 8),
                    Text(
                      'Loading pins...',
                      style: TextStyle(
                        color: BM.textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── GPS LOADING ───────────────────────────────────────────────
          if (!_locLoaded)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: BM.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: BM.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(color: BM.accent),
                      SizedBox(width: 10),
                      Text(
                        'Finding your location...',
                        style: TextStyle(
                          color: BM.textSec,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ── DROP PIN BUTTON ───────────────────────────────────────────
          Positioned(
            bottom: 20,
            left: 18,
            right: 18,
            child: GestureDetector(
              onTap: _dropPin,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: BM.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(51, 0, 0, 0),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.location_fill,
                      color: BM.bg,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pin to ${widget.activeLayer}',
                      style: const TextStyle(
                        color: BM.bg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PIN SHEET WIDGET
// ==========================================
class _PinSheet extends StatefulWidget {
  final MapPin pin;
  final Future<Map<String, dynamic>?> Function() fetchRating;
  final Future<void> Function(int rating) onRate;
  final VoidCallback onDelete;
  final VoidCallback onRated;

  const _PinSheet({
    required this.pin,
    required this.fetchRating,
    required this.onRate,
    required this.onDelete,
    required this.onRated,
  });

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  int _selectedStars = 0;
  int _totalReviews = 0;
  double _avgRating = 0;
  bool _loadingRating = true;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    final data = await widget.fetchRating();
    if (mounted) {
      setState(() {
        _totalReviews = (data?['total_reviews'] as num?)?.toInt() ?? 0;
        _avgRating = (data?['average_rating'] as num?)?.toDouble() ?? 0;
        _loadingRating = false;
      });
    }
  }

  Future<void> _rate(int stars) async {
    setState(() {
      _selectedStars = stars;
      _submitted = true;
    });
    await widget.onRate(stars);
    // Refresh from API after submitting
    final data = await widget.fetchRating();
    if (mounted) {
      setState(() {
        _totalReviews = (data?['total_reviews'] as num?)?.toInt() ?? 0;
        _avgRating = (data?['average_rating'] as num?)?.toDouble() ?? 0;
      });
    }
    widget.onRated();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      decoration: BoxDecoration(
        color: BM.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BM.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: BM.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: BM.accentSoft,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: BM.accent.withOpacity(0.35)),
            ),
            child: const Icon(
              CupertinoIcons.location_solid,
              color: BM.accent,
              size: 38,
              shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.pin.layer,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: BM.textPri,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.pin.location.latitude.toStringAsFixed(5)}, '
            '${widget.pin.location.longitude.toStringAsFixed(5)}',
            style: const TextStyle(color: BM.textTer, fontSize: 11),
          ),
          const SizedBox(height: 20),

          // ── Current rating summary ──────────────────────────────────
          _loadingRating
              ? const CupertinoActivityIndicator(color: BM.accent, radius: 8)
              : _totalReviews == 0
              ? const Text(
                  'No ratings yet',
                  style: TextStyle(color: BM.textTer, fontSize: 12),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.star_fill,
                      color: Color(0xFFFFC107),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _avgRating % 1 == 0
                          ? '${_avgRating.toInt()}'
                          : _avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: BM.textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($_totalReviews ${_totalReviews == 1 ? 'rating' : 'ratings'})',
                      style: const TextStyle(color: BM.textTer, fontSize: 12),
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // ── Star picker (locked after submit) ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _selectedStars;
              return GestureDetector(
                onTap: _submitted ? null : () => _rate(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    color: filled ? const Color(0xFFFFC107) : BM.textTer,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // ── Delete ──────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: BM.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: BM.danger.withOpacity(0.25)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.trash, color: BM.danger, size: 15),
                  SizedBox(width: 8),
                  Text(
                    'Remove Pin',
                    style: TextStyle(
                      color: BM.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
