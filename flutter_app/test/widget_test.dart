import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/src/data/smartfarm_api.dart';
import 'package:smartfarm_mobile/src/ui/smartfarm_app.dart';
import 'package:smartfarm_mobile/src/plots/smartfarm_plot_map_page.dart';

class FakeGateway extends SmartFarmGateway {
  String? user;
  int plotRequests = 0;
  int deviceStatsRequests = 0;
  final Map<String, String> nicknames = {};
  int nicknameSaveCalls = 0;

  @override
  Future<String?> currentUser() async => user;

  @override
  Future<String> signIn(String username, String password) async {
    if (password != 'teste') {
      throw const SmartFarmApiException('Credenciais inválidas.');
    }
    return user = username;
  }

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  Future<List<SmartFarmRecord>> records(SmartFarmResource resource) async {
    if (resource == SmartFarmResource.plots) {
      plotRequests++;
      return [const SmartFarmRecord({'id': 123, 'name': 'Talhão de teste'})];
    }
    if (resource == SmartFarmResource.devices) {
      return [const SmartFarmRecord({
        'uavAlias': 'AT-DRONE-1',
        'uavNickname': 'Drone da fazenda',
      })];
    }
    return [];
  }

  @override
  Future<Map<String, String>> deviceNicknames() async => {...nicknames};

  @override
  Future<void> saveDeviceNickname(String alias, String name) async {
    nicknameSaveCalls++;
    nicknames[alias] = name;
  }

  @override
  Future<Map<String, dynamic>> moduleDetail(
    SmartFarmModule module, SmartFarmRecord record,
  ) async {
    if (module == SmartFarmModule.devices) {
      deviceStatsRequests++;
      return {
        ...record.fields,
        'workArea': 2.55,
        'flightTime': 7200,
        '_confirmed': true,
      };
    }
    return record.fields;
  }
}

void main() {
  testWidgets('talhões exibem filtro de demanda e somente favoritos', (tester) async {
    final gateway = FakeGateway()..user = 'piloto';
    await tester.pumpWidget(SmartFarmApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-plots')));
    await tester.pumpAndSettle();

    expect(find.text('Talhão de teste'), findsOneWidget);
    expect(find.byKey(const Key('plot-demand-filter')), findsOneWidget);
    expect(find.byKey(const Key('plot-favorites-filter')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('plot-favorites-filter')));
    await tester.tap(find.byKey(const Key('plot-favorites-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Talhão de teste'), findsNothing);
    await tester.tap(find.byKey(const Key('plot-favorites-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Talhão de teste'), findsOneWidget);
  });

  testWidgets('detalhes do drone e edição de apelido persistente', (tester) async {
    final gateway = FakeGateway()..user = 'piloto';
    await tester.pumpWidget(SmartFarmApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-devices')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('device-card-AT-DRONE-1')));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do Dispositivo'), findsOneWidget);
    expect(find.text('Código da aeronave'), findsOneWidget);
    expect(find.text('Código do dispositivo'), findsOneWidget);
    expect(find.text('Código do produto'), findsOneWidget);
    expect(find.byKey(const Key('device-nickname-edit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('device-nickname-edit')));
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('device-nickname-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Operação 01');
    await tester.ensureVisible(find.byKey(const Key('device-nickname-save')));
    await tester.tap(find.byKey(const Key('device-nickname-save')));
    await tester.pumpAndSettle();

    expect(gateway.nicknameSaveCalls, 1);
    expect(gateway.nicknames['AT-DRONE-1'], 'Operação 01');
    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Operação 01'), findsOneWidget);
  });

  testWidgets('mapa do talhão alterna tela cheia e detalhes', (tester) async {
    final record = SmartFarmRecord({
      'fieldId': 25,
      'fieldName': 'Talhão de teste',
    });
    await tester.pumpWidget(MaterialApp(
      home: SmartFarmPlotMapPage(
        gateway: FakeGateway(),
        record: record,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do talhão'), findsOneWidget);
    expect(find.byTooltip('Abrir mapa em tela cheia'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir mapa em tela cheia'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sair da tela cheia'), findsOneWidget);
    expect(find.text('Detalhes do talhão'), findsNothing);
    await tester.tap(find.byTooltip('Sair da tela cheia'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do talhão'), findsOneWidget);
  });

  testWidgets('cartões de drones exibem área e horas da EAVision', (tester) async {
    final gateway = FakeGateway()..user = 'piloto';
    await tester.pumpWidget(SmartFarmApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-devices')));
    await tester.pumpAndSettle();

    expect(find.text('Drone da fazenda'), findsOneWidget);
    expect(find.text('AT-DRONE-1'), findsOneWidget);
    expect(find.text('Área de Trabalho (ha)'), findsOneWidget);
    expect(find.text('Horas de Voo'), findsOneWidget);
    expect(find.text('0,17'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(gateway.deviceStatsRequests, 1);
  });

  testWidgets('login, consulta de talhoes e logout', (tester) async {
    final gateway = FakeGateway();
    await tester.pumpWidget(SmartFarmApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Gestão agrícola em suas mãos.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('username')), 'piloto');
    await tester.enterText(find.byKey(const Key('password')), 'teste');
    await tester.tap(find.byKey(const Key('submit-login')));
    await tester.pumpAndSettle();

    expect(find.text('Olá, piloto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-plots')));
    await tester.pumpAndSettle();
    expect(find.text('Talhão de teste'), findsOneWidget);
    expect(gateway.plotRequests, 1);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('username')), findsOneWidget);
  });

  testWidgets('nao permite enviar login vazio', (tester) async {
    await tester.pumpWidget(SmartFarmApp(gateway: FakeGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-login')));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu usuário'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
  });
}
