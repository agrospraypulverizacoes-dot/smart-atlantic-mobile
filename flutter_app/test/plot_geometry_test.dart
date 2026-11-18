// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/src/plots/plot_geometry.dart';
import 'package:smartfarm_mobile/src/data/smartfarm_api.dart';

void main() {
  group('Talhões MapCloud — dados e geometria', () {
    test('converte mu EAVision em hectares igual ao web', () {
      expect(PlotDisplay.area({'fieldArea': 179.25}), '11.95 ha');
      expect(PlotDisplay.area({'fieldArea': 0}), '0.00 ha');
    });

    test('nome, ID, requisito e localidade', () {
      final f = {
        'fieldName': 'maia eucalipto',
        'fieldId': 50350684,
        'countryName': 'Brazil',
        'provinceName': 'Minas Gerais',
        'cityName': 'Cedro do Abaeté',
        'requirementName': 'Default requirement',
      };
      expect(PlotDisplay.name(f), 'maia eucalipto');
      expect(PlotDisplay.id(f), '50350684');
      expect(PlotDisplay.requirement(f), 'Default requirement');
      expect(PlotDisplay.location(f), contains('Minas Gerais'));
    });

    test('boarderData usa latitude/longitude e fecha polígono', () {
      final g = PlotGeometry.fromFields({
        'boarderData':
            '-19.100,-45.100,C;-19.100,-45.000,C;'
            '-19.200,-45.000,C;-19.100,-45.100,C',
      });
      expect(g.boundaries, hasLength(1));
      expect(g.boundaries.single, hasLength(3));
      expect(g.boundaries.single.first.latitude, closeTo(-19.1, 0.000001));
      expect(g.boundaries.single.first.longitude, closeTo(-45.1, 0.000001));
      expect(g.bounds, isNotNull);
    });

    test('obstáculos e exclusões permanecem independentes', () {
      final g = PlotGeometry.fromFields({
        'fieldPath': '-19,-45,C;-19,-44,C;-20,-44,C',
        'barrierData':
            '-19.1,-44.8,C;-19.1,-44.7,C;-19.2,-44.7,C'
            '|-19.3,-44.8,C;-19.3,-44.7,C;-19.4,-44.7,C',
        'noSprayBorder': '-19.5,-44.8,C;-19.5,-44.7,C;-19.6,-44.7,C',
      });
      expect(g.boundaries, hasLength(1));
      expect(g.obstacles, hasLength(2));
      expect(g.noSpray, hasLength(1));
    });

    test('GeoJSON respeita longitude/latitude', () {
      final g = PlotGeometry.fromFields({
        'geoJson': '{"type":"Polygon","coordinates":['
            '[[-45.10,-19.10],[-45.00,-19.10],[-45.00,-19.20]]]}',
      });
      expect(g.boundaries, hasLength(1));
      expect(g.boundaries.single.first.latitude, -19.10);
      expect(g.boundaries.single.first.longitude, -45.10);
    });

    test('rejeita coordenadas inválidas', () {
      final g = PlotGeometry.fromFields({
        'boarderData': '900,900,C;91,-45,C;45,-190,C',
      });
      expect(g.hasBoundary, isFalse);
    });

    test('resposta com 496 talhões é reconhecida integralmente', () {
      final response = {
        'status': 200,
        'data': {
          'page': {
            'records': List.generate(496,
              (i) => {'fieldId': i + 1,
                'fieldName': 'Talhão ' + (i + 1).toString()},
            ),
            'total': 496,
          },
        },
      };
      final page = parseSmartFarmPage(
        response, pageIndex: 1, pageSize: 10000);
      expect(page.records, hasLength(496));
      expect(page.hasMore, isFalse);
      expect(page.total, 496);
    });
  });
}
