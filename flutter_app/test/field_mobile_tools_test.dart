import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/src/plots/field_mobile_tools.dart';

void main() {
  test('navegação usa coordenadas do talhão e não inventa uma entrada', () {
    final uri = FieldLocation.directionsUri(const LatLng(-19.776, -45.584));
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['travelmode'], 'driving');
    expect(uri.queryParameters['destination'], '-19.7760000,-45.5840000');
  });
}
