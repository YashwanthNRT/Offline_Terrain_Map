import 'dart:math' as math;
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

enum AppMode { pointInspect, routePlan }

class RouteWaypoint {
  final LatLng coordinate;
  final double distanceFromStartMeters;
  final UGVTerrainSpecs specs;

  RouteWaypoint({
    required this.coordinate,
    required this.distanceFromStartMeters,
    required this.specs,
  });
}

class TerrainMapView extends StatefulWidget {
  const TerrainMapView({super.key});

  @override
  State<TerrainMapView> createState() => _TerrainMapViewState();
}

class _TerrainMapViewState extends State<TerrainMapView> {
  static const LatLng jkCenter = LatLng(34.0836, 74.7973);
  static const double initialZoomLevel = 8.0;

  final MapController _mapController = MapController();

  AppMode _currentMode = AppMode.pointInspect;

  // Single Point Mode State
  LatLng? _singleSelectedPoint;
  UGVTerrainSpecs? _singlePointSpecs;

  // Zig-Zag Route Mode State
  List<LatLng> _routePoints = [];
  List<RouteWaypoint> _routeWaypoints = [];
  int _selectedWaypointIndex = 0;
  double _totalRouteDistanceMeters = 0.0;
  double _maxRouteSlope = 0.0;
  bool _isRouteOverallPassable = true;

  bool _isProcessing = false;

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

  void _resetAll() {
    setState(() {
      _singleSelectedPoint = null;
      _singlePointSpecs = null;
      _routePoints.clear();
      _routeWaypoints.clear();
      _selectedWaypointIndex = 0;
      _totalRouteDistanceMeters = 0.0;
      _maxRouteSlope = 0.0;
      _isRouteOverallPassable = true;
      _isProcessing = false;
    });
    _mapController.move(jkCenter, initialZoomLevel);
  }

  void _undoLastRoutePoint() {
    if (_routePoints.isEmpty) return;
    setState(() {
      _routePoints.removeLast();
      _routeWaypoints.removeLast();

      if (_routePoints.isEmpty) {
        _resetAll();
      } else {
        _recalculateRouteSummary();
        if (_selectedWaypointIndex >= _routeWaypoints.length) {
          _selectedWaypointIndex = _routeWaypoints.length - 1;
        }
      }
    });
  }

  void _recalculateRouteSummary() {
    _totalRouteDistanceMeters = _routeWaypoints.last.distanceFromStartMeters;
    _maxRouteSlope = 0.0;
    _isRouteOverallPassable = true;

    for (var wp in _routeWaypoints) {
      if (wp.specs.slopeDegrees > _maxRouteSlope) {
        _maxRouteSlope = wp.specs.slopeDegrees;
      }
      if (!wp.specs.isPassable) {
        _isRouteOverallPassable = false;
      }
    }
  }

  void _onMapTapped(TapPosition pos, LatLng point) async {
    if (_isProcessing) return;

    if (_currentMode == AppMode.pointInspect) {
      await _handleSinglePointTap(point);
    } else {
      await _handleMultiRouteTap(point);
    }
  }

  Future<void> _handleSinglePointTap(LatLng point) async {
    setState(() {
      _singleSelectedPoint = point;
      _singlePointSpecs = null;
      _isProcessing = true;
    });

    try {
      final zoom = _mapController.camera.zoom.round();
      final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
      if (mounted) {
        setState(() {
          _singlePointSpecs = specs;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _singlePointSpecs = null;
        });
        _showError(e.toString());
      }
    }
  }

  Future<void> _handleMultiRouteTap(LatLng point) async {
    setState(() => _isProcessing = true);

    try {
      final zoom = _mapController.camera.zoom.round();
      final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);

      double distFromStart = 0.0;
      if (_routePoints.isNotEmpty) {
        const Distance distanceCalc = Distance();
        final double segmentDist =
        distanceCalc.as(LengthUnit.Meter, _routePoints.last, point);
        distFromStart =
            _routeWaypoints.last.distanceFromStartMeters + segmentDist;
      }

      if (mounted) {
        setState(() {
          _routePoints.add(point);
          _routeWaypoints.add(
            RouteWaypoint(
              coordinate: point,
              distanceFromStartMeters: distFromStart,
              specs: specs,
            ),
          );

          _recalculateRouteSummary();

          // Automatically focus the slider on the newly dropped point
          _selectedWaypointIndex = _routeWaypoints.length - 1;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeWaypoint = (_routeWaypoints.isNotEmpty &&
        _selectedWaypointIndex < _routeWaypoints.length)
        ? _routeWaypoints[_selectedWaypointIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tactical UGV Terrain Analyzer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _currentMode == AppMode.pointInspect
                  ? 'Mode: Spot Coordinate Inspector'
                  : 'Mode: Zig-Zag Route Planner',
              style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear & Reset',
            icon: const Icon(Icons.refresh),
            onPressed: _resetAll,
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

              // Polyline rendering for the zig-zag path
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: _isRouteOverallPassable
                          ? Colors.cyanAccent
                          : Colors.orangeAccent,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // Single Point Mode Marker
                  if (_currentMode == AppMode.pointInspect &&
                      _singleSelectedPoint != null)
                    Marker(
                      point: _singleSelectedPoint!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),

                  // Route Mode: Tapped Waypoints
                  if (_currentMode == AppMode.routePlan)
                    ..._routePoints.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final pt = entry.value;
                      final isStart = idx == 0;
                      final isEnd = idx == _routePoints.length - 1 && idx > 0;

                      return Marker(
                        point: pt,
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isStart
                                ? Colors.green
                                : (isEnd ? Colors.red : Colors.blueAccent),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              isStart ? 'S' : (isEnd ? 'E' : '${idx + 1}'),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                  // Route Mode: Active Inspected Slider Ring (Yellow Highlight)
                  if (_currentMode == AppMode.routePlan &&
                      activeWaypoint != null)
                    Marker(
                      point: activeWaypoint.coordinate,
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.amberAccent, width: 3.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Upper Mode Selector Switch & Status Info
          Positioned(
            top: 10,
            left: 10,
            right: 70,
            child: Column(
              children: [
                SegmentedButton<AppMode>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => const Color(0xEE0F172A),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: AppMode.pointInspect,
                      label: Text('Point Inspect'),
                      icon: Icon(Icons.touch_app),
                    ),
                    ButtonSegment(
                      value: AppMode.routePlan,
                      label: Text('Draw Route'),
                      icon: Icon(Icons.timeline),
                    ),
                  ],
                  selected: {_currentMode},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _currentMode = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 6),
                Card(
                  color: const Color(0xEE0F172A),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _currentMode == AppMode.pointInspect
                              ? Icons.info_outline
                              : Icons.navigation_outlined,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentMode == AppMode.pointInspect
                                ? 'Tap anywhere to evaluate terrain metrics.'
                                : 'Tap repeatedly to draw a zig-zag transit path point-by-point.',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right-side floating controls (Zoom + Undo)
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_recenter',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.greenAccent,
                  onPressed: () =>
                      _mapController.move(jkCenter, initialZoomLevel),
                  child: const Icon(Icons.my_location),
                ),
                if (_currentMode == AppMode.routePlan &&
                    _routePoints.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  FloatingActionButton.small(
                    heroTag: 'btn_undo',
                    backgroundColor: Colors.redAccent.withAlpha(200),
                    foregroundColor: Colors.white,
                    tooltip: 'Undo Last Point',
                    onPressed: _undoLastRoutePoint,
                    child: const Icon(Icons.undo),
                  ),
                ]
              ],
            ),
          ),

          // Bottom Sheet: Single Point Inspection Mode
          if (_currentMode == AppMode.pointInspect &&
              _singleSelectedPoint != null &&
              (_isProcessing || _singlePointSpecs != null))
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: _buildSpecsCard(
                title: _singlePointSpecs?.terrainType ?? 'Analyzing...',
                isPassable: _singlePointSpecs?.isPassable ?? true,
                safetyRating: _singlePointSpecs?.safetyRating ?? '',
                specs: _singlePointSpecs,
                coord: _singleSelectedPoint!,
                isCalculating: _isProcessing,
                onClose: () {
                  setState(() {
                    _singleSelectedPoint = null;
                    _singlePointSpecs = null;
                  });
                },
              ),
            ),

          // Bottom Sheet: Route Mode Scrubber & Waypoint Inspector
          if (_currentMode == AppMode.routePlan &&
              (_isProcessing || _routeWaypoints.isNotEmpty))
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
                    color: _isRouteOverallPassable ? Colors.cyan : Colors.orange,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _isProcessing
                      ? const SizedBox(
                    height: 75,
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
                            'Reading Copernicus DEM for waypoint...',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Overall Path Summary Header
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MULTI-SEGMENT TRANSIT ASSESSMENT',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${(_totalRouteDistanceMeters / 1000.0).toStringAsFixed(2)} km  |  Max Slope: ${_maxRouteSlope.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isRouteOverallPassable
                                  ? Colors.green.withAlpha(40)
                                  : Colors.red.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isRouteOverallPassable
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            child: Text(
                              _isRouteOverallPassable
                                  ? 'ROUTE PASSABLE'
                                  : 'HAZARDOUS OBSTACLES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isRouteOverallPassable
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 14),

                      // Waypoint Scrubber Slider (Only shown if 2+ points exist)
                      if (_routeWaypoints.length > 1)
                        Row(
                          children: [
                            Text(
                              'Start (S)',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[400]),
                            ),
                            Expanded(
                              child: Slider(
                                value:
                                _selectedWaypointIndex.toDouble(),
                                min: 0,
                                max: (_routeWaypoints.length - 1)
                                    .toDouble(),
                                divisions: _routeWaypoints.length - 1,
                                activeColor: Colors.amberAccent,
                                inactiveColor: Colors.white24,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedWaypointIndex =
                                        val.round();
                                  });
                                },
                              ),
                            ),
                            Text(
                              'End (E)',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[400]),
                            ),
                          ],
                        ),

                      // Current Sampled Waypoint Metrics
                      if (activeWaypoint != null) ...[
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Waypoint ${_selectedWaypointIndex + 1}/${_routeWaypoints.length}  (+${(activeWaypoint.distanceFromStartMeters / 1000.0).toStringAsFixed(2)} km)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent),
                            ),
                            Text(
                              activeWaypoint.specs.terrainType,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                          children: [
                            _DataCell(
                              label: 'Altitude',
                              value:
                              '${activeWaypoint.specs.elevationMeters.toStringAsFixed(1)} m',
                            ),
                            _DataCell(
                              label: 'Slope',
                              value:
                              '${activeWaypoint.specs.slopeDegrees.toStringAsFixed(1)}°',
                            ),
                            _DataCell(
                              label: 'Steepness',
                              value:
                              '${activeWaypoint.specs.steepnessPercentage.toStringAsFixed(1)}%',
                            ),
                            _DataCell(
                              label: 'Aspect',
                              value:
                              '${activeWaypoint.specs.aspectDegrees.toStringAsFixed(0)}° ${activeWaypoint.specs.aspectDirection}',
                            ),
                            _DataCell(
                              label: 'Roughness',
                              value: activeWaypoint.specs.roughnessIndex
                                  .toStringAsFixed(2),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecsCard({
    required String title,
    required bool isPassable,
    required String safetyRating,
    required UGVTerrainSpecs? specs,
    required LatLng coord,
    required bool isCalculating,
    required VoidCallback onClose,
  }) {
    // Standard Card layout (same as single point inspector)
    return Card(
      color: const Color(0xFF0F172A),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: specs == null
              ? Colors.blueAccent
              : (isPassable ? Colors.green : Colors.red),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: isCalculating
            ? const SizedBox(
          height: 70,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 14),
                Text(
                  'Reading Copernicus DEM Elevation...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  title,
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
                        color: isPassable
                            ? Colors.green.withAlpha(40)
                            : Colors.red.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPassable ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        '$safetyRating (${isPassable ? "PASSABLE" : "NO-GO"})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPassable
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
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),
            if (specs != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DataCell(
                    label: 'Altitude',
                    value:
                    '${specs.elevationMeters.toStringAsFixed(1)} m',
                  ),
                  _DataCell(
                    label: 'Slope Angle',
                    value:
                    '${specs.slopeDegrees.toStringAsFixed(1)}°',
                  ),
                  _DataCell(
                    label: 'Steepness',
                    value:
                    '${specs.steepnessPercentage.toStringAsFixed(1)}%',
                  ),
                  _DataCell(
                    label: 'Aspect',
                    value:
                    '${specs.aspectDegrees.toStringAsFixed(0)}° ${specs.aspectDirection}',
                  ),
                  _DataCell(
                    label: 'Roughness',
                    value: specs.roughnessIndex.toStringAsFixed(2),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'Coordinate: ${coord.latitude.toStringAsFixed(5)}° N, ${coord.longitude.toStringAsFixed(5)}° E',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
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