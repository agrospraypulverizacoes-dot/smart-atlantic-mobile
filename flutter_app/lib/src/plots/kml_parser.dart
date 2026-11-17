import 'package:xml/xml.dart';

class KmlVertex {
  const KmlVertex(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  bool sameAs(KmlVertex other) =>
      latitude == other.latitude && longitude == other.longitude;
}

class KmlPlot {
  const KmlPlot(this.name, this.source, this.ring);
  final String name;
  final String source;
  final List<KmlVertex> ring;
}

XmlElement? _find(XmlElement node, String name) {
  for (final child in node.descendants.whereType<XmlElement>()) {
    if (child.name.local == name) return child;
  }
  return null;
}

List<KmlVertex> _ring(String text) {
  final points = <KmlVertex>[];
  for (final token in text.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final values = token.split(',');
    if (values.length < 2) {
      throw const FormatException('Coordenadas KML incompletas.');
    }
    final lon = double.tryParse(values[0]);
    final lat = double.tryParse(values[1]);
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite ||
        lat.abs() > 90 || lon.abs() > 180) {
      throw const FormatException('Coordenada WGS84 inválida.');
    }
    points.add(KmlVertex(lat, lon));
  }
  if (points.length > 1 && points.first.sameAs(points.last)) {
    points.removeLast();
  }
  if (points.map((p) => (p.latitude, p.longitude)).toSet().length < 3) {
    throw const FormatException('Talhão precisa de três vértices distintos.');
  }
  return List.unmodifiable([...points, points.first]);
}

/// Leitura local para prévia. Não envia o talhão à API nem ao drone.
List<KmlPlot> readKmlPlots(String source, String fileName) {
  if (source.length > 5 * 1024 * 1024) {
    throw const FormatException('KML maior que 5 MB.');
  }
  late final XmlDocument doc;
  try {
    doc = XmlDocument.parse(source);
  } on XmlException {
    throw const FormatException('XML inválido.');
  }
  if (doc.rootElement.name.local != 'kml') {
    throw const FormatException('O documento não é KML.');
  }
  final plots = <KmlPlot>[];
  for (final placemark in doc.descendants.whereType<XmlElement>()) {
    if (placemark.name.local != 'Placemark') continue;
    String name = 'Talhão sem nome';
    for (final child in placemark.children.whereType<XmlElement>()) {
      if (child.name.local == 'name' && child.innerText.trim().isNotEmpty) {
        name = child.innerText.trim();
        break;
      }
    }
    final polygons = placemark.descendants.whereType<XmlElement>()
        .where((p) => p.name.local == 'Polygon').toList();
    final geometries = polygons.isNotEmpty
        ? polygons
        : placemark.descendants.whereType<XmlElement>()
            .where((p) => p.name.local == 'LineString').toList();
    for (var i = 0; i < geometries.length; i++) {
      final geometry = geometries[i];
      final outer = geometry.name.local == 'Polygon'
          ? _find(geometry, 'outerBoundaryIs') : geometry;
      final coordinates = outer == null ? null : _find(outer, 'coordinates');
      if (coordinates == null) {
        throw FormatException('Talhão sem coordenadas: $name.');
      }
      plots.add(KmlPlot(
        geometries.length == 1 ? name :
            [name, (i + 1).toString()].join(' / '),
        fileName,
        _ring(coordinates.innerText),
      ));
    }
  }
  if (plots.isEmpty) {
    throw const FormatException('Nenhum talhão encontrado.');
  }
  return List.unmodifiable(plots);
}
