import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/src/plots/kml_parser.dart';

void main() {
  test('um arquivo com dois polígonos cria dois talhões', () {
    const data = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
<Placemark><name>03</name><MultiGeometry>
<Polygon><outerBoundaryIs><LinearRing><coordinates>
-45,-20 -45.1,-20 -45.1,-20.1
</coordinates></LinearRing></outerBoundaryIs></Polygon>
<Polygon><outerBoundaryIs><LinearRing><coordinates>
-46,-20 -46.1,-20 -46.1,-20.1
</coordinates></LinearRing></outerBoundaryIs></Polygon>
</MultiGeometry></Placemark></Document></kml>
''';
    final plots = readKmlPlots(data, '03.kml');
    expect(plots, hasLength(2));
    expect(plots.first.name, '03 / 1');
    expect(plots.last.source, '03.kml');
    expect(plots.first.ring.first.sameAs(plots.first.ring.last), isTrue);
  });
  test('aceita contorno LineString para prévia local', () {
    const data = '<kml><Placemark><name>Área</name>'
      '<LineString><coordinates>-45,-20 -45.1,-20 -45.1,-20.1'
      '</coordinates></LineString></Placemark></kml>';
    final plot = readKmlPlots(data, 'origem.kml').single;
    expect(plot.ring, hasLength(4));
  });
  test('rejeita arquivos sem polígono e coordenadas inválidas', () {
    expect(() => readKmlPlots('<kml/>', 'vazio.kml'), throwsFormatException);
    const data = '<kml><Placemark><LineString><coordinates>'
      '190,-20 -45,-20 -45,-21</coordinates></LineString></Placemark></kml>';
    expect(() => readKmlPlots(data, 'ruim.kml'), throwsFormatException);
  });
}
