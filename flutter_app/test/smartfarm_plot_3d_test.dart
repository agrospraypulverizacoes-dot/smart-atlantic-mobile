import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/src/plots/plot_geometry.dart';
import 'package:smartfarm_mobile/src/plots/smartfarm_plot_3d_viewer.dart';

void main() {
  const boundary = [LatLng(-19.65, -45.87), LatLng(-19.65, -45.86),
    LatLng(-19.66, -45.86)];
  final geo = PlotGeometry(
    boundaries: [boundary],
    obstacles: [const [LatLng(-19.651, -45.869), LatLng(-19.651, -45.868),
      LatLng(-19.652, -45.868)]],
    noSpray: const [],
  );

  test('GeoJSON usa longitude antes da latitude e fecha o polígono', () {
    final data = smartFarm3DGeoJson(geo);
    final features = data['features'] as List;
    expect(features.length, 2);
    final ring = (features[0]['geometry']['coordinates'] as List)[0] as List;
    expect(ring.length, 4);
    expect(ring.first, [-45.87, -19.65]);
    expect(ring.last, ring.first);
    expect(features[1]['properties']['kind'], 'obstacle');
  });

  test('3D utiliza mesmo motor, elevação e controles do Web', () {
    final html = smartFarmPlot3DHtml(geo);
    expect(html, contains('maplibre-gl@5.17.0'));
    expect(html, contains('raster-dem'));
    expect(html, contains("encoding:'terrarium'"));
    expect(html, contains("setProjection({type:'globe'})"));
    expect(html, contains("setTerrain({source:'relief',exaggeration:1})"));
    expect(html, contains("id=\"center\""));
    expect(html, contains("id=\"north\""));
    expect(html, contains("id=\"tilt\""));
    expect(html, contains('[-45.87,-19.65]'));
    expect(html, isNot(contains('__GEOJSON__')));
  });
}
