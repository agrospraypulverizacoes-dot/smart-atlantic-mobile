# Atlantic SmartFarm Mobile · Flutter

Migração oficial do aplicativo mobile da Atlantic Drones para **Flutter + Dart** com destinos **Android e iOS**.

## Estado da migração

- Interface inicial: login, painel, talhões, drones, operações e conta.
- API: `https://smartfarm.atlanticdrones.com.br`, via HTTPS.
- Sessão: cookie `atlantic_smartfarm_session` mantido apenas em memória; não há armazenamento de credenciais em disco.
- Telas de talhões, drones e operações: leitura, paginação inicial até 30 registros e atualização manual.
- Dados reais somente com usuário autorizado e permissões correspondentes.

**Não implementado:** mapas 2D/3D, importação KML, edição de talhões, obstáculos, telemetria em tempo real, controle de voo, persistência segura da sessão, acesso offline e build iOS homologado.

## Ambiente

- Flutter 3.50.0 stable; Dart 3.14.0.
- Android Studio e SDK Android; macOS + Xcode necessários para compilar e distribuir no iOS.
- Plataforma Android instalada localmente em `C:\src\smartfarm_mobile\android` e iOS em `C:\src\smartfarm_mobile\ios`.

Neste momento, **a branch `flutter-migration` contém os fontes Dart e testes**. Para regenerar os diretórios nativos (sem sobrescrever o projeto já criado), num clone novo e dentro de `flutter_app`, execute:

```sh
flutter create --platforms=android,ios --org br.com.atlanticdrones --project-name smartfarm_mobile .
flutter pub get
flutter analyze
flutter test
flutter run
```

Não gere builds assinadas antes de configurar credenciais de distribuição e revisar licenças do Android SDK. Não versionar credenciais, tokens, certificados nem dados de clientes.

## Segurança

O serviço de produção SmartFarm não foi modificado. O cliente Dart utiliza apenas rotas existentes e HTTPS. A sessão não persiste após o fechamento do aplicativo nesta etapa.

## Estratégia Git

A `main` conserva o protótipo React Native/Expo anterior; `flutter-migration` é uma migração incremental, sem histórico destrutivo. Após validação em Android e revisão iOS, será possível substituir a arquitetura principal com segurança.
