import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dem_engine.dart';

void main() {
  runApp(const UGVApp());
}

class UGVApp extends StatelessWidget {
  const UGVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UGV Tactical Offline GIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF0284C7),
      ),
      home: const TerrainMapView(),
    );
  }
}

class TerrainMapView extends StatefulWidget {
  const TerrainMapView({super.key});

  @override
  State<TerrainMapView> createState() => _TerrainMapViewState();
}

class _TerrainMapViewState extends State<TerrainMapView> {
  // Sector center over Jammu & Kashmir (Srinagar region)
  static const LatLng jkCenter = LatLng(34.0836, 74.7973);
  static const double initialZoomLevel = 8.0;

  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  UGVTerrainSpecs? _specs;
  bool _calculating = false;

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom + 1.0).clamp(6.0, 14.0);
    _mapController.move(_mapController.camera.center, targetZoom);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom - 1.0).clamp(6.0, 14.0);
    _mapController.move(_mapController.camera.center, targetZoom);
  }

  void _resetView() {
    setState(() {
      _selectedPoint = null;
      _specs = null;
      _calculating = false;
    });
    _mapController.move(jkCenter, initialZoomLevel);
  }

  void _onMapTapped(TapPosition pos, LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _calculating = true;
      _specs = null;
    });

    try {
      final zoom = _mapController.camera.zoom.round();
      final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
      if (mounted) {
        setState(() {
          _specs = specs;
          _calculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calculating = false;
          _specs = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UGV Offline Terrain Analyzer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Jammu & Kashmir Sector | Offline Copernicus DEM',
                style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Map & Clear Selection',
            icon: const Icon(Icons.refresh),
            onPressed: _resetView,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: jkCenter,
              initialZoom: initialZoomLevel,
              minZoom: 6.0,
              maxZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              // containCenter avoids locking the desktop camera viewport
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(
                  const LatLng(31.5, 72.5),
                  const LatLng(37.5, 79.0),
                ),
              ),
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: 'assets/map_tiles/{z}_{x}_{y}.png',
                tileProvider: AssetTileProvider(),
                maxNativeZoom: 9,
                maxZoom: 14.0,
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top Info Banner
          Positioned(
            top: 10,
            left: 10,
            right: 80,
            child: Card(
              color: const Color(0xEE0F172A),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: const [
                    Icon(Icons.satellite_alt,
                        color: Colors.greenAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '100% Offline Mode. Tap any location on the map to evaluate terrain parameters.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom & Reset Floating Button Column
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  tooltip: 'Zoom In (+)',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  tooltip: 'Zoom Out (-)',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_recenter',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.greenAccent,
                  tooltip: 'Recenter on Base',
                  onPressed: () => _mapController.move(jkCenter, initialZoomLevel),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // Specs Bottom Display Overlay
          if (_selectedPoint != null && (_calculating || _specs != null))
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Card(
                color: const Color(0xFF0F172A),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _specs == null
                        ? Colors.blueAccent
                        : (_specs!.isPassable ? Colors.green : Colors.red),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: _calculating
                      ? const SizedBox(
                    height: 70,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                          SizedBox(width: 14),
                          Text(
                            'Reading Copernicus DEM Elevation...',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _specs!.terrainType,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _specs!.isPassable
                                      ? Colors.green.withAlpha(40)
                                      : Colors.red.withAlpha(40),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _specs!.isPassable
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  '${_specs!.safetyRating} (${_specs!.isPassable ? "PASSABLE" : "NO-GO"})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _specs!.isPassable
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedPoint = null;
                                    _specs = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DataCell(
                            label: 'Elevation',
                            value:
                            '${_specs!.elevationMeters.toStringAsFixed(1)} m',
                          ),
                          _DataCell(
                            label: 'Slope Angle',
                            value:
                            '${_specs!.slopeDegrees.toStringAsFixed(1)}°',
                          ),
                          _DataCell(
                            label: 'Steepness',
                            value:
                            '${_specs!.steepnessPercentage.toStringAsFixed(1)}%',
                          ),
                          _DataCell(
                            label: 'Aspect',
                            value:
                            '${_specs!.aspectDegrees.toStringAsFixed(0)}° ${_specs!.aspectDirection}',
                          ),
                          _DataCell(
                            label: 'Roughness',
                            value: _specs!.roughnessIndex
                                .toStringAsFixed(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Coordinate: ${_selectedPoint!.latitude.toStringAsFixed(5)}° N, ${_selectedPoint!.longitude.toStringAsFixed(5)}° E',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontFamily: 'monospace',
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

class _DataCell extends StatelessWidget {
  final String label;
  final String value;

  const _DataCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}