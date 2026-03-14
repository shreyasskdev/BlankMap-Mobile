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
// 4. MAP PIN MODEL  (unchanged)
// ==========================================
class MapPin {
  final String id;
  final LatLng location;
  final String layer;
  int upvotes;
  int downvotes;
  MapPin({
    required this.id,
    required this.location,
    required this.layer,
    this.upvotes = 1,
    this.downvotes = 0,
  });
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

  // Pins are fetched from the API and kept here
  List<MapPin> _pins = [];
  bool _pinsLoading = false;

  // Maps layer display-name → blank-map UUID (resolved once on init)
  final Map<String, String> _layerNameToId = {};

  final List<String> _quickLayers = allBlankMaps
      .take(6)
      .map((m) => m['tag'] as String)
      .toList();

  @override
  void initState() {
    super.initState();
    _initLoc();
    _loadBlankMapIds().then((_) => _fetchPins());
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (old.activeLayer != widget.activeLayer) {
      _fetchPins();
    }
  }

  // ── Auth helper ──────────────────────────────────────────────────────────
  Future<String?> _getToken() => _storage.read(key: 'jwt');

  // ── Resolve layer name → blank-map UUID from GET /blank-maps ────────────
  Future<void> _loadBlankMapIds() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/blank-maps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
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

  // ==========================================
  // API – GET /pins?blank_map_id=<uuid>
  // ==========================================
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
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;

        // Fetch feedback counts for all pins concurrently
        final pins = await Future.wait(
          data.map((json) async {
            final pinId = json['id'] as String;
            final counts = await _fetchFeedbackCounts(pinId);
            return MapPin(
              id: pinId,
              location: LatLng(
                (json['latitude'] as num).toDouble(),
                (json['longitude'] as num).toDouble(),
              ),
              layer: widget.activeLayer,
              upvotes: counts.$1,
              downvotes: counts.$2,
            );
          }),
        );

        if (mounted) setState(() => _pins = pins);
      } else {
        debugPrint('Fetch pins error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Fetch pins exception: $e');
    } finally {
      if (mounted) setState(() => _pinsLoading = false);
    }
  }

  // ==========================================
  // API – GET /pins/:pinID/feedback  → (upvotes, downvotes)
  // rating >= 1  → upvote
  // rating <= -1 → downvote
  // ==========================================
  Future<(int, int)> _fetchFeedbackCounts(String pinId) async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/pins/$pinId/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        int up = 0, down = 0;
        for (final f in list) {
          final rating = f['rating'] as int? ?? 0;
          if (rating >= 1) up++;
          if (rating <= -1) down++;
        }
        return (up, down);
      }
    } catch (e) {
      debugPrint('Fetch feedback error for $pinId: $e');
    }
    return (0, 0);
  }

  // ==========================================
  // API – POST /pins  (replaces the old local-only _dropPin)
  // ==========================================
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
          upvotes: 1,
          downvotes: 0,
        );
        if (mounted) setState(() => _pins.add(newPin));
        _toast('Pinned to ${widget.activeLayer}  ·  +10 Karma');
      } else {
        debugPrint('Create pin error ${res.statusCode}: ${res.body}');
        _toast('Failed to drop pin');
      }
    } catch (e) {
      debugPrint('Drop pin exception: $e');
      _toast('Failed to drop pin');
    }
  }

  // ==========================================
  // API – POST /feedback  (upvote rating=1 / downvote rating=-1)
  // ==========================================
  Future<void> _submitFeedback({
    required MapPin pin,
    required int rating,
    required VoidCallback onSuccess,
  }) async {
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('$baseUrl/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pin_id': pin.id, 'rating': rating}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        onSuccess();
      } else {
        debugPrint('Feedback error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Feedback exception: $e');
    }
  }

  // ==========================================
  // API – DELETE /pins/:id
  // ==========================================
  Future<void> _deletePin(MapPin pin) async {
    try {
      final token = await _getToken();
      final res = await http.delete(
        Uri.parse('$baseUrl/pins/${pin.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        if (mounted) setState(() => _pins.remove(pin));
        _toast('Pin removed');
      } else {
        debugPrint('Delete pin error ${res.statusCode}: ${res.body}');
        _toast('Failed to remove pin');
      }
    } catch (e) {
      debugPrint('Delete pin exception: $e');
      _toast('Failed to remove pin');
    }
  }

  // ── Toast (unchanged) ────────────────────────────────────────────────────
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

  // ── Pin sheet – upvote/downvote now call API; delete button added ─────────
  void _showPinSheet(MapPin pin) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
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
              // Handle bar
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
                pin.layer,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BM.textPri,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pin.location.latitude.toStringAsFixed(5)}, '
                '${pin.location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: BM.textTer, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: BM.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BM.success.withOpacity(0.3)),
                ),
                child: const Text(
                  '✓  Community Verified',
                  style: TextStyle(
                    color: BM.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Works – POST /feedback rating=1
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _submitFeedback(
                          pin: pin,
                          rating: 1,
                          onSuccess: () {
                            setSheet(() => pin.upvotes++);
                            setState(() {});
                            Navigator.pop(ctx);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: BM.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: BM.success.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.hand_thumbsup_fill,
                              color: BM.success,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${pin.upvotes}  Works',
                              style: const TextStyle(
                                color: BM.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Broken – POST /feedback rating=-1
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _submitFeedback(
                          pin: pin,
                          rating: -1,
                          onSuccess: () {
                            setSheet(() => pin.downvotes++);
                            setState(() {});
                            Navigator.pop(ctx);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: BM.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: BM.danger.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              CupertinoIcons.hand_thumbsdown_fill,
                              color: BM.danger,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${pin.downvotes}  Broken',
                              style: const TextStyle(
                                color: BM.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Delete pin – DELETE /pins/:id
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _deletePin(pin);
                },
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
        ),
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
          // ── MAP ──────────────────────────────────
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
                      child: Column(
                        children: const [
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
          // ── CROSSHAIR ────────────────────────────
          const Center(
            child: Icon(CupertinoIcons.plus, color: Colors.black54, size: 26),
          ),
          // ── TOP GRADIENT + LAYER CHIPS ────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: topPad + 8, bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [BM.bg.withOpacity(0.96), BM.bg.withOpacity(0.0)],
                  stops: const [0.35, 1.0],
                ),
              ),
              child: SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _quickLayers.length,
                  itemBuilder: (_, i) {
                    final l = _quickLayers[i];
                    final sel = l == widget.activeLayer;
                    return GestureDetector(
                      onTap: () => widget.onLayerChanged(l),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? BM.accent : BM.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: sel ? BM.accent : BM.border,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: BM.accentGlow,
                                    blurRadius: 12,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          l,
                          style: TextStyle(
                            color: sel ? BM.bg : BM.textSec,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // ── LOCATE ME BUTTON ─────────────────────
          Positioned(
            top: topPad + 58,
            right: 14,
            child: GestureDetector(
              onTap: () {
                if (_locLoaded) _mapCtrl.move(_userLoc, 16.0);
              },
              child: Container(
                width: 42,
                height: 42,
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
          // ── PINS LOADING INDICATOR ────────────────
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
          // ── GPS LOADING ───────────────────────────
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
          // ── DROP PIN BUTTON ───────────────────────
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
