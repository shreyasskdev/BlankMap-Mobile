// ==========================================
// 5. MAP SCREEN
// ==========================================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:blankmap_mobile/shared.dart';
import 'package:latlong2/latlong.dart';

// ==========================================
// 4. MAP PIN MODEL
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
  LatLng _userLoc = const LatLng(28.6315, 77.2167);
  bool _locLoaded = false;

  static final List<MapPin> _pins = [];

  final List<String> _quickLayers = allBlankMaps
      .take(6)
      .map((m) => m['tag'] as String)
      .toList();

  @override
  void initState() {
    super.initState();
    _initLoc();
  }

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

  void _dropPin() {
    setState(() {
      _pins.add(
        MapPin(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          location: _mapCtrl.camera.center,
          layer: widget.activeLayer,
        ),
      );
    });
    _toast('Pinned to ${widget.activeLayer}  ·  +10 Karma');
  }

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
                  // Works
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setSheet(() => pin.upvotes++);
                        setState(() {});
                        Navigator.pop(ctx);
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
                  // Broken
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setSheet(() => pin.downvotes++);
                        setState(() {});
                        Navigator.pop(ctx);
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
