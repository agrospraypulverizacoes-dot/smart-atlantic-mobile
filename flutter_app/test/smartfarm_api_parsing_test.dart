import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/src/data/smartfarm_api.dart';

void main() {
  test('converte área em mu para hectares e segundos para horas', () {
    final metrics = SmartFarmDeviceMetrics.fromDetails({
      'workArea': 2.55,
      'flightTime': 7200,
      '_confirmed': true,
    });
    expect(metrics.areaHa, '0,17');
    expect(metrics.flightHours, '2');
  });

  test('prioriza horas diretas e não fabrica métricas ausentes', () {
    final direct = SmartFarmDeviceMetrics.fromDetails({
      'workArea': 223.2,
      'flightHours': 1.25,
      'flightTime': 9999,
      '_confirmed': true,
    });
    expect(direct.areaHa, '14,88');
    expect(direct.flightHours, '1,25');
    final missing = SmartFarmDeviceMetrics.fromDetails(null);
    expect(missing.areaHa, '—');
    expect(missing.flightHours, '—');
    final empty = SmartFarmDeviceMetrics.fromDetails({'_confirmed': true});
    expect(empty.areaHa, '0,00');
    expect(empty.flightHours, '0');
  });

  test('prioriza o nome da conta EAVision sobre o e-mail de login', () {
    expect(
      smartFarmAccountDisplayName({
        'username': 'contato@atlanticdrones.com.br',
        'user': {
          'data': {'accountName': 'Atlantic Drones'},
        },
      }),
      'Atlantic Drones',
    );
    expect(
      smartFarmAccountDisplayName({
        'username': 'contato@atlanticdrones.com.br',
      }),
      'Usuário',
    );
    expect(
      smartFarmAccountDisplayName({
        'username': 'operador',
        'context': {'name': 'Atlantic Drones'},
      }),
      'Atlantic Drones',
    );
  });

  group('Contrato SmartFarm/EAVision', () {
    test('reconhece data.content e totalElements', () {
      final result = parseSmartFarmPage(
        {'status': 200, 'data': {'content': [
          {'name': 'Talhão A', 'fieldId': 10},
          {'name': 'Talhão B', 'fieldId': 11},
        ], 'totalElements': 5}},
        pageIndex: 1, pageSize: 2,
      );
      expect(result.records.length, 2);
      expect(result.records.first.title, 'Talhão A');
      expect(result.hasMore, isTrue);
      expect(result.total, 5);
    });

    test('reconhece data.page.records', () {
      final result = parseSmartFarmPage(
        {'status': '200', 'data': {'page': {
          'records': [{'mapName': 'Mapa Alfa'}], 'totalCount': 1,
        }}},
        pageIndex: 1, pageSize: 50,
      );
      expect(result.records.single.title, 'Mapa Alfa');
      expect(result.hasMore, isFalse);
    });

    test('reconhece data.data como lista', () {
      final result = parseSmartFarmPage(
        {'data': {'data': [
          {'uavAlias': 'AT-DRONE-1', 'sn': 'SN-1'},
        ]}},
        pageIndex: 1, pageSize: 50,
      );
      expect(result.records.single.title, 'AT-DRONE-1');
      expect(result.records.single.subtitle, 'sn: SN-1');
    });

    test('respeita marcador explicito de ultima pagina', () {
      final result = parseSmartFarmPage(
        {'status': 200, 'data': {
          'items': [{'name': 'Registro'}],
          'last': true,
        }},
        pageIndex: 2, pageSize: 1,
      );
      expect(result.hasMore, isFalse);
    });

    test('identifica registros individuais para recursos sem paginação', () {
      final result = parseSmartFarmPage(
        {'status': 200, 'data': {'name': 'Conta', 'id': 8}},
        pageIndex: 1, pageSize: 50, paged: false,
      );
      expect(result.records.single.title, 'Conta');
      expect(result.hasMore, isFalse);
    });

    test('não oculta erros lógicos retornados com HTTP 200', () {
      expect(
        () => parseSmartFarmPage(
          {'status': 401, 'message': 'Sessão expirada', 'data': []},
          pageIndex: 1, pageSize: 50,
        ),
        throwsA(isA<SmartFarmApiException>()),
      );
    });
  });
}
