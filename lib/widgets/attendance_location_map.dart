import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geofence_service.dart';
import '../theme/colors.dart';

class AttendanceLocationMap extends StatefulWidget {
  const AttendanceLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.title = 'Lokasi GPS realtime',
    this.showLiveIndicator = true,
    this.showCampusBoundary = false,
    this.mapHeight = 230,
  });

  final double latitude;
  final double longitude;
  final String title;
  final bool showLiveIndicator;
  final bool showCampusBoundary;
  final double mapHeight;

  @override
  State<AttendanceLocationMap> createState() => _AttendanceLocationMapState();
}

class _AttendanceLocationMapState extends State<AttendanceLocationMap> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  LatLng get _position => LatLng(widget.latitude, widget.longitude);

  @override
  void didUpdateWidget(covariant AttendanceLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      _mapController.move(_position, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.radar_rounded, color: AppColors.primary, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.showLiveIndicator) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF27AE60),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Live',
                style: TextStyle(
                  color: Color(0xFF238451),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.mapHeight,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _position,
                initialZoom: 17,
                onMapReady: () => _mapReady = true,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'smart_presensi',
                ),
                if (widget.showCampusBoundary)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: [
                          LatLng(
                            CampusGeofence.southLatitude,
                            CampusGeofence.westLongitude,
                          ),
                          LatLng(
                            CampusGeofence.southLatitude,
                            CampusGeofence.eastLongitude,
                          ),
                          LatLng(
                            CampusGeofence.northLatitude,
                            CampusGeofence.eastLongitude,
                          ),
                          LatLng(
                            CampusGeofence.northLatitude,
                            CampusGeofence.westLongitude,
                          ),
                        ],
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _position,
                      width: 48,
                      height: 56,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primary,
                        size: 48,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
