import 'package:material_ui/material_ui.dart';
import '../data/smartfarm_api.dart';

const _background = Color(0xFF07131C);
const _card = Color(0xFF142A34);
const _accent = Color(0xFF67C23A);
const _muted = Color(0xFFA6BDC1);

class SmartFarmApp extends StatefulWidget {
  const SmartFarmApp({super.key, this.gateway});
  final SmartFarmGateway? gateway;

  @override
  State<SmartFarmApp> createState() => _SmartFarmAppState();
}

class _SmartFarmAppState extends State<SmartFarmApp> {
  late final SmartFarmGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? SmartFarmApi();
  }

  @override
  void dispose() {
    if (widget.gateway == null && _gateway is SmartFarmApi) {
      _gateway.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atlantic SmartFarm',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: _background),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFF0B1B24),
        ),
      ),
      home: _SmartFarmHome(gateway: _gateway),
    );
  }
}

class _SmartFarmHome extends StatefulWidget {
  const _SmartFarmHome({required this.gateway});
  final SmartFarmGateway gateway;

  @override
  State<_SmartFarmHome> createState() => _SmartFarmHomeState();
}

class _SmartFarmHomeState extends State<_SmartFarmHome> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _user;
  String? _error;
  int _tab = 0;
  bool _booting = true;
  bool _busy = false;
  List<SmartFarmRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    String? user;
    try {
      user = await widget.gateway.currentUser();
    } catch (_) {
      user = null;
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _booting = false;
    });
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.gateway.signIn(
        _username.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      _password.clear();
      setState(() {
        _user = user;
        _tab = 0;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _navigate(int index) {
    setState(() {
      _tab = index;
      _error = null;
      _records = const [];
    });
    if (index >= 1 && index <= 3) _loadRecords(index);
  }

  Future<void> _loadRecords(int index) async {
    final resource = SmartFarmResource.values[index - 1];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final records = await widget.gateway.records(resource);
      if (!mounted || _tab != index) return;
      setState(() => _records = records);
    } catch (error) {
      if (!mounted || _tab != index) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && _tab == index) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.gateway.signOut();
    } catch (_) {
      // A sessão local é encerrada mesmo se o servidor não responder.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _user = null;
          _tab = 0;
          _records = const [];
          _error = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    return _user == null ? _loginScreen() : _mainScreen();
  }

  Widget _logo() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.agriculture_rounded, color: _accent, size: 30),
        SizedBox(width: 10),
        Text('ATLANTIC ', style: TextStyle(fontWeight: FontWeight.w900)),
        Text('SMARTFARM',
            style: TextStyle(color: _accent, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _loginScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                _logo(),
                const SizedBox(height: 45),
                const Text(
                  'Gestão agrícola em suas mãos.',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acesse com sua conta EAVision pelo SmartFarm Atlantic.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 28),
                Card(
                  color: _card,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const Key('username'),
                            controller: _username,
                            autofocus: false,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Usuário',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Informe seu usuário'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('password'),
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Informe sua senha'
                                    : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const Key('submit-login'),
                            onPressed: _busy ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _background,
                              padding: const EdgeInsets.all(16),
                            ),
                            child: Text(_busy ? 'Entrando...' : 'Entrar no SmartFarm'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF958D)),
                  ),
                ],
                const SizedBox(height: 25),
                const Text(
                  'Atlantic Drones • Acesso autenticado',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ATLANTIC SMARTFARM',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_tab >= 1 && _tab <= 3)
            IconButton(
              key: const Key('reload'),
              tooltip: 'Atualizar',
              onPressed: _busy ? null : () => _loadRecords(_tab),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_tab) {
          0 => _dashboard(),
          4 => _profile(),
          _ => _recordsScreen(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _navigate,
        backgroundColor: _card,
        indicatorColor: _accent.withValues(alpha: 0.24),
        destinations: const [
          NavigationDestination(
            key: Key('nav-home'),
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            key: Key('nav-plots'),
            icon: Icon(Icons.map_outlined),
            label: 'Talhões',
          ),
          NavigationDestination(
            key: Key('nav-devices'),
            icon: Icon(Icons.flight_outlined),
            label: 'Drones',
          ),
          NavigationDestination(
            key: Key('nav-operations'),
            icon: Icon(Icons.list_alt_outlined),
            label: 'Operações',
          ),
          NavigationDestination(
            key: Key('nav-profile'),
            icon: Icon(Icons.person_outline),
            label: 'Conta',
          ),
        ],
      ),
    );
  }

  Widget _dashboard() {
    const labels = [
      ('Talhões', Icons.map_outlined, 'Consultar áreas agrícolas'),
      ('Drones', Icons.flight_outlined, 'Consultar equipamentos'),
      ('Operações', Icons.assignment_outlined, 'Consultar registros de voo'),
    ];
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          'Olá, ${_user ?? 'Usuário'}',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Dados operacionais integrados ao SmartFarm Atlantic.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < labels.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: _card,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                leading: Icon(labels[index].$2, color: _accent, size: 30),
                title: Text(
                  labels[index].$1,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(labels[index].$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigate(index + 1),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          'Esta versão consulta dados. Mapas, edição e comandos de voo '
          'serão implementados em etapas posteriores.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _recordsScreen() {
    final resource = SmartFarmResource.values[_tab - 1];
    if (_busy) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _loadRecords(_tab),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadRecords(_tab),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            resource.label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta aos registros disponíveis na sua conta EAVision.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'Nenhum registro retornado para esta conta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            ),
          for (final record in _records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: _card,
                child: ListTile(
                  title: Text(record.title),
                  subtitle: record.subtitle == null
                      ? null
                      : Text(record.subtitle!),
                  leading: const Icon(Icons.description_outlined, color: _accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profile() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Minha conta',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          color: _card,
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: _accent),
            title: Text(_user ?? 'Usuário'),
            subtitle: const Text('Sessão SmartFarm Atlantic'),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          key: const Key('sign-out'),
          onPressed: _busy ? null : _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
      ],
    );
  }
}
