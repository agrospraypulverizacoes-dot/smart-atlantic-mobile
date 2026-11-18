import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/src/data/smartfarm_api.dart';
import 'package:smartfarm_mobile/src/ui/smartfarm_app.dart';

class FakeGateway extends SmartFarmGateway {
  String? user;
  int plotRequests = 0;

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
    return [];
  }
}

void main() {
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
