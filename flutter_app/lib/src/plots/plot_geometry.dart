// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Geometrias MapCloud/EAVision, sem modificar coordenadas cadastradas.
class PlotGeometry {
  const PlotGeometry({required this.boundaries, required this.obstacles,
    required this.noSpray});
  final List<List<LatLng>> boundaries;
  final List<List<LatLng>> obstacles;
  final List<List<LatLng>> noSpray;

  bool get hasBoundary => boundaries.isNotEmpty;
  int get vertexCount => boundaries.fold(0, (n, ring) => n + ring.length);
  LatLngBounds? get bounds {
    final points = boundaries.expand((ring) => ring).toList();
    return points.isEmpty ? null : LatLngBounds.fromPoints(points);
  }

  factory PlotGeometry.fromFields(Map<String, dynamic> fields) {
    var boundary = <List<LatLng>>[];
    for (final key in ['fieldPath', 'boarderData', 'fieldBorderData']) {
      boundary = _readEavPolygons(fields[key]);
      if (boundary.isNotEmpty) break;
    }
    if (boundary.isEmpty) {
      for (final key in ['geoJson', 'geojson', 'fieldGeoJson', 'fieldJson',
        'boundary', 'polygon', 'coordinates', 'points', 'latLngs',
        'fieldBoundary']) {
        boundary = _readGeoPolygons(fields[key]);
        if (boundary.isNotEmpty) break;
      }
    }
    var obstacles = <List<LatLng>>[];
    for (final key in ['barrierPath', 'barrierData', 'barriers']) {
      obstacles = _readEavPolygons(fields[key]);
      if (obstacles.isEmpty) obstacles = _readGeoPolygons(fields[key]);
      if (obstacles.isNotEmpty) break;
    }
    var noSpray = <List<LatLng>>[];
    for (final key in ['noSprayBorder', 'noSprayZones', 'noSprayData']) {
      noSpray = _readEavPolygons(fields[key]);
      if (noSpray.isEmpty) noSpray = _readGeoPolygons(fields[key]);
      if (noSpray.isNotEmpty) break;
    }
    return PlotGeometry(boundaries: boundary, obstacles: obstacles,
      noSpray: noSpray);
  }
}

class PlotDisplay {
  static String _first(Map<String, dynamic> fields, List<String> keys) {
    for (final key in keys) {
      final value = fields[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
    }
    return '';
  }

  static String name(Map<String, dynamic> fields) {
    final result = _first(fields, ['fieldName', 'name', 'plotName', 'keyName']);
    return result.isNotEmpty ? result : 'Talhão ' + id(fields);
  }
  static String id(Map<String, dynamic> fields) =>
    _first(fields, ['fieldId', 'id', 'plotId']);

  /// A EAVision informa fieldArea em mu. O SmartFarm Web usa 1/15 ha.
  static String area(Map<String, dynamic> fields,
      {double coefficient = 1 / 15, String unit = 'ha'}) {
    final raw = _first(fields, ['fieldArea', 'area', 'acreage', 'muArea']);
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) return '—';
    return (value * coefficient).toStringAsFixed(2) + ' ' + unit;
  }

  static String requirement(Map<String, dynamic> fields) =>
    _first(fields, ['requirementName', 'requirement',
        'demandName', 'requirementId']);

  static String location(Map<String, dynamic> fields) {
    final address = _first(fields, ['address', 'location']);
    if (address.isNotEmpty) return address;
    final parts = [
      _first(fields, ['countryName', 'country']),
      _first(fields, ['provinceName', 'stateName', 'province']),
      _first(fields, ['cityName', 'city', 'countyName']),
    ].where((item) => item.isNotEmpty).toList();
    return parts.join(' · ');
  }
}

List<List<LatLng>> _readEavPolygons(dynamic source) {
  if (source is String) {
    return source.split('|').map(_readEavRing)
        .where((ring) => ring.length >= 3).toList(growable: false);
  }
  if (source is List) {
    if (source.isEmpty) return [];
    if (source.first is String) {
      return source.expand((e) => _readEavPolygons(e)).toList();
    }
  }
  return [];
}

List<LatLng> _readEavRing(String text) {
  final points = <LatLng>[];
  for (final row in text.split(';')) {
    final parts = row.trim().split(',');
    if (parts.length < 2) continue;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    final point = _point(lat, lon);
    if (point != null) points.add(point);
  }
  return _cleanRing(points);
}

LatLng? _point(double? lat, double? lon) {
  if (lat == null || lon == null || !lat.isFinite || !lon.isFinite ||
      lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return LatLng(lat, lon);
}

List<LatLng> _cleanRing(List<LatLng> points) {
  if (points.length >= 2 && points.first == points.last) {
    points = points.sublist(0, points.length - 1);
  }
  return points.length >= 3 ? points : [];
}

List<List<LatLng>> _readGeoPolygons(dynamic source) {
  if (source == null || source == '') return [];
  if (source is String) {
    try {
      return _readGeoPolygons(jsonDecode(source));
    } on FormatException {
      return _readEavPolygons(source);
    }
  }
  if (source is Map) {
    final type = source['type']?.toString();
    if (type == 'FeatureCollection') {
      return (source['features'] as List? ?? const [])
          .expand(_readGeoPolygons).toList();
    }
    if (type == 'Feature') return _readGeoPolygons(source['geometry']);
    if (type == 'GeometryCollection') {
      return (source['geometries'] as List? ?? const [])
          .expand(_readGeoPolygons).toList();
    }
    if (type == 'Polygon') return _geoPolygon(source['coordinates']);
    if (type == 'MultiPolygon') {
      return (source['coordinates'] as List? ?? const [])
          .expand(_geoPolygon).toList();
    }
    for (final key in ['points', 'boundary', 'coordinates', 'polygon']) {
      if (source.containsKey(key)) return _readGeoPolygons(source[key]);
    }
    return [];
  }
  if (source is! List || source.isEmpty) return [];
  if (_isPoint(source.first)) {
    final ring = _cleanRing(source.map(_arrayPoint)
        .whereType<LatLng>().toList());
    return ring.isEmpty ? [] : [ring];
  }
  if (source.first is List) return source.expand(_readGeoPolygons).toList();
  return [];
}

bool _isPoint(dynamic value) {
  if (value is Map) {
    return value.containsKey('lat') || value.containsKey('latitude');
  }
  return value is List && value.length >= 2 &&
      (value[0] is num || value[0] is String);
}

LatLng? _arrayPoint(dynamic source) {
  if (source is Map) {
    return _point(
      double.tryParse((source['lat'] ?? source['latitude']).toString()),
      double.tryParse((source['lng'] ?? source['longitude'] ??
          source['lon']).toString()),
    );
  }
  if (source is List && source.length >= 2) {
    // Listas simples EAV utilizam latitude, longitude.
    return _point(double.tryParse(source[0].toString()),
        double.tryParse(source[1].toString()));
  }
  return null;
}

List<List<LatLng>> _geoPolygon(dynamic value) {
  if (value is! List || value.isEmpty) return [];
  final exterior = value.first;
  if (exterior is! List) return [];
  final points = _cleanRing(exterior.map((p) {
    if (p is! List || p.length < 2) return null;
    // GeoJSON utiliza longitude, latitude.
    return _point(double.tryParse(p[1].toString()),
        double.tryParse(p[0].toString()));
  }).whereType<LatLng>().toList());
  return points.isEmpty ? [] : [points];
}
