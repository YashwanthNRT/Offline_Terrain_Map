import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

class UGVTerrainSpecs {
  final double elevationMeters;
  final double slopeDegrees;
  final double steepnessPercentage;
  final double aspectDegrees;
  final String aspectDirection;
  final double roughnessIndex;
  final bool isPassable;
  final String safetyRating;
  final String terrainType;

  UGVTerrainSpecs({
    required this.elevationMeters,
    required this.slopeDegrees,
    required this.steepnessPercentage,
    required this.aspectDegrees,
    required this.aspectDirection,
    required this.roughnessIndex,
    required this.isPassable,
    required this.safetyRating,
    required this.terrainType,
  });
}

class DEMEngine {
  static const double maxSafeSlopeDegrees = 20.0;
  static const double criticalSlopeDegrees = 28.0;

  /// Decodes Mapbox Terrain-RGB pixel value to elevation in meters
  static double rgbToElevation(int r, int g, int b) {
    return -10000.0 + ((r * 65536 + g * 256 + b) * 0.1);
  }

  static Point<int> latLngToTileXY(LatLng point, int zoom) {
    final latRad = point.latitude * math.pi / 180.0;
    final n = math.pow(2.0, zoom);
    final tileX = ((point.longitude + 180.0) / 360.0 * n).floor();
    final tileY = ((1.0 -
        math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) /
            math.pi) /
        2.0 *
        n)
        .floor();
    return Point(tileX, tileY);
  }

  static Point<int> latLngToPixelXY(LatLng point, int zoom) {
    final latRad = point.latitude * math.pi / 180.0;
    final n = math.pow(2.0, zoom);
    final pixelX =
        (((point.longitude + 180.0) / 360.0 * n) * 256).floor() % 256;
    final pixelY = (((1.0 -
        math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) /
            math.pi) /
        2.0 *
        n) *
        256)
        .floor() %
        256;
    return Point(pixelX, pixelY);
  }

  static Future<UGVTerrainSpecs> analyzeTerrainAtCoordinate(
      LatLng point, int mapZoom) async {
    // Broader operational envelope for J&K and border sectors
    if (point.latitude < 32.0 ||
        point.latitude > 37.0 ||
        point.longitude < 73.0 ||
        point.longitude > 78.5) {
      throw Exception('Target is outside the Jammu & Kashmir coverage bounds.');
    }

    // Match available DEM tile zoom levels (6 to 9)
    final int analysisZoom = mapZoom.clamp(6, 9);
    final tile = latLngToTileXY(point, analysisZoom);
    final pixel = latLngToPixelXY(point, analysisZoom);

    final String assetPath =
        'assets/dem_tiles/${analysisZoom}_${tile.x}_${tile.y}.png';

    ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (_) {
      throw Exception('DEM elevation tile not found for this coordinate.');
    }

    final img.Image? demImage = img.decodeImage(data.buffer.asUint8List());
    if (demImage == null) {
      throw Exception('Corrupted elevation tile image.');
    }

    double getPixelHeight(int px, int py) {
      final clampedX = px.clamp(0, demImage.width - 1);
      final clampedY = py.clamp(0, demImage.height - 1);
      final pixelData = demImage.getPixel(clampedX, clampedY);
      return rgbToElevation(
        pixelData.r.toInt(),
        pixelData.g.toInt(),
        pixelData.b.toInt(),
      );
    }

    final int px = pixel.x;
    final int py = pixel.y;

    // 3x3 elevation sampling grid
    final double z1 = getPixelHeight(px - 1, py - 1);
    final double z2 = getPixelHeight(px, py - 1);
    final double z3 = getPixelHeight(px + 1, py - 1);
    final double z4 = getPixelHeight(px - 1, py);
    final double z5 = getPixelHeight(px, py); // Center spot elevation
    final double z6 = getPixelHeight(px + 1, py);
    final double z7 = getPixelHeight(px - 1, py + 1);
    final double z8 = getPixelHeight(px, py + 1);
    final double z9 = getPixelHeight(px + 1, py + 1);

    // Approximate ground resolution in meters per pixel at this latitude
    final double metersPerPixel =
        (156543.03392 * math.cos(point.latitude * math.pi / 180.0)) /
            math.pow(2.0, analysisZoom);

    // Horn's method for surface derivatives
    final double dzdx =
        ((z3 + 2 * z6 + z9) - (z1 + 2 * z4 + z7)) / (8 * metersPerPixel);
    final double dzdy =
        ((z7 + 2 * z8 + z9) - (z1 + 2 * z2 + z3)) / (8 * metersPerPixel);

    final double slopeRad = math.atan(math.sqrt(dzdx * dzdx + dzdy * dzdy));
    final double slopeDeg = slopeRad * (180.0 / math.pi);
    final double steepnessPct = math.tan(slopeRad) * 100.0;

    double aspectDeg = math.atan2(dzdy, -dzdx) * (180.0 / math.pi);
    if (aspectDeg < 0) aspectDeg += 360.0;

    // Terrain Roughness Index (TRI)
    final double tri = ((z1 - z5).abs() +
        (z2 - z5).abs() +
        (z3 - z5).abs() +
        (z4 - z5).abs() +
        (z6 - z5).abs() +
        (z7 - z5).abs() +
        (z8 - z5).abs() +
        (z9 - z5).abs()) /
        8.0;

    final bool passable = slopeDeg <= maxSafeSlopeDegrees && tri < 4.0;
    final String safety = slopeDeg <= maxSafeSlopeDegrees
        ? 'SAFE'
        : (slopeDeg <= criticalSlopeDegrees ? 'WARNING' : 'HAZARDOUS');

    return UGVTerrainSpecs(
      elevationMeters: z5,
      slopeDegrees: slopeDeg,
      steepnessPercentage: steepnessPct,
      aspectDegrees: aspectDeg,
      aspectDirection: _getCompassHeading(aspectDeg),
      roughnessIndex: tri,
      isPassable: passable,
      safetyRating: safety,
      terrainType: _classifyTerrain(slopeDeg, tri),
    );
  }

  static String _getCompassHeading(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  static String _classifyTerrain(double slope, double tri) {
    if (slope < 5.0 && tri < 1.0) return 'Flat Basin / Highway';
    if (slope < 12.0 && tri < 2.5) return 'Gentle Undulating Ground';
    if (slope < 22.0 && tri < 5.0) return 'Rugged Hillside';
    return 'Steep Mountain / Escarpment';
  }
}

class Point<T> {
  final T x;
  final T y;
  Point(this.x, this.y);
}