// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'dem_engine.dart';
//
// void main() {
//   runApp(const UGVApp());
// }
//
// class UGVApp extends StatelessWidget {
//   const UGVApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'UGV Tactical Offline GIS',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         brightness: Brightness.dark,
//         colorSchemeSeed: const Color(0xFF0284C7),
//       ),
//       home: const TerrainMapView(),
//     );
//   }
// }
//
// enum AppMode { pointInspect, routePlan }
//
// class RouteWaypoint {
//   final LatLng coordinate;
//   final double distanceFromStartMeters;
//   final UGVTerrainSpecs specs;
//
//   RouteWaypoint({
//     required this.coordinate,
//     required this.distanceFromStartMeters,
//     required this.specs,
//   });
// }
//
// class TerrainMapView extends StatefulWidget {
//   const TerrainMapView({super.key});
//
//   @override
//   State<TerrainMapView> createState() => _TerrainMapViewState();
// }
//
// class _TerrainMapViewState extends State<TerrainMapView> {
//   static const LatLng jkCenter = LatLng(34.0836, 74.7973);
//   static const double initialZoomLevel = 8.0;
//
//   final MapController _mapController = MapController();
//
//   AppMode _currentMode = AppMode.pointInspect;
//
//   // Single Point Mode State
//   LatLng? _singleSelectedPoint;
//   UGVTerrainSpecs? _singlePointSpecs;
//
//   // Zig-Zag Route Mode State
//   List<LatLng> _routePoints = [];
//   List<RouteWaypoint> _routeWaypoints = [];
//   int _selectedWaypointIndex = 0;
//   double _totalRouteDistanceMeters = 0.0;
//   double _maxRouteSlope = 0.0;
//   bool _isRouteOverallPassable = true;
//
//   bool _isProcessing = false;
//
//   void _zoomIn() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom + 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _zoomOut() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom - 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _resetAll() {
//     setState(() {
//       _singleSelectedPoint = null;
//       _singlePointSpecs = null;
//       _routePoints.clear();
//       _routeWaypoints.clear();
//       _selectedWaypointIndex = 0;
//       _totalRouteDistanceMeters = 0.0;
//       _maxRouteSlope = 0.0;
//       _isRouteOverallPassable = true;
//       _isProcessing = false;
//     });
//     _mapController.move(jkCenter, initialZoomLevel);
//   }
//
//   void _undoLastRoutePoint() {
//     if (_routePoints.isEmpty) return;
//     setState(() {
//       _routePoints.removeLast();
//       _routeWaypoints.removeLast();
//
//       if (_routePoints.isEmpty) {
//         _resetAll();
//       } else {
//         _recalculateRouteSummary();
//         if (_selectedWaypointIndex >= _routeWaypoints.length) {
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//         }
//       }
//     });
//   }
//
//   void _recalculateRouteSummary() {
//     _totalRouteDistanceMeters = _routeWaypoints.last.distanceFromStartMeters;
//     _maxRouteSlope = 0.0;
//     _isRouteOverallPassable = true;
//
//     for (var wp in _routeWaypoints) {
//       if (wp.specs.slopeDegrees > _maxRouteSlope) {
//         _maxRouteSlope = wp.specs.slopeDegrees;
//       }
//       if (!wp.specs.isPassable) {
//         _isRouteOverallPassable = false;
//       }
//     }
//   }
//
//   void _onMapTapped(TapPosition pos, LatLng point) async {
//     if (_isProcessing) return;
//
//     if (_currentMode == AppMode.pointInspect) {
//       await _handleSinglePointTap(point);
//     } else {
//       await _handleMultiRouteTap(point);
//     }
//   }
//
//   Future<void> _handleSinglePointTap(LatLng point) async {
//     setState(() {
//       _singleSelectedPoint = point;
//       _singlePointSpecs = null;
//       _isProcessing = true;
//     });
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//       if (mounted) {
//         setState(() {
//           _singlePointSpecs = specs;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isProcessing = false;
//           _singlePointSpecs = null;
//         });
//         _showError(e.toString());
//       }
//     }
//   }
//
//   Future<void> _handleMultiRouteTap(LatLng point) async {
//     setState(() => _isProcessing = true);
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//
//       double distFromStart = 0.0;
//       if (_routePoints.isNotEmpty) {
//         const Distance distanceCalc = Distance();
//         final double segmentDist =
//         distanceCalc.as(LengthUnit.Meter, _routePoints.last, point);
//         distFromStart =
//             _routeWaypoints.last.distanceFromStartMeters + segmentDist;
//       }
//
//       if (mounted) {
//         setState(() {
//           _routePoints.add(point);
//           _routeWaypoints.add(
//             RouteWaypoint(
//               coordinate: point,
//               distanceFromStartMeters: distFromStart,
//               specs: specs,
//             ),
//           );
//
//           _recalculateRouteSummary();
//
//           // Automatically focus the slider on the newly dropped point
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isProcessing = false);
//         _showError(e.toString());
//       }
//     }
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message.replaceAll('Exception: ', '')),
//         backgroundColor: Colors.redAccent,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final activeWaypoint = (_routeWaypoints.isNotEmpty &&
//         _selectedWaypointIndex < _routeWaypoints.length)
//         ? _routeWaypoints[_selectedWaypointIndex]
//         : null;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Tactical UGV Terrain Analyzer',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             Text(
//               _currentMode == AppMode.pointInspect
//                   ? 'Mode: Spot Coordinate Inspector'
//                   : 'Mode: Zig-Zag Route Planner',
//               style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             tooltip: 'Clear & Reset',
//             icon: const Icon(Icons.refresh),
//             onPressed: _resetAll,
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: jkCenter,
//               initialZoom: initialZoomLevel,
//               minZoom: 6.0,
//               maxZoom: 14.0,
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all,
//               ),
//               cameraConstraint: CameraConstraint.containCenter(
//                 bounds: LatLngBounds(
//                   const LatLng(31.5, 72.5),
//                   const LatLng(37.5, 79.0),
//                 ),
//               ),
//               onTap: _onMapTapped,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'assets/map_tiles/{z}_{x}_{y}.png',
//                 tileProvider: AssetTileProvider(),
//                 maxNativeZoom: 9,
//                 maxZoom: 14.0,
//               ),
//
//               // Polyline rendering for the zig-zag path
//               if (_routePoints.length > 1)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routePoints,
//                       color: _isRouteOverallPassable
//                           ? Colors.cyanAccent
//                           : Colors.orangeAccent,
//                       strokeWidth: 4.0,
//                     ),
//                   ],
//                 ),
//
//               // Markers Layer
//               MarkerLayer(
//                 markers: [
//                   // Single Point Mode Marker
//                   if (_currentMode == AppMode.pointInspect &&
//                       _singleSelectedPoint != null)
//                     Marker(
//                       point: _singleSelectedPoint!,
//                       width: 40,
//                       height: 40,
//                       alignment: Alignment.topCenter,
//                       child: const Icon(
//                         Icons.location_pin,
//                         color: Colors.redAccent,
//                         size: 40,
//                       ),
//                     ),
//
//                   // Route Mode: Tapped Waypoints
//                   if (_currentMode == AppMode.routePlan)
//                     ..._routePoints.asMap().entries.map((entry) {
//                       final idx = entry.key;
//                       final pt = entry.value;
//                       final isStart = idx == 0;
//                       final isEnd = idx == _routePoints.length - 1 && idx > 0;
//
//                       return Marker(
//                         point: pt,
//                         width: 24,
//                         height: 24,
//                         alignment: Alignment.center,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: isStart
//                                 ? Colors.green
//                                 : (isEnd ? Colors.red : Colors.blueAccent),
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                           child: Center(
//                             child: Text(
//                               isStart ? 'S' : (isEnd ? 'E' : '${idx + 1}'),
//                               style: const TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white),
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//
//                   // Route Mode: Active Inspected Slider Ring (Yellow Highlight)
//                   if (_currentMode == AppMode.routePlan &&
//                       activeWaypoint != null)
//                     Marker(
//                       point: activeWaypoint.coordinate,
//                       width: 34,
//                       height: 34,
//                       alignment: Alignment.center,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                               color: Colors.amberAccent, width: 3.5),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ],
//           ),
//
//           // Upper Mode Selector Switch & Status Info
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 70,
//             child: Column(
//               children: [
//                 SegmentedButton<AppMode>(
//                   style: ButtonStyle(
//                     backgroundColor: WidgetStateProperty.resolveWith<Color>(
//                           (states) => const Color(0xEE0F172A),
//                     ),
//                   ),
//                   segments: const [
//                     ButtonSegment(
//                       value: AppMode.pointInspect,
//                       label: Text('Point Inspect'),
//                       icon: Icon(Icons.touch_app),
//                     ),
//                     ButtonSegment(
//                       value: AppMode.routePlan,
//                       label: Text('Draw Route'),
//                       icon: Icon(Icons.timeline),
//                     ),
//                   ],
//                   selected: {_currentMode},
//                   onSelectionChanged: (newSelection) {
//                     setState(() {
//                       _currentMode = newSelection.first;
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 6),
//                 Card(
//                   color: const Color(0xEE0F172A),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 8),
//                     child: Row(
//                       children: [
//                         Icon(
//                           _currentMode == AppMode.pointInspect
//                               ? Icons.info_outline
//                               : Icons.navigation_outlined,
//                           color: Colors.greenAccent,
//                           size: 16,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _currentMode == AppMode.pointInspect
//                                 ? 'Tap anywhere to evaluate terrain metrics.'
//                                 : 'Tap repeatedly to draw a zig-zag transit path point-by-point.',
//                             style: const TextStyle(
//                                 fontSize: 11, color: Colors.white70),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Right-side floating controls (Zoom + Undo)
//           Positioned(
//             top: 12,
//             right: 12,
//             child: Column(
//               children: [
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_in',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomIn,
//                   child: const Icon(Icons.add),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_out',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomOut,
//                   child: const Icon(Icons.remove),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_recenter',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.greenAccent,
//                   onPressed: () =>
//                       _mapController.move(jkCenter, initialZoomLevel),
//                   child: const Icon(Icons.my_location),
//                 ),
//                 if (_currentMode == AppMode.routePlan &&
//                     _routePoints.isNotEmpty) ...[
//                   const SizedBox(height: 24),
//                   FloatingActionButton.small(
//                     heroTag: 'btn_undo',
//                     backgroundColor: Colors.redAccent.withAlpha(200),
//                     foregroundColor: Colors.white,
//                     tooltip: 'Undo Last Point',
//                     onPressed: _undoLastRoutePoint,
//                     child: const Icon(Icons.undo),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//
//           // Bottom Sheet: Single Point Inspection Mode
//           if (_currentMode == AppMode.pointInspect &&
//               _singleSelectedPoint != null &&
//               (_isProcessing || _singlePointSpecs != null))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: _buildSpecsCard(
//                 title: _singlePointSpecs?.terrainType ?? 'Analyzing...',
//                 isPassable: _singlePointSpecs?.isPassable ?? true,
//                 safetyRating: _singlePointSpecs?.safetyRating ?? '',
//                 specs: _singlePointSpecs,
//                 coord: _singleSelectedPoint!,
//                 isCalculating: _isProcessing,
//                 onClose: () {
//                   setState(() {
//                     _singleSelectedPoint = null;
//                     _singlePointSpecs = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Bottom Sheet: Route Mode Scrubber & Waypoint Inspector
//           if (_currentMode == AppMode.routePlan &&
//               (_isProcessing || _routeWaypoints.isNotEmpty))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: Card(
//                 color: const Color(0xFF0F172A),
//                 elevation: 12,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   side: BorderSide(
//                     color: _isRouteOverallPassable ? Colors.cyan : Colors.orange,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: _isProcessing
//                       ? const SizedBox(
//                     height: 75,
//                     child: Center(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                                 strokeWidth: 2),
//                           ),
//                           SizedBox(width: 14),
//                           Text(
//                             'Reading Copernicus DEM for waypoint...',
//                             style: TextStyle(
//                                 color: Colors.white70, fontSize: 13),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                       : Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Overall Path Summary Header
//                       Row(
//                         mainAxisAlignment:
//                         MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'MULTI-SEGMENT TRANSIT ASSESSMENT',
//                                 style: TextStyle(
//                                     fontSize: 11,
//                                     color: Colors.grey,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                               Text(
//                                 '${(_totalRouteDistanceMeters / 1000.0).toStringAsFixed(2)} km  |  Max Slope: ${_maxRouteSlope.toStringAsFixed(1)}°',
//                                 style: const TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 10, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: _isRouteOverallPassable
//                                   ? Colors.green.withAlpha(40)
//                                   : Colors.red.withAlpha(40),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color: _isRouteOverallPassable
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                             child: Text(
//                               _isRouteOverallPassable
//                                   ? 'ROUTE PASSABLE'
//                                   : 'HAZARDOUS OBSTACLES',
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.bold,
//                                 color: _isRouteOverallPassable
//                                     ? Colors.greenAccent
//                                     : Colors.redAccent,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const Divider(color: Colors.white24, height: 14),
//
//                       // Waypoint Scrubber Slider (Only shown if 2+ points exist)
//                       if (_routeWaypoints.length > 1)
//                         Row(
//                           children: [
//                             Text(
//                               'Start (S)',
//                               style: TextStyle(
//                                   fontSize: 10, color: Colors.grey[400]),
//                             ),
//                             Expanded(
//                               child: Slider(
//                                 value:
//                                 _selectedWaypointIndex.toDouble(),
//                                 min: 0,
//                                 max: (_routeWaypoints.length - 1)
//                                     .toDouble(),
//                                 divisions: _routeWaypoints.length - 1,
//                                 activeColor: Colors.amberAccent,
//                                 inactiveColor: Colors.white24,
//                                 onChanged: (val) {
//                                   setState(() {
//                                     _selectedWaypointIndex =
//                                         val.round();
//                                   });
//                                 },
//                               ),
//                             ),
//                             Text(
//                               'End (E)',
//                               style: TextStyle(
//                                   fontSize: 10, color: Colors.grey[400]),
//                             ),
//                           ],
//                         ),
//
//                       // Current Sampled Waypoint Metrics
//                       if (activeWaypoint != null) ...[
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               'Waypoint ${_selectedWaypointIndex + 1}/${_routeWaypoints.length}  (+${(activeWaypoint.distanceFromStartMeters / 1000.0).toStringAsFixed(2)} km)',
//                               style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.amberAccent),
//                             ),
//                             Text(
//                               activeWaypoint.specs.terrainType,
//                               style: const TextStyle(
//                                   fontSize: 11, color: Colors.white70),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 6),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceAround,
//                           children: [
//                             _DataCell(
//                               label: 'Altitude',
//                               value:
//                               '${activeWaypoint.specs.elevationMeters.toStringAsFixed(1)} m',
//                             ),
//                             _DataCell(
//                               label: 'Slope',
//                               value:
//                               '${activeWaypoint.specs.slopeDegrees.toStringAsFixed(1)}°',
//                             ),
//                             _DataCell(
//                               label: 'Steepness',
//                               value:
//                               '${activeWaypoint.specs.steepnessPercentage.toStringAsFixed(1)}%',
//                             ),
//                             _DataCell(
//                               label: 'Aspect',
//                               value:
//                               '${activeWaypoint.specs.aspectDegrees.toStringAsFixed(0)}° ${activeWaypoint.specs.aspectDirection}',
//                             ),
//                             _DataCell(
//                               label: 'Roughness',
//                               value: activeWaypoint.specs.roughnessIndex
//                                   .toStringAsFixed(2),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSpecsCard({
//     required String title,
//     required bool isPassable,
//     required String safetyRating,
//     required UGVTerrainSpecs? specs,
//     required LatLng coord,
//     required bool isCalculating,
//     required VoidCallback onClose,
//   }) {
//     // Standard Card layout (same as single point inspector)
//     return Card(
//       color: const Color(0xFF0F172A),
//       elevation: 12,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: BorderSide(
//           color: specs == null
//               ? Colors.blueAccent
//               : (isPassable ? Colors.green : Colors.red),
//           width: 1.5,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(14.0),
//         child: isCalculating
//             ? const SizedBox(
//           height: 70,
//           child: Center(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//                 SizedBox(width: 14),
//                 Text(
//                   'Reading Copernicus DEM Elevation...',
//                   style: TextStyle(color: Colors.white70, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//         )
//             : Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: isPassable
//                             ? Colors.green.withAlpha(40)
//                             : Colors.red.withAlpha(40),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: isPassable ? Colors.green : Colors.red,
//                         ),
//                       ),
//                       child: Text(
//                         '$safetyRating (${isPassable ? "PASSABLE" : "NO-GO"})',
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                           color: isPassable
//                               ? Colors.greenAccent
//                               : Colors.redAccent,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     IconButton(
//                       icon: const Icon(Icons.close,
//                           size: 18, color: Colors.grey),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                       onPressed: onClose,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const Divider(color: Colors.white24, height: 16),
//             if (specs != null)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _DataCell(
//                     label: 'Altitude',
//                     value:
//                     '${specs.elevationMeters.toStringAsFixed(1)} m',
//                   ),
//                   _DataCell(
//                     label: 'Slope Angle',
//                     value:
//                     '${specs.slopeDegrees.toStringAsFixed(1)}°',
//                   ),
//                   _DataCell(
//                     label: 'Steepness',
//                     value:
//                     '${specs.steepnessPercentage.toStringAsFixed(1)}%',
//                   ),
//                   _DataCell(
//                     label: 'Aspect',
//                     value:
//                     '${specs.aspectDegrees.toStringAsFixed(0)}° ${specs.aspectDirection}',
//                   ),
//                   _DataCell(
//                     label: 'Roughness',
//                     value: specs.roughnessIndex.toStringAsFixed(2),
//                   ),
//                 ],
//               ),
//             const SizedBox(height: 10),
//             Text(
//               'Coordinate: ${coord.latitude.toStringAsFixed(5)}° N, ${coord.longitude.toStringAsFixed(5)}° E',
//               style: const TextStyle(
//                 fontSize: 10,
//                 color: Colors.grey,
//                 fontFamily: 'monospace',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _DataCell extends StatelessWidget {
//   final String label;
//   final String value;
//
//   const _DataCell({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 10, color: Colors.grey),
//         ),
//       ],
//     );
//   }
// }




// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' hide Path;
// import 'dem_engine.dart';
//
// void main() {
//   runApp(const UGVApp());
// }
//
// class UGVApp extends StatelessWidget {
//   const UGVApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'UGV Tactical Offline GIS',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         brightness: Brightness.dark,
//         colorSchemeSeed: const Color(0xFF0284C7),
//       ),
//       home: const TerrainMapView(),
//     );
//   }
// }
//
// enum AppMode { pointInspect, routePlan }
//
// class RouteWaypoint {
//   final LatLng coordinate;
//   final double distanceFromStartMeters;
//   final UGVTerrainSpecs specs;
//
//   RouteWaypoint({
//     required this.coordinate,
//     required this.distanceFromStartMeters,
//     required this.specs,
//   });
// }
//
// class TerrainMapView extends StatefulWidget {
//   const TerrainMapView({super.key});
//
//   @override
//   State<TerrainMapView> createState() => _TerrainMapViewState();
// }
//
// class _TerrainMapViewState extends State<TerrainMapView> {
//   static const LatLng jkCenter = LatLng(34.0836, 74.7973);
//   static const double initialZoomLevel = 8.0;
//
//   final MapController _mapController = MapController();
//
//   AppMode _currentMode = AppMode.pointInspect;
//
//   // Single Point Mode State
//   LatLng? _singleSelectedPoint;
//   UGVTerrainSpecs? _singlePointSpecs;
//
//   // Zig-Zag Route Mode State
//   List<LatLng> _routePoints = [];
//   List<RouteWaypoint> _routeWaypoints = [];
//   int _selectedWaypointIndex = 0;
//   double _totalRouteDistanceMeters = 0.0;
//   double _maxRouteSlope = 0.0;
//   bool _isRouteOverallPassable = true;
//
//   bool _isProcessing = false;
//
//   void _zoomIn() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom + 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _zoomOut() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom - 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _resetAll() {
//     setState(() {
//       _singleSelectedPoint = null;
//       _singlePointSpecs = null;
//       _routePoints.clear();
//       _routeWaypoints.clear();
//       _selectedWaypointIndex = 0;
//       _totalRouteDistanceMeters = 0.0;
//       _maxRouteSlope = 0.0;
//       _isRouteOverallPassable = true;
//       _isProcessing = false;
//     });
//     _mapController.move(jkCenter, initialZoomLevel);
//   }
//
//   void _undoLastRoutePoint() {
//     if (_routePoints.isEmpty) return;
//     setState(() {
//       _routePoints.removeLast();
//       _routeWaypoints.removeLast();
//
//       if (_routePoints.isEmpty) {
//         _resetAll();
//       } else {
//         _recalculateRouteSummary();
//         if (_selectedWaypointIndex >= _routeWaypoints.length) {
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//         }
//       }
//     });
//   }
//
//   void _recalculateRouteSummary() {
//     _totalRouteDistanceMeters = _routeWaypoints.last.distanceFromStartMeters;
//     _maxRouteSlope = 0.0;
//     _isRouteOverallPassable = true;
//
//     for (var wp in _routeWaypoints) {
//       if (wp.specs.slopeDegrees > _maxRouteSlope) {
//         _maxRouteSlope = wp.specs.slopeDegrees;
//       }
//       if (!wp.specs.isPassable) {
//         _isRouteOverallPassable = false;
//       }
//     }
//   }
//
//   void _onMapTapped(TapPosition pos, LatLng point) async {
//     if (_isProcessing) return;
//
//     if (_currentMode == AppMode.pointInspect) {
//       await _handleSinglePointTap(point);
//     } else {
//       await _handleMultiRouteTap(point);
//     }
//   }
//
//   Future<void> _handleSinglePointTap(LatLng point) async {
//     setState(() {
//       _singleSelectedPoint = point;
//       _singlePointSpecs = null;
//       _isProcessing = true;
//     });
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//       if (mounted) {
//         setState(() {
//           _singlePointSpecs = specs;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isProcessing = false;
//           _singlePointSpecs = null;
//         });
//         _showError(e.toString());
//       }
//     }
//   }
//
//   Future<void> _handleMultiRouteTap(LatLng point) async {
//     setState(() => _isProcessing = true);
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//
//       double distFromStart = 0.0;
//       if (_routePoints.isNotEmpty) {
//         const Distance distanceCalc = Distance();
//         final double segmentDist =
//         distanceCalc.as(LengthUnit.Meter, _routePoints.last, point);
//         distFromStart =
//             _routeWaypoints.last.distanceFromStartMeters + segmentDist;
//       }
//
//       if (mounted) {
//         setState(() {
//           _routePoints.add(point);
//           _routeWaypoints.add(
//             RouteWaypoint(
//               coordinate: point,
//               distanceFromStartMeters: distFromStart,
//               specs: specs,
//             ),
//           );
//
//           _recalculateRouteSummary();
//
//           // Automatically focus the graph on the newly dropped point
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isProcessing = false);
//         _showError(e.toString());
//       }
//     }
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message.replaceAll('Exception: ', '')),
//         backgroundColor: Colors.redAccent,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final activeWaypoint = (_routeWaypoints.isNotEmpty &&
//         _selectedWaypointIndex < _routeWaypoints.length)
//         ? _routeWaypoints[_selectedWaypointIndex]
//         : null;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Tactical UGV Terrain Analyzer',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             Text(
//               _currentMode == AppMode.pointInspect
//                   ? 'Mode: Spot Coordinate Inspector'
//                   : 'Mode: Zig-Zag Route Planner',
//               style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             tooltip: 'Clear & Reset',
//             icon: const Icon(Icons.refresh),
//             onPressed: _resetAll,
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: jkCenter,
//               initialZoom: initialZoomLevel,
//               minZoom: 6.0,
//               maxZoom: 14.0,
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all,
//               ),
//               cameraConstraint: CameraConstraint.containCenter(
//                 bounds: LatLngBounds(
//                   const LatLng(31.5, 72.5),
//                   const LatLng(37.5, 79.0),
//                 ),
//               ),
//               onTap: _onMapTapped,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'assets/map_tiles/{z}_{x}_{y}.png',
//                 tileProvider: AssetTileProvider(),
//                 maxNativeZoom: 9,
//                 maxZoom: 14.0,
//               ),
//
//               // Polyline rendering for the zig-zag path
//               if (_routePoints.length > 1)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routePoints,
//                       color: _isRouteOverallPassable
//                           ? Colors.cyanAccent
//                           : Colors.orangeAccent,
//                       strokeWidth: 4.0,
//                     ),
//                   ],
//                 ),
//
//               // Markers Layer
//               MarkerLayer(
//                 markers: [
//                   // Single Point Mode Marker
//                   if (_currentMode == AppMode.pointInspect &&
//                       _singleSelectedPoint != null)
//                     Marker(
//                       point: _singleSelectedPoint!,
//                       width: 40,
//                       height: 40,
//                       alignment: Alignment.topCenter,
//                       child: const Icon(
//                         Icons.location_pin,
//                         color: Colors.redAccent,
//                         size: 40,
//                       ),
//                     ),
//
//                   // Route Mode: Tapped Waypoints
//                   if (_currentMode == AppMode.routePlan)
//                     ..._routePoints.asMap().entries.map((entry) {
//                       final idx = entry.key;
//                       final pt = entry.value;
//                       final isStart = idx == 0;
//                       final isEnd = idx == _routePoints.length - 1 && idx > 0;
//
//                       return Marker(
//                         point: pt,
//                         width: 24,
//                         height: 24,
//                         alignment: Alignment.center,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: isStart
//                                 ? Colors.green
//                                 : (isEnd ? Colors.red : Colors.blueAccent),
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                           child: Center(
//                             child: Text(
//                               isStart ? 'S' : (isEnd ? 'E' : '${idx + 1}'),
//                               style: const TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white),
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//
//                   // Route Mode: Active Inspected Point Ring (Yellow Highlight)
//                   if (_currentMode == AppMode.routePlan &&
//                       activeWaypoint != null)
//                     Marker(
//                       point: activeWaypoint.coordinate,
//                       width: 34,
//                       height: 34,
//                       alignment: Alignment.center,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                               color: Colors.amberAccent, width: 3.5),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ],
//           ),
//
//           // Upper Mode Selector Switch & Status Info
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 70,
//             child: Column(
//               children: [
//                 SegmentedButton<AppMode>(
//                   style: ButtonStyle(
//                     backgroundColor: WidgetStateProperty.resolveWith<Color>(
//                           (states) => const Color(0xEE0F172A),
//                     ),
//                   ),
//                   segments: const [
//                     ButtonSegment(
//                       value: AppMode.pointInspect,
//                       label: Text('Point Inspect'),
//                       icon: Icon(Icons.touch_app),
//                     ),
//                     ButtonSegment(
//                       value: AppMode.routePlan,
//                       label: Text('Draw Route'),
//                       icon: Icon(Icons.timeline),
//                     ),
//                   ],
//                   selected: {_currentMode},
//                   onSelectionChanged: (newSelection) {
//                     setState(() {
//                       _currentMode = newSelection.first;
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 6),
//                 Card(
//                   color: const Color(0xEE0F172A),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 8),
//                     child: Row(
//                       children: [
//                         Icon(
//                           _currentMode == AppMode.pointInspect
//                               ? Icons.info_outline
//                               : Icons.navigation_outlined,
//                           color: Colors.greenAccent,
//                           size: 16,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _currentMode == AppMode.pointInspect
//                                 ? 'Tap anywhere to evaluate terrain metrics.'
//                                 : 'Tap repeatedly to draw a zig-zag transit path point-by-point.',
//                             style: const TextStyle(
//                                 fontSize: 11, color: Colors.white70),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Right-side floating controls (Zoom + Undo)
//           Positioned(
//             top: 12,
//             right: 12,
//             child: Column(
//               children: [
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_in',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomIn,
//                   child: const Icon(Icons.add),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_out',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomOut,
//                   child: const Icon(Icons.remove),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_recenter',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.greenAccent,
//                   onPressed: () =>
//                       _mapController.move(jkCenter, initialZoomLevel),
//                   child: const Icon(Icons.my_location),
//                 ),
//                 if (_currentMode == AppMode.routePlan &&
//                     _routePoints.isNotEmpty) ...[
//                   const SizedBox(height: 24),
//                   FloatingActionButton.small(
//                     heroTag: 'btn_undo',
//                     backgroundColor: Colors.redAccent.withAlpha(200),
//                     foregroundColor: Colors.white,
//                     tooltip: 'Undo Last Point',
//                     onPressed: _undoLastRoutePoint,
//                     child: const Icon(Icons.undo),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//
//           // Bottom Sheet: Single Point Inspection Mode
//           if (_currentMode == AppMode.pointInspect &&
//               _singleSelectedPoint != null &&
//               (_isProcessing || _singlePointSpecs != null))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: _buildSpecsCard(
//                 title: _singlePointSpecs?.terrainType ?? 'Analyzing...',
//                 isPassable: _singlePointSpecs?.isPassable ?? true,
//                 safetyRating: _singlePointSpecs?.safetyRating ?? '',
//                 specs: _singlePointSpecs,
//                 coord: _singleSelectedPoint!,
//                 isCalculating: _isProcessing,
//                 onClose: () {
//                   setState(() {
//                     _singleSelectedPoint = null;
//                     _singlePointSpecs = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Bottom Sheet: Route Mode Interactive Elevation Chart & Metrics
//           if (_currentMode == AppMode.routePlan &&
//               (_isProcessing || _routeWaypoints.isNotEmpty))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: Card(
//                 color: const Color(0xFF0F172A),
//                 elevation: 12,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   side: BorderSide(
//                     color: _isRouteOverallPassable
//                         ? Colors.cyan
//                         : Colors.orange,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: _isProcessing
//                       ? const SizedBox(
//                     height: 75,
//                     child: Center(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                                 strokeWidth: 2),
//                           ),
//                           SizedBox(width: 14),
//                           Text(
//                             'Reading Copernicus DEM for waypoint...',
//                             style: TextStyle(
//                                 color: Colors.white70, fontSize: 13),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                       : Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Overall Path Summary Header
//                       Row(
//                         mainAxisAlignment:
//                         MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'MULTI-SEGMENT TRANSIT ASSESSMENT',
//                                 style: TextStyle(
//                                     fontSize: 11,
//                                     color: Colors.grey,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                               Text(
//                                 '${(_totalRouteDistanceMeters / 1000.0).toStringAsFixed(2)} km  |  Max Slope: ${_maxRouteSlope.toStringAsFixed(1)}°',
//                                 style: const TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 10, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: _isRouteOverallPassable
//                                   ? Colors.green.withAlpha(40)
//                                   : Colors.red.withAlpha(40),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color: _isRouteOverallPassable
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                             child: Text(
//                               _isRouteOverallPassable
//                                   ? 'ROUTE PASSABLE'
//                                   : 'HAZARDOUS OBSTACLES',
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.bold,
//                                 color: _isRouteOverallPassable
//                                     ? Colors.greenAccent
//                                     : Colors.redAccent,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const Divider(color: Colors.white24, height: 14),
//
//                       // Interactive Elevation Graph (Replaces Slider)
//                       if (_routeWaypoints.length > 1)
//                         Padding(
//                           padding: const EdgeInsets.symmetric(vertical: 8.0),
//                           child: Row(
//                             children: [
//                               Text(
//                                 'Start (S)',
//                                 style: TextStyle(
//                                     fontSize: 10, color: Colors.grey[400]),
//                               ),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: SizedBox(
//                                   height: 50, // Height of the chart
//                                   child: ElevationProfileChart(
//                                     waypoints: _routeWaypoints,
//                                     selectedIndex: _selectedWaypointIndex,
//                                     onChanged: (val) {
//                                       setState(() {
//                                         _selectedWaypointIndex = val;
//                                       });
//                                     },
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               Text(
//                                 'End (E)',
//                                 style: TextStyle(
//                                     fontSize: 10, color: Colors.grey[400]),
//                               ),
//                             ],
//                           ),
//                         ),
//
//                       // Current Sampled Waypoint Metrics
//                       if (activeWaypoint != null) ...[
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               'Waypoint ${_selectedWaypointIndex + 1}/${_routeWaypoints.length}  (+${(activeWaypoint.distanceFromStartMeters / 1000.0).toStringAsFixed(2)} km)',
//                               style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.amberAccent),
//                             ),
//                             Text(
//                               activeWaypoint.specs.terrainType,
//                               style: const TextStyle(
//                                   fontSize: 11, color: Colors.white70),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 6),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceAround,
//                           children: [
//                             _DataCell(
//                               label: 'Altitude',
//                               value:
//                               '${activeWaypoint.specs.elevationMeters.toStringAsFixed(1)} m',
//                             ),
//                             _DataCell(
//                               label: 'Slope',
//                               value:
//                               '${activeWaypoint.specs.slopeDegrees.toStringAsFixed(1)}°',
//                             ),
//                             _DataCell(
//                               label: 'Steepness',
//                               value:
//                               '${activeWaypoint.specs.steepnessPercentage.toStringAsFixed(1)}%',
//                             ),
//                             _DataCell(
//                               label: 'Aspect',
//                               value:
//                               '${activeWaypoint.specs.aspectDegrees.toStringAsFixed(0)}° ${activeWaypoint.specs.aspectDirection}',
//                             ),
//                             _DataCell(
//                               label: 'Roughness',
//                               value: activeWaypoint.specs.roughnessIndex
//                                   .toStringAsFixed(2),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSpecsCard({
//     required String title,
//     required bool isPassable,
//     required String safetyRating,
//     required UGVTerrainSpecs? specs,
//     required LatLng coord,
//     required bool isCalculating,
//     required VoidCallback onClose,
//   }) {
//     return Card(
//       color: const Color(0xFF0F172A),
//       elevation: 12,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: BorderSide(
//           color: specs == null
//               ? Colors.blueAccent
//               : (isPassable ? Colors.green : Colors.red),
//           width: 1.5,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(14.0),
//         child: isCalculating
//             ? const SizedBox(
//           height: 70,
//           child: Center(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//                 SizedBox(width: 14),
//                 Text(
//                   'Reading Copernicus DEM Elevation...',
//                   style: TextStyle(color: Colors.white70, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//         )
//             : Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: isPassable
//                             ? Colors.green.withAlpha(40)
//                             : Colors.red.withAlpha(40),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: isPassable ? Colors.green : Colors.red,
//                         ),
//                       ),
//                       child: Text(
//                         '$safetyRating (${isPassable ? "PASSABLE" : "NO-GO"})',
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                           color: isPassable
//                               ? Colors.greenAccent
//                               : Colors.redAccent,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     IconButton(
//                       icon: const Icon(Icons.close,
//                           size: 18, color: Colors.grey),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                       onPressed: onClose,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const Divider(color: Colors.white24, height: 16),
//             if (specs != null)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _DataCell(
//                     label: 'Altitude',
//                     value:
//                     '${specs.elevationMeters.toStringAsFixed(1)} m',
//                   ),
//                   _DataCell(
//                     label: 'Slope Angle',
//                     value:
//                     '${specs.slopeDegrees.toStringAsFixed(1)}°',
//                   ),
//                   _DataCell(
//                     label: 'Steepness',
//                     value:
//                     '${specs.steepnessPercentage.toStringAsFixed(1)}%',
//                   ),
//                   _DataCell(
//                     label: 'Aspect',
//                     value:
//                     '${specs.aspectDegrees.toStringAsFixed(0)}° ${specs.aspectDirection}',
//                   ),
//                   _DataCell(
//                     label: 'Roughness',
//                     value: specs.roughnessIndex.toStringAsFixed(2),
//                   ),
//                 ],
//               ),
//             const SizedBox(height: 10),
//             Text(
//               'Coordinate: ${coord.latitude.toStringAsFixed(5)}° N, ${coord.longitude.toStringAsFixed(5)}° E',
//               style: const TextStyle(
//                 fontSize: 10,
//                 color: Colors.grey,
//                 fontFamily: 'monospace',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _DataCell extends StatelessWidget {
//   final String label;
//   final String value;
//
//   const _DataCell({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 10, color: Colors.grey),
//         ),
//       ],
//     );
//   }
// }
//
// // -------------------------------------------------------------
// // Interactive Elevation Profile Chart Widget
// // -------------------------------------------------------------
// class ElevationProfileChart extends StatelessWidget {
//   final List<RouteWaypoint> waypoints;
//   final int selectedIndex;
//   final ValueChanged<int> onChanged;
//
//   const ElevationProfileChart({
//     super.key,
//     required this.waypoints,
//     required this.selectedIndex,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       // Handles both tapping and dragging across the graph
//       onTapDown: (details) => _handleGesture(details.localPosition, context),
//       onPanUpdate: (details) => _handleGesture(details.localPosition, context),
//       child: Container(
//         color: Colors.transparent, // Ensures the whole box captures touches
//         child: CustomPaint(
//           size: const Size(double.infinity, double.infinity),
//           painter: ElevationChartPainter(
//             waypoints: waypoints,
//             selectedIndex: selectedIndex,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _handleGesture(Offset localPosition, BuildContext context) {
//     if (waypoints.isEmpty) return;
//
//     final RenderBox renderBox = context.findRenderObject() as RenderBox;
//     final double width = renderBox.size.width;
//     final double fraction = (localPosition.dx / width).clamp(0.0, 1.0);
//
//     final double totalDist = waypoints.last.distanceFromStartMeters;
//     final double targetDist = fraction * totalDist;
//
//     // Find the waypoint that is physically closest to where the user tapped/dragged
//     int closestIdx = 0;
//     double minDiff = double.infinity;
//     for (int i = 0; i < waypoints.length; i++) {
//       final diff = (waypoints[i].distanceFromStartMeters - targetDist).abs();
//       if (diff < minDiff) {
//         minDiff = diff;
//         closestIdx = i;
//       }
//     }
//     if (closestIdx != selectedIndex) {
//       onChanged(closestIdx);
//     }
//   }
// }
//
// class ElevationChartPainter extends CustomPainter {
//   final List<RouteWaypoint> waypoints;
//   final int selectedIndex;
//
//   ElevationChartPainter({
//     required this.waypoints,
//     required this.selectedIndex,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (waypoints.isEmpty) return;
//
//     final double totalDist = waypoints.last.distanceFromStartMeters;
//
//     // Find min and max elevations to scale the Y-axis correctly
//     double minElev = waypoints.map((w) => w.specs.elevationMeters).reduce(math.min);
//     double maxElev = waypoints.map((w) => w.specs.elevationMeters).reduce(math.max);
//
//     // Add a 20% vertical padding buffer so the line doesn't touch the top/bottom edges
//     final double elevRange = maxElev - minElev == 0 ? 100 : (maxElev - minElev);
//     minElev -= elevRange * 0.2;
//     maxElev += elevRange * 0.2;
//     final double adjustedRange = maxElev - minElev;
//
//     final Path fillPath = Path();
//     final Path linePath = Path();
//     final List<Offset> points = [];
//
//     // Map each waypoint into an X, Y pixel coordinate on the canvas
//     for (int i = 0; i < waypoints.length; i++) {
//       final wp = waypoints[i];
//       final double x = totalDist == 0
//           ? 0
//           : (wp.distanceFromStartMeters / totalDist) * size.width;
//
//       // Y is inverted (0 is top of canvas)
//       final double y = size.height - ((wp.specs.elevationMeters - minElev) / adjustedRange) * size.height;
//       points.add(Offset(x, y));
//
//       if (i == 0) {
//         fillPath.moveTo(x, size.height);
//         fillPath.lineTo(x, y);
//         linePath.moveTo(x, y);
//       } else {
//         fillPath.lineTo(x, y);
//         linePath.lineTo(x, y);
//       }
//     }
//
//     fillPath.lineTo(points.last.dx, size.height);
//     fillPath.close();
//
//     // 1. Draw the gradient fill under the line
//     final Paint fillPaint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//         colors: [
//           Colors.amberAccent.withAlpha(120),
//           Colors.amberAccent.withAlpha(10),
//         ],
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
//       ..style = PaintingStyle.fill;
//     canvas.drawPath(fillPath, fillPaint);
//
//     // 2. Draw the solid elevation profile line
//     final Paint linePaint = Paint()
//       ..color = Colors.amberAccent
//       ..strokeWidth = 2.0
//       ..strokeJoin = StrokeJoin.round
//       ..style = PaintingStyle.stroke;
//     canvas.drawPath(linePath, linePaint);
//
//     // 3. Draw the interactive scrubber indicator at the selected point
//     if (selectedIndex >= 0 && selectedIndex < points.length) {
//       final Offset selPoint = points[selectedIndex];
//
//       // Vertical marker line
//       final Paint indicatorLinePaint = Paint()
//         ..color = Colors.white54
//         ..strokeWidth = 1.5
//         ..style = PaintingStyle.stroke;
//       canvas.drawLine(Offset(selPoint.dx, 0), Offset(selPoint.dx, size.height), indicatorLinePaint);
//
//       // Inner glowing dot
//       final Paint dotPaint = Paint()
//         ..color = Colors.amberAccent
//         ..style = PaintingStyle.fill;
//       canvas.drawCircle(selPoint, 4.0, dotPaint);
//
//       // Outer white ring
//       final Paint dotBorderPaint = Paint()
//         ..color = Colors.white
//         ..strokeWidth = 2.0
//         ..style = PaintingStyle.stroke;
//       canvas.drawCircle(selPoint, 4.0, dotBorderPaint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant ElevationChartPainter oldDelegate) {
//     return oldDelegate.selectedIndex != selectedIndex || oldDelegate.waypoints != waypoints;
//   }
// }



// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart' hide Path;
// import 'dem_engine.dart';
//
// void main() {
//   runApp(const UGVApp());
// }
//
// class UGVApp extends StatelessWidget {
//   const UGVApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'UGV Tactical Offline GIS',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         brightness: Brightness.dark,
//         colorSchemeSeed: const Color(0xFF0284C7),
//       ),
//       home: const TerrainMapView(),
//     );
//   }
// }
//
// enum AppMode { pointInspect, routePlan }
//
// class RouteWaypoint {
//   final LatLng coordinate;
//   final double distanceFromStartMeters;
//   final UGVTerrainSpecs specs;
//
//   RouteWaypoint({
//     required this.coordinate,
//     required this.distanceFromStartMeters,
//     required this.specs,
//   });
// }
//
// class TerrainMapView extends StatefulWidget {
//   const TerrainMapView({super.key});
//
//   @override
//   State<TerrainMapView> createState() => _TerrainMapViewState();
// }
//
// class _TerrainMapViewState extends State<TerrainMapView> {
//   static const LatLng jkCenter = LatLng(34.0836, 74.7973);
//   static const double initialZoomLevel = 8.0;
//
//   final MapController _mapController = MapController();
//
//   AppMode _currentMode = AppMode.pointInspect;
//
//   // Single Point Mode State
//   LatLng? _singleSelectedPoint;
//   UGVTerrainSpecs? _singlePointSpecs;
//
//   // Zig-Zag Route Mode State
//   List<LatLng> _routePoints = [];
//   List<RouteWaypoint> _routeWaypoints = [];
//   int _selectedWaypointIndex = 0;
//   double _totalRouteDistanceMeters = 0.0;
//   double _maxRouteSlope = 0.0;
//   bool _isRouteOverallPassable = true;
//
//   bool _isProcessing = false;
//
//   void _zoomIn() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom + 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _zoomOut() {
//     final currentZoom = _mapController.camera.zoom;
//     final targetZoom = (currentZoom - 1.0).clamp(6.0, 14.0);
//     _mapController.move(_mapController.camera.center, targetZoom);
//   }
//
//   void _resetAll() {
//     setState(() {
//       _singleSelectedPoint = null;
//       _singlePointSpecs = null;
//       _routePoints.clear();
//       _routeWaypoints.clear();
//       _selectedWaypointIndex = 0;
//       _totalRouteDistanceMeters = 0.0;
//       _maxRouteSlope = 0.0;
//       _isRouteOverallPassable = true;
//       _isProcessing = false;
//     });
//     _mapController.move(jkCenter, initialZoomLevel);
//   }
//
//   void _undoLastRoutePoint() {
//     if (_routePoints.isEmpty) return;
//     setState(() {
//       _routePoints.removeLast();
//       _routeWaypoints.removeLast();
//
//       if (_routePoints.isEmpty) {
//         _resetAll();
//       } else {
//         _recalculateRouteSummary();
//         if (_selectedWaypointIndex >= _routeWaypoints.length) {
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//         }
//       }
//     });
//   }
//
//   void _recalculateRouteSummary() {
//     _totalRouteDistanceMeters = _routeWaypoints.last.distanceFromStartMeters;
//     _maxRouteSlope = 0.0;
//     _isRouteOverallPassable = true;
//
//     for (var wp in _routeWaypoints) {
//       if (wp.specs.slopeDegrees > _maxRouteSlope) {
//         _maxRouteSlope = wp.specs.slopeDegrees;
//       }
//       if (!wp.specs.isPassable) {
//         _isRouteOverallPassable = false;
//       }
//     }
//   }
//
//   void _onMapTapped(TapPosition pos, LatLng point) async {
//     if (_isProcessing) return;
//
//     if (_currentMode == AppMode.pointInspect) {
//       await _handleSinglePointTap(point);
//     } else {
//       await _handleMultiRouteTap(point);
//     }
//   }
//
//   Future<void> _handleSinglePointTap(LatLng point) async {
//     setState(() {
//       _singleSelectedPoint = point;
//       _singlePointSpecs = null;
//       _isProcessing = true;
//     });
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//       if (mounted) {
//         setState(() {
//           _singlePointSpecs = specs;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isProcessing = false;
//           _singlePointSpecs = null;
//         });
//         _showError(e.toString());
//       }
//     }
//   }
//
//   Future<void> _handleMultiRouteTap(LatLng point) async {
//     setState(() => _isProcessing = true);
//
//     try {
//       final zoom = _mapController.camera.zoom.round();
//       final specs = await DEMEngine.analyzeTerrainAtCoordinate(point, zoom);
//
//       double distFromStart = 0.0;
//       if (_routePoints.isNotEmpty) {
//         const Distance distanceCalc = Distance();
//         final double segmentDist =
//         distanceCalc.as(LengthUnit.Meter, _routePoints.last, point);
//         distFromStart =
//             _routeWaypoints.last.distanceFromStartMeters + segmentDist;
//       }
//
//       if (mounted) {
//         setState(() {
//           _routePoints.add(point);
//           _routeWaypoints.add(
//             RouteWaypoint(
//               coordinate: point,
//               distanceFromStartMeters: distFromStart,
//               specs: specs,
//             ),
//           );
//
//           _recalculateRouteSummary();
//           _selectedWaypointIndex = _routeWaypoints.length - 1;
//           _isProcessing = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isProcessing = false);
//         _showError(e.toString());
//       }
//     }
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message.replaceAll('Exception: ', '')),
//         backgroundColor: Colors.redAccent,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final activeWaypoint = (_routeWaypoints.isNotEmpty &&
//         _selectedWaypointIndex < _routeWaypoints.length)
//         ? _routeWaypoints[_selectedWaypointIndex]
//         : null;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Tactical UGV Terrain Analyzer',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             Text(
//               _currentMode == AppMode.pointInspect
//                   ? 'Mode: Spot Coordinate Inspector'
//                   : 'Mode: Zig-Zag Route Planner',
//               style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             tooltip: 'Clear & Reset',
//             icon: const Icon(Icons.refresh),
//             onPressed: _resetAll,
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: jkCenter,
//               initialZoom: initialZoomLevel,
//               minZoom: 6.0,
//               maxZoom: 14.0,
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all,
//               ),
//               cameraConstraint: CameraConstraint.containCenter(
//                 bounds: LatLngBounds(
//                   const LatLng(31.5, 72.5),
//                   const LatLng(37.5, 79.0),
//                 ),
//               ),
//               onTap: _onMapTapped,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'assets/map_tiles/{z}_{x}_{y}.png',
//                 tileProvider: AssetTileProvider(),
//                 maxNativeZoom: 9,
//                 maxZoom: 14.0,
//               ),
//
//               if (_routePoints.length > 1)
//                 PolylineLayer(
//                   polylines: [
//                     Polyline(
//                       points: _routePoints,
//                       color: _isRouteOverallPassable
//                           ? Colors.cyanAccent
//                           : Colors.orangeAccent,
//                       strokeWidth: 4.0,
//                     ),
//                   ],
//                 ),
//
//               MarkerLayer(
//                 markers: [
//                   if (_currentMode == AppMode.pointInspect &&
//                       _singleSelectedPoint != null)
//                     Marker(
//                       point: _singleSelectedPoint!,
//                       width: 40,
//                       height: 40,
//                       alignment: Alignment.topCenter,
//                       child: const Icon(
//                         Icons.location_pin,
//                         color: Colors.redAccent,
//                         size: 40,
//                       ),
//                     ),
//
//                   if (_currentMode == AppMode.routePlan)
//                     ..._routePoints.asMap().entries.map((entry) {
//                       final idx = entry.key;
//                       final pt = entry.value;
//                       final isStart = idx == 0;
//                       final isEnd = idx == _routePoints.length - 1 && idx > 0;
//
//                       return Marker(
//                         point: pt,
//                         width: 24,
//                         height: 24,
//                         alignment: Alignment.center,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: isStart
//                                 ? Colors.green
//                                 : (isEnd ? Colors.red : Colors.blueAccent),
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                           child: Center(
//                             child: Text(
//                               isStart ? 'S' : (isEnd ? 'E' : '${idx + 1}'),
//                               style: const TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white),
//                             ),
//                           ),
//                         ),
//                       );
//                     }),
//
//                   if (_currentMode == AppMode.routePlan &&
//                       activeWaypoint != null)
//                     Marker(
//                       point: activeWaypoint.coordinate,
//                       width: 34,
//                       height: 34,
//                       alignment: Alignment.center,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                               color: Colors.amberAccent, width: 3.5),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ],
//           ),
//
//           // Upper Selector Controls
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 70,
//             child: Column(
//               children: [
//                 SegmentedButton<AppMode>(
//                   style: ButtonStyle(
//                     backgroundColor: WidgetStateProperty.resolveWith<Color>(
//                           (states) => const Color(0xEE0F172A),
//                     ),
//                   ),
//                   segments: const [
//                     ButtonSegment(
//                       value: AppMode.pointInspect,
//                       label: Text('Point Inspect'),
//                       icon: Icon(Icons.touch_app),
//                     ),
//                     ButtonSegment(
//                       value: AppMode.routePlan,
//                       label: Text('Draw Route'),
//                       icon: Icon(Icons.timeline),
//                     ),
//                   ],
//                   selected: {_currentMode},
//                   onSelectionChanged: (newSelection) {
//                     setState(() {
//                       _currentMode = newSelection.first;
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 6),
//                 Card(
//                   color: const Color(0xEE0F172A),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 8),
//                     child: Row(
//                       children: [
//                         Icon(
//                           _currentMode == AppMode.pointInspect
//                               ? Icons.info_outline
//                               : Icons.navigation_outlined,
//                           color: Colors.greenAccent,
//                           size: 16,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             _currentMode == AppMode.pointInspect
//                                 ? 'Tap anywhere to evaluate terrain metrics.'
//                                 : 'Tap to mark route points. Milestones appear below on the terrain elevation curve.',
//                             style: const TextStyle(
//                                 fontSize: 11, color: Colors.white70),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Zoom & Recenter Controls
//           Positioned(
//             top: 12,
//             right: 12,
//             child: Column(
//               children: [
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_in',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomIn,
//                   child: const Icon(Icons.add),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_zoom_out',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.white,
//                   onPressed: _zoomOut,
//                   child: const Icon(Icons.remove),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton.small(
//                   heroTag: 'btn_recenter',
//                   backgroundColor: const Color(0xFF0F172A),
//                   foregroundColor: Colors.greenAccent,
//                   onPressed: () =>
//                       _mapController.move(jkCenter, initialZoomLevel),
//                   child: const Icon(Icons.my_location),
//                 ),
//                 if (_currentMode == AppMode.routePlan &&
//                     _routePoints.isNotEmpty) ...[
//                   const SizedBox(height: 24),
//                   FloatingActionButton.small(
//                     heroTag: 'btn_undo',
//                     backgroundColor: Colors.redAccent.withAlpha(200),
//                     foregroundColor: Colors.white,
//                     tooltip: 'Undo Last Point',
//                     onPressed: _undoLastRoutePoint,
//                     child: const Icon(Icons.undo),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//
//           // Point Inspection Sheet
//           if (_currentMode == AppMode.pointInspect &&
//               _singleSelectedPoint != null &&
//               (_isProcessing || _singlePointSpecs != null))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: _buildSpecsCard(
//                 title: _singlePointSpecs?.terrainType ?? 'Analyzing...',
//                 isPassable: _singlePointSpecs?.isPassable ?? true,
//                 safetyRating: _singlePointSpecs?.safetyRating ?? '',
//                 specs: _singlePointSpecs,
//                 coord: _singleSelectedPoint!,
//                 isCalculating: _isProcessing,
//                 onClose: () {
//                   setState(() {
//                     _singleSelectedPoint = null;
//                     _singlePointSpecs = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Route Analysis Card with Smooth Elevation Profile Chart
//           if (_currentMode == AppMode.routePlan &&
//               (_isProcessing || _routeWaypoints.isNotEmpty))
//             Positioned(
//               bottom: 12,
//               left: 12,
//               right: 12,
//               child: Card(
//                 color: const Color(0xFF0F172A),
//                 elevation: 12,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   side: BorderSide(
//                     color: _isRouteOverallPassable
//                         ? Colors.cyan
//                         : Colors.orange,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: _isProcessing
//                       ? const SizedBox(
//                     height: 80,
//                     child: Center(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                                 strokeWidth: 2),
//                           ),
//                           SizedBox(width: 14),
//                           Text(
//                             'Reading Copernicus DEM for waypoint...',
//                             style: TextStyle(
//                                 color: Colors.white70, fontSize: 13),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                       : Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Row(
//                         mainAxisAlignment:
//                         MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'MULTI-SEGMENT TRANSIT ASSESSMENT',
//                                 style: TextStyle(
//                                     fontSize: 11,
//                                     color: Colors.grey,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                               Text(
//                                 '${(_totalRouteDistanceMeters / 1000.0).toStringAsFixed(2)} km  |  Max Slope: ${_maxRouteSlope.toStringAsFixed(1)}°',
//                                 style: const TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 10, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: _isRouteOverallPassable
//                                   ? Colors.green.withAlpha(40)
//                                   : Colors.red.withAlpha(40),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color: _isRouteOverallPassable
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                             child: Text(
//                               _isRouteOverallPassable
//                                   ? 'ROUTE PASSABLE'
//                                   : 'HAZARDOUS OBSTACLES',
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.bold,
//                                 color: _isRouteOverallPassable
//                                     ? Colors.greenAccent
//                                     : Colors.redAccent,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const Divider(color: Colors.white24, height: 12),
//
//                       // Smooth Interactive Elevation Profile Chart
//                       if (_routeWaypoints.length > 1)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
//                           child: SizedBox(
//                             height: 68,
//                             child: ElevationProfileChart(
//                               waypoints: _routeWaypoints,
//                               selectedIndex: _selectedWaypointIndex,
//                               onChanged: (val) {
//                                 setState(() {
//                                   _selectedWaypointIndex = val;
//                                 });
//                               },
//                             ),
//                           ),
//                         ),
//
//                       // Selected Waypoint Metrics Card
//                       if (activeWaypoint != null) ...[
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               'Waypoint ${_selectedWaypointIndex + 1}/${_routeWaypoints.length}  (+${(activeWaypoint.distanceFromStartMeters / 1000.0).toStringAsFixed(2)} km)',
//                               style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.amberAccent),
//                             ),
//                             Text(
//                               activeWaypoint.specs.terrainType,
//                               style: const TextStyle(
//                                   fontSize: 11, color: Colors.white70),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 6),
//                         Row(
//                           mainAxisAlignment:
//                           MainAxisAlignment.spaceAround,
//                           children: [
//                             _DataCell(
//                               label: 'Altitude',
//                               value:
//                               '${activeWaypoint.specs.elevationMeters.toStringAsFixed(1)} m',
//                             ),
//                             _DataCell(
//                               label: 'Slope',
//                               value:
//                               '${activeWaypoint.specs.slopeDegrees.toStringAsFixed(1)}°',
//                             ),
//                             _DataCell(
//                               label: 'Steepness',
//                               value:
//                               '${activeWaypoint.specs.steepnessPercentage.toStringAsFixed(1)}%',
//                             ),
//                             _DataCell(
//                               label: 'Aspect',
//                               value:
//                               '${activeWaypoint.specs.aspectDegrees.toStringAsFixed(0)}° ${activeWaypoint.specs.aspectDirection}',
//                             ),
//                             _DataCell(
//                               label: 'Roughness',
//                               value: activeWaypoint.specs.roughnessIndex
//                                   .toStringAsFixed(2),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSpecsCard({
//     required String title,
//     required bool isPassable,
//     required String safetyRating,
//     required UGVTerrainSpecs? specs,
//     required LatLng coord,
//     required bool isCalculating,
//     required VoidCallback onClose,
//   }) {
//     return Card(
//       color: const Color(0xFF0F172A),
//       elevation: 12,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: BorderSide(
//           color: specs == null
//               ? Colors.blueAccent
//               : (isPassable ? Colors.green : Colors.red),
//           width: 1.5,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(14.0),
//         child: isCalculating
//             ? const SizedBox(
//           height: 70,
//           child: Center(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//                 SizedBox(width: 14),
//                 Text(
//                   'Reading Copernicus DEM Elevation...',
//                   style: TextStyle(color: Colors.white70, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//         )
//             : Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: isPassable
//                             ? Colors.green.withAlpha(40)
//                             : Colors.red.withAlpha(40),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: isPassable ? Colors.green : Colors.red,
//                         ),
//                       ),
//                       child: Text(
//                         '$safetyRating (${isPassable ? "PASSABLE" : "NO-GO"})',
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                           color: isPassable
//                               ? Colors.greenAccent
//                               : Colors.redAccent,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     IconButton(
//                       icon: const Icon(Icons.close,
//                           size: 18, color: Colors.grey),
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                       onPressed: onClose,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const Divider(color: Colors.white24, height: 16),
//             if (specs != null)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _DataCell(
//                     label: 'Altitude',
//                     value:
//                     '${specs.elevationMeters.toStringAsFixed(1)} m',
//                   ),
//                   _DataCell(
//                     label: 'Slope Angle',
//                     value:
//                     '${specs.slopeDegrees.toStringAsFixed(1)}°',
//                   ),
//                   _DataCell(
//                     label: 'Steepness',
//                     value:
//                     '${specs.steepnessPercentage.toStringAsFixed(1)}%',
//                   ),
//                   _DataCell(
//                     label: 'Aspect',
//                     value:
//                     '${specs.aspectDegrees.toStringAsFixed(0)}° ${specs.aspectDirection}',
//                   ),
//                   _DataCell(
//                     label: 'Roughness',
//                     value: specs.roughnessIndex.toStringAsFixed(2),
//                   ),
//                 ],
//               ),
//             const SizedBox(height: 10),
//             Text(
//               'Coordinate: ${coord.latitude.toStringAsFixed(5)}° N, ${coord.longitude.toStringAsFixed(5)}° E',
//               style: const TextStyle(
//                 fontSize: 10,
//                 color: Colors.grey,
//                 fontFamily: 'monospace',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _DataCell extends StatelessWidget {
//   final String label;
//   final String value;
//
//   const _DataCell({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 10, color: Colors.grey),
//         ),
//       ],
//     );
//   }
// }
//
// // -------------------------------------------------------------
// // Interactive Elevation Profile Chart Widget (Smooth Curve + Waypoint Pins)
// // -------------------------------------------------------------
// class ElevationProfileChart extends StatelessWidget {
//   final List<RouteWaypoint> waypoints;
//   final int selectedIndex;
//   final ValueChanged<int> onChanged;
//
//   const ElevationProfileChart({
//     super.key,
//     required this.waypoints,
//     required this.selectedIndex,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTapDown: (details) => _handleGesture(details.localPosition, context),
//       onPanUpdate: (details) => _handleGesture(details.localPosition, context),
//       child: Container(
//         color: Colors.transparent,
//         child: CustomPaint(
//           size: const Size(double.infinity, double.infinity),
//           painter: ElevationChartPainter(
//             waypoints: waypoints,
//             selectedIndex: selectedIndex,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _handleGesture(Offset localPosition, BuildContext context) {
//     if (waypoints.isEmpty) return;
//
//     final RenderBox renderBox = context.findRenderObject() as RenderBox;
//     final double width = renderBox.size.width;
//     final double fraction = (localPosition.dx / width).clamp(0.0, 1.0);
//
//     final double totalDist = waypoints.last.distanceFromStartMeters;
//     final double targetDist = fraction * totalDist;
//
//     int closestIdx = 0;
//     double minDiff = double.infinity;
//     for (int i = 0; i < waypoints.length; i++) {
//       final diff = (waypoints[i].distanceFromStartMeters - targetDist).abs();
//       if (diff < minDiff) {
//         minDiff = diff;
//         closestIdx = i;
//       }
//     }
//     if (closestIdx != selectedIndex) {
//       onChanged(closestIdx);
//     }
//   }
// }
//
// class ElevationChartPainter extends CustomPainter {
//   final List<RouteWaypoint> waypoints;
//   final int selectedIndex;
//
//   ElevationChartPainter({
//     required this.waypoints,
//     required this.selectedIndex,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (waypoints.isEmpty) return;
//
//     final double totalDist = waypoints.last.distanceFromStartMeters;
//
//     double actualMinElev =
//     waypoints.map((w) => w.specs.elevationMeters).reduce(math.min);
//     double actualMaxElev =
//     waypoints.map((w) => w.specs.elevationMeters).reduce(math.max);
//
//     // Vertical padding buffer so the line doesn't collide with edges or waypoint chips
//     final double rawElevDiff = actualMaxElev - actualMinElev;
//     final double elevRange = rawElevDiff == 0 ? 100 : rawElevDiff;
//     final double minElev = actualMinElev - (elevRange * 0.25);
//     final double maxElev = actualMaxElev + (elevRange * 0.25);
//     final double adjustedRange = maxElev - minElev;
//
//     final List<Offset> points = [];
//
//     for (int i = 0; i < waypoints.length; i++) {
//       final wp = waypoints[i];
//       final double x = totalDist == 0
//           ? 0.0
//           : (wp.distanceFromStartMeters / totalDist) * size.width;
//
//       final double y = size.height -
//           ((wp.specs.elevationMeters - minElev) / adjustedRange) * size.height;
//       points.add(Offset(x, y.clamp(14.0, size.height - 14.0)));
//     }
//
//     // 1. Build Smooth Continuous Path using Catmull-Rom Spline
//     final Path smoothLinePath = Path();
//     smoothLinePath.moveTo(points.first.dx, points.first.dy);
//
//     if (points.length == 2) {
//       smoothLinePath.lineTo(points.last.dx, points.last.dy);
//     } else {
//       for (int i = 0; i < points.length - 1; i++) {
//         final p0 = i > 0 ? points[i - 1] : points[i];
//         final p1 = points[i];
//         final p2 = points[i + 1];
//         final p3 = i + 2 < points.length ? points[i + 2] : p2;
//
//         final cp1 = Offset(
//           p1.dx + (p2.dx - p0.dx) / 5.5,
//           p1.dy + (p2.dy - p0.dy) / 5.5,
//         );
//         final cp2 = Offset(
//           p2.dx - (p3.dx - p1.dx) / 5.5,
//           p2.dy - (p3.dy - p1.dy) / 5.5,
//         );
//
//         smoothLinePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
//       }
//     }
//
//     // 2. Gradient Fill Under the Curve
//     final Path smoothFillPath = Path.from(smoothLinePath);
//     smoothFillPath.lineTo(points.last.dx, size.height);
//     smoothFillPath.lineTo(points.first.dx, size.height);
//     smoothFillPath.close();
//
//     final Paint fillPaint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//         colors: [
//           Colors.amberAccent.withAlpha(100),
//           Colors.amberAccent.withAlpha(12),
//         ],
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
//       ..style = PaintingStyle.fill;
//     canvas.drawPath(smoothFillPath, fillPaint);
//
//     // 3. Draw the Smooth Terrain Line
//     final Paint linePaint = Paint()
//       ..color = Colors.amberAccent
//       ..strokeWidth = 2.5
//       ..strokeJoin = StrokeJoin.round
//       ..style = PaintingStyle.stroke;
//     canvas.drawPath(smoothLinePath, linePaint);
//
//     // 4. Subtle Min / Max Elevation Labels
//     final TextPainter minElevPainter = TextPainter(
//       text: TextSpan(
//         text: '${actualMinElev.toStringAsFixed(0)} m',
//         style: const TextStyle(fontSize: 8, color: Colors.white38),
//       ),
//       textDirection: TextDirection.ltr,
//     )..layout();
//     minElevPainter.paint(
//         canvas, Offset(4, size.height - minElevPainter.height - 2));
//
//     final TextPainter maxElevPainter = TextPainter(
//       text: TextSpan(
//         text: '${actualMaxElev.toStringAsFixed(0)} m',
//         style: const TextStyle(fontSize: 8, color: Colors.white38),
//       ),
//       textDirection: TextDirection.ltr,
//     )..layout();
//     maxElevPainter.paint(canvas, const Offset(4, 2));
//
//     // 5. Draw Waypoint Pins & Guidelines across the entire route
//     for (int i = 0; i < points.length; i++) {
//       final pt = points[i];
//       final isSelected = i == selectedIndex;
//       final isStart = i == 0;
//       final isEnd = i == points.length - 1 && i > 0;
//
//       final String label = isStart ? 'S' : (isEnd ? 'E' : '${i + 1}');
//
//       // Vertical Guideline
//       final Paint guidePaint = Paint()
//         ..color = isSelected ? Colors.amberAccent.withAlpha(150) : Colors.white12
//         ..strokeWidth = isSelected ? 1.5 : 1.0;
//       canvas.drawLine(
//         Offset(pt.dx, 0),
//         Offset(pt.dx, size.height),
//         guidePaint,
//       );
//
//       // Milestone Pin Background Color (matches map markers)
//       Color pinColor;
//       if (isStart) {
//         pinColor = Colors.green;
//       } else if (isEnd) {
//         pinColor = Colors.red;
//       } else {
//         pinColor = Colors.blueAccent;
//       }
//
//       // Outer Selection Ring
//       if (isSelected) {
//         final Paint selGlowPaint = Paint()
//           ..color = Colors.amberAccent
//           ..strokeWidth = 2.5
//           ..style = PaintingStyle.stroke;
//         canvas.drawCircle(pt, 12.0, selGlowPaint);
//       }
//
//       // Waypoint Node
//       final Paint pinBgPaint = Paint()
//         ..color = pinColor
//         ..style = PaintingStyle.fill;
//       canvas.drawCircle(pt, 9.0, pinBgPaint);
//
//       final Paint pinBorderPaint = Paint()
//         ..color = Colors.white
//         ..strokeWidth = 1.5
//         ..style = PaintingStyle.stroke;
//       canvas.drawCircle(pt, 9.0, pinBorderPaint);
//
//       // Centered Label Text ('S', '2', '3' ... 'E')
//       final TextPainter labelPainter = TextPainter(
//         text: TextSpan(
//           text: label,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 9,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();
//
//       labelPainter.paint(
//         canvas,
//         Offset(pt.dx - (labelPainter.width / 2),
//             pt.dy - (labelPainter.height / 2)),
//       );
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant ElevationChartPainter oldDelegate) {
//     return oldDelegate.selectedIndex != selectedIndex ||
//         oldDelegate.waypoints != waypoints;
//   }
// }


import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
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

              MarkerLayer(
                markers: [
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
                    }),

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

          // Upper Mode Switch
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
                                : 'Tap map to mark route waypoints. Slide/scroll the profile below to inspect every point.',
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

          // Right Controls
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

          // Point Inspection Sheet
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

          // Route Mode with Slideable Elevation Profile
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
                    color: _isRouteOverallPassable
                        ? Colors.cyan
                        : Colors.orange,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _isProcessing
                      ? const SizedBox(
                    height: 85,
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
                      const Divider(color: Colors.white24, height: 12),

                      // Interactive Slideable Elevation Chart View
                      if (_routeWaypoints.length > 1)
                        Padding(
                          padding:
                          const EdgeInsets.only(top: 2.0, bottom: 6.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                color: _selectedWaypointIndex > 0
                                    ? Colors.amberAccent
                                    : Colors.white24,
                                tooltip: 'Previous Waypoint',
                                onPressed: _selectedWaypointIndex > 0
                                    ? () => setState(() =>
                                _selectedWaypointIndex--)
                                    : null,
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 96,
                                  child: ElevationProfileChart(
                                    waypoints: _routeWaypoints,
                                    selectedIndex:
                                    _selectedWaypointIndex,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedWaypointIndex = val;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios,
                                    size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                color: _selectedWaypointIndex <
                                    _routeWaypoints.length - 1
                                    ? Colors.amberAccent
                                    : Colors.white24,
                                tooltip: 'Next Waypoint',
                                onPressed: _selectedWaypointIndex <
                                    _routeWaypoints.length - 1
                                    ? () => setState(() =>
                                _selectedWaypointIndex++)
                                    : null,
                              ),
                            ],
                          ),
                        ),

                      // Selected Waypoint Metrics
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
            fontSize: 14,
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

// -------------------------------------------------------------
// Interactive Elevation Profile Chart (Uniform Spacing & Auto-Center)
// -------------------------------------------------------------
class ElevationProfileChart extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const ElevationProfileChart({
    super.key,
    required this.waypoints,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  final ScrollController _scrollController = ScrollController();
  static const double waypointSpacing = 110.0;
  static const double startPadding = 36.0;

  @override
  void didUpdateWidget(covariant ElevationProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.waypoints.length != widget.waypoints.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnIndex(widget.selectedIndex);
      });
    }
  }

  void _centerOnIndex(int index) {
    if (!_scrollController.hasClients || widget.waypoints.isEmpty) return;
    if (index < 0 || index >= widget.waypoints.length) return;

    final double nodeX = startPadding + (index * waypointSpacing);
    final double viewportWidth =
        _scrollController.position.viewportDimension;
    final double targetOffset = (nodeX - (viewportWidth / 2)).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTapCanvas(double localX) {
    if (widget.waypoints.isEmpty) return;

    final int targetIndex =
    ((localX - startPadding) / waypointSpacing).round().clamp(
      0,
      widget.waypoints.length - 1,
    );

    if (targetIndex != widget.selectedIndex) {
      widget.onChanged(targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce 110px per waypoint so the graph retains its natural scale
        final double contentWidth = math.max(
          constraints.maxWidth,
          startPadding * 2 + (widget.waypoints.length - 1) * waypointSpacing,
        );

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 3.5,
            radius: const Radius.circular(3),
            thumbColor: Colors.amberAccent.withAlpha(140),
            padding: const EdgeInsets.only(bottom: 2),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _onTapCanvas(details.localPosition.dx),
                child: SizedBox(
                  width: contentWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    size: Size(contentWidth, constraints.maxHeight),
                    painter: ElevationChartPainter(
                      waypoints: widget.waypoints,
                      selectedIndex: widget.selectedIndex,
                      pointSpacing: waypointSpacing,
                      startPadding: startPadding,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ElevationChartPainter extends CustomPainter {
  final List<RouteWaypoint> waypoints;
  final int selectedIndex;
  final double pointSpacing;
  final double startPadding;

  ElevationChartPainter({
    required this.waypoints,
    required this.selectedIndex,
    required this.pointSpacing,
    required this.startPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waypoints.isEmpty) return;

    double actualMinElev =
    waypoints.map((w) => w.specs.elevationMeters).reduce(math.min);
    double actualMaxElev =
    waypoints.map((w) => w.specs.elevationMeters).reduce(math.max);

    final double rawElevDiff = actualMaxElev - actualMinElev;
    final double elevRange = rawElevDiff == 0 ? 80 : rawElevDiff;
    final double minElev = actualMinElev - (elevRange * 0.35);
    final double maxElev = actualMaxElev + (elevRange * 0.35);
    final double adjustedRange = maxElev - minElev;

    final List<Offset> points = [];

    // Calculate fixed waypoint coordinates
    for (int i = 0; i < waypoints.length; i++) {
      final double x = startPadding + (i * pointSpacing);
      final double y = size.height -
          22.0 -
          ((waypoints[i].specs.elevationMeters - minElev) / adjustedRange) *
              (size.height - 40.0);
      points.add(Offset(x, y.clamp(20.0, size.height - 22.0)));
    }

    // 1. Catmull-Rom Smooth Cubic Spline
    final Path smoothLinePath = Path();
    smoothLinePath.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      smoothLinePath.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i + 2 < points.length ? points[i + 2] : p2;

        final cp1 = Offset(
          p1.dx + (p2.dx - p0.dx) / 5.5,
          p1.dy + (p2.dy - p0.dy) / 5.5,
        );
        final cp2 = Offset(
          p2.dx - (p3.dx - p1.dx) / 5.5,
          p2.dy - (p3.dy - p1.dy) / 5.5,
        );

        smoothLinePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    // 2. Translucent Altitude Gradient Fill Under Curve
    final Path smoothFillPath = Path.from(smoothLinePath);
    smoothFillPath.lineTo(points.last.dx, size.height - 10.0);
    smoothFillPath.lineTo(points.first.dx, size.height - 10.0);
    smoothFillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.amberAccent.withAlpha(90),
          Colors.amberAccent.withAlpha(8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(smoothFillPath, fillPaint);

    // 3. Smooth Curve Stroke
    final Paint linePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(smoothLinePath, linePaint);

    // 4. Draw Waypoint Nodes, Guideline, and Metric Labels
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final wp = waypoints[i];
      final isSelected = i == selectedIndex;
      final isStart = i == 0;
      final isEnd = i == points.length - 1 && i > 0;

      final String label = isStart ? 'S' : (isEnd ? 'E' : '${i + 1}');

      // Vertical Guideline
      final Paint guidePaint = Paint()
        ..color = isSelected
            ? Colors.amberAccent.withAlpha(160)
            : Colors.white10
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawLine(
        Offset(pt.dx, 10),
        Offset(pt.dx, size.height - 12),
        guidePaint,
      );

      // Node Color Assignment
      Color pinColor;
      if (isStart) {
        pinColor = Colors.green;
      } else if (isEnd) {
        pinColor = Colors.red;
      } else {
        pinColor = Colors.blueAccent;
      }

      // Outer Selection Glow Ring
      if (isSelected) {
        final Paint selGlowPaint = Paint()
          ..color = Colors.amberAccent
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pt, 13.0, selGlowPaint);
      }

      // Waypoint Node Dot
      final Paint pinBgPaint = Paint()
        ..color = pinColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 9.5, pinBgPaint);

      final Paint pinBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pt, 9.5, pinBorderPaint);

      // Node ID ('S', '2', '3' ... 'E')
      final TextPainter idPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      idPainter.paint(
        canvas,
        Offset(pt.dx - (idPainter.width / 2),
            pt.dy - (idPainter.height / 2)),
      );

      // Top Metric: Exact Altitude (meters)
      final TextPainter elevPainter = TextPainter(
        text: TextSpan(
          text: '${wp.specs.elevationMeters.toStringAsFixed(0)} m',
          style: TextStyle(
            color: isSelected ? Colors.amberAccent : Colors.white70,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      elevPainter.paint(
        canvas,
        Offset(pt.dx - (elevPainter.width / 2), pt.dy - 22.0),
      );

      // Bottom Metric: Cumulative Distance from Start
      final TextPainter distPainter = TextPainter(
        text: TextSpan(
          text:
          '${(wp.distanceFromStartMeters / 1000.0).toStringAsFixed(1)}k',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8.5,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      distPainter.paint(
        canvas,
        Offset(pt.dx - (distPainter.width / 2), size.height - 11.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ElevationChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.waypoints != waypoints;
  }
}