import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
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
  test('preserva nomes existentes e numera Placemark sem nome no KML', () {
    final source = '<kml xmlns="http://www.opengis.net/kml/2.2">'
      '<Document><Folder><name>aplic_1040</name>'
      '<Placemark><Polygon><outerBoundaryIs><LinearRing>'
      '<coordinates>-46,-20 -46.1,-20 -46.1,-20.1</coordinates>'
      '</LinearRing></outerBoundaryIs></Polygon></Placemark>'
      '<Placemark><name>Talhão existente</name><Polygon><outerBoundaryIs>'
      '<LinearRing><coordinates>-47,-20 -47.1,-20 -47.1,-20.1'
      '</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>'
      '<Placemark><name>null</name><Polygon><outerBoundaryIs>'
      '<LinearRing><coordinates>-48,-20 -48.1,-20 -48.1,-20.1'
      '</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>'
      '</Folder></Document></kml>';

    final normalized = prepareKmlForUpload(source, 'aplic_1040.kml');
    final xml = XmlDocument.parse(normalized);
    final placemarks = xml.descendants.whereType<XmlElement>()
        .where((element) => element.name.local == 'Placemark').toList();
    final names = placemarks.map((placemark) => placemark.children
        .whereType<XmlElement>()
        .firstWhere((element) => element.name.local == 'name')
        .innerText).toList();
    expect(names, ['aplic_1040_1', 'Talhão existente', 'aplic_1040_3']);

    List<String> coordinates(String value) => XmlDocument.parse(value)
        .descendants.whereType<XmlElement>()
        .where((element) => element.name.local == 'coordinates')
        .map((element) => element.innerText).toList();
    expect(coordinates(normalized), coordinates(source));

    final preview = readKmlPlots(source, 'aplic_1040.kml');
    expect(preview.map((plot) => plot.name).toList(),
        ['aplic_1040_1', 'Talhão existente', 'aplic_1040_3']);
  });

  test('nome base não depende de metadados internos ausentes', () {
    expect(kmlImportBaseName(r'C:\files\aplic_1040.kml'), 'aplic_1040');
    expect(kmlImportBaseName('/data/TESTE área.kml'), 'TESTE_rea');
    expect(kmlImportBaseName('null_null.kml'), 'talhao');
    expect(() => prepareKmlForUpload('<kml/>', 'vazio.kml'),
        throwsFormatException);
  });

}
