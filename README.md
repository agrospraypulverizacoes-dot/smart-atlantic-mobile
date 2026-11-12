# Atlantic SmartFarm Mobile

Aplicativo móvel da Atlantic Drones em **React Native, Expo SDK 58 e TypeScript**.

## Funcionalidades desta versão
- Login e logout por meio do backend Atlantic SmartFarm / EAVision.
- Navegação por Início, Talhões, Drones, Operações e Conta.
- Consulta às rotas de leitura do backend oficial.
- Interface escura e arquitetura para Android.

## Executar
Requisitos: Node.js, npm e Expo Go ou SDK Android compatível.

```bash
npm install
npx expo start
```

## Verificar
```bash
npx tsc --noEmit
npx expo export --platform android
```

## Organização
- `src/app/index.tsx` — telas e navegação inicial.
- `src/app/_layout.tsx` — layout Expo Router.
- `src/lib/api.ts` — API SmartFarm.

## Integração
Backend: https://smartfarm.atlanticdrones.com.br

A persistência da sessão por cookie precisa ser testada em um celular Android. Consultas aos recursos EAVision dependem das permissões do usuário autenticado. Ainda não há controle de voo nem conexão direta com drones.

## Estado
Versão `0.1.0`. TypeScript e bundle Metro Android verificados; APK e testes de login em celular pendentes.

**Observação de publicação:** o código está completo para a primeira etapa. O ícone principal usa provisoriamente o arquivo de foreground existente; o `package-lock.json` original ainda não foi incluído devido à limitação de transferência do terminal remoto. Use `npm install` nesta versão. Ambos os arquivos originais permanecem no projeto local.

Não versionar credenciais, sessões, dados reais, caches ou artefatos de build.
