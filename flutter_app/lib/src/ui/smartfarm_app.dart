// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../data/smartfarm_api.dart';
import '../plots/kml_import_page.dart';
import '../plots/smartfarm_plot_map_page.dart';
import '../plots/plot_geometry.dart';
import 'web_modules_page.dart';

// Atlantic Smart Farm design tokens — fonte: RAG SMARTFARM/app/static/atlantic-theme.css.
const _background = Color(0xFF071019);
const _card = Color(0xFF0E1A2A);
const _panel = Color(0xFF081422);
const _accent = Color(0xFF1E78FF);
const _positive = Color(0xFF67C23A);
const _muted = Color(0xFF9EAFC3);
const _outline = Color(0xFF263A50);
const _onAccent = Color(0xFFF4F7FB);
const _brand = 'assets/images/atlantic_smartfarm_brand.png';
const _dronePhoto = 'assets/images/atlantic_drone.webp';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _onAccent,
          elevation: 0,
          centerTitle: false,
        ),
        cardColor: _card,
        dividerColor: _outline,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _panel,
          indicatorColor: _accent.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _outline),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _accent, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          filled: true,
          fillColor: _panel,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
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
  final Map<String, Map<String, dynamic>> _deviceStats = {};
  final Map<String, String> _deviceNicknames = {};
  int _recordsPage = 0;
  bool _recordsHasMore = false;
  bool _loadingMore = false;
  int _recordsVersion = 0;
  String _plotQuery = '';

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
    _recordsVersion++;
    setState(() {
      _tab = index;
      _error = null;
      _records = const [];
      _deviceStats.clear();
      _deviceNicknames.clear();
      _recordsPage = 0;
      _recordsHasMore = false;
      _loadingMore = false;
    });
    if (index >= 1 && index <= 3) _loadRecords(index);
  }

  Future<void> _loadRecords(int index, {bool loadMore = false}) async {
    if (loadMore && (_loadingMore || !_recordsHasMore)) return;
    final version = ++_recordsVersion;
    final resource = SmartFarmResource.values[index - 1];
    final page = loadMore ? _recordsPage + 1 : 1;
    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _busy = true;
        _error = null;
        if (resource == SmartFarmResource.devices) _deviceStats.clear();
      }
    });
    try {
      final result = await widget.gateway.recordsPage(
        resource, pageIndex: page, pageSize: 50,
      );
      if (!mounted || _tab != index || version != _recordsVersion) return;
      setState(() {
        _records = loadMore
            ? [..._records, ...result.records] : result.records;
        _recordsPage = result.pageIndex;
        _recordsHasMore = result.hasMore;
      });
      if (resource == SmartFarmResource.devices) {
        unawaited(_loadDeviceStats(result.records, version, index));
        unawaited(_loadDeviceNicknames(version, index));
      }
    } catch (error) {
      if (!mounted || _tab != index || version != _recordsVersion) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && _tab == index && version == _recordsVersion) {
        setState(() {
          _busy = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// Consulta as estatísticas em lotes para não bloquear a lista de drones.
  Future<void> _loadDeviceStats(
    List<SmartFarmRecord> records, int version, int index,
  ) async {
    for (var offset = 0; offset < records.length; offset += 4) {
      if (!mounted || _tab != index || version != _recordsVersion) return;
      final batch = records.skip(offset).take(4);
      await Future.wait(batch.map((record) async {
        final alias = (record.fields['uavAlias'] ?? '').toString().trim();
        if (alias.isEmpty) return;
        try {
          final data = await widget.gateway.moduleDetail(
            SmartFarmModule.devices, record,
          );
          if (!mounted || _tab != index || version != _recordsVersion) return;
          setState(() => _deviceStats[alias] = data);
        } catch (_) {
          // A lista permanece utilizável se alguma estatística falhar.
        }
      }));
    }
  }

  Future<void> _loadDeviceNicknames(int version, int index) async {
    try {
      final names = await widget.gateway.deviceNicknames();
      if (!mounted || _tab != index || version != _recordsVersion) return;
      setState(() {
        _deviceNicknames
          ..clear()
          ..addAll(names);
      });
    } catch (_) {
      // Mantém o apelido da EAVision quando a preferência não estiver acessível.
    }
  }

  void _openDeviceDetails(SmartFarmRecord record) {
    final alias = (record.fields['uavAlias'] ?? '').toString().trim();
    if (alias.isEmpty) return;
    final nickname = _deviceNicknames.containsKey(alias)
        ? _deviceNicknames[alias]!
        : (record.fields['uavNickname'] ?? '').toString().trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeviceDetailsSheet(
        gateway: widget.gateway,
        record: record,
        nickname: nickname,
        initialDetails: _deviceStats[alias] ?? record.fields,
        onSaved: (name) {
          if (!mounted) return;
          setState(() => _deviceNicknames[alias] = name);
        },
      ),
    );
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
          _deviceStats.clear();
          _deviceNicknames.clear();
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


  Widget _logo({double width = 230}) {
    return Image.asset(
      _brand,
      width: width,
      height: 62,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticLabel: 'Atlantic Smart Farm',
    );
  }

  Widget _sectionLabel(String text, {Color color = _muted}) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.7,
      ),
    );
  }

  BoxDecoration _panelDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? _outline),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  Widget _photoBanner({
    required String title,
    required String subtitle,
    double height = 190,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_dronePhoto, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF4071019),
                    Color(0xD4071019),
                    Color(0x5C071019),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _sectionLabel('ATLANTIC DRONES  /  SMART FARM',
                      color: _positive),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: _onAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFD6E1EC),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 13,
              right: 13,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _positive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginScreen() {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: compact ? 12 : 26),
              children: [
                Center(child: SizedBox(height: compact ? 43 : 62, child: _logo(width: 270))),
                SizedBox(height: compact ? 8 : 23),
                _photoBanner(
                  title: 'Gestão agrícola em suas mãos.',
                  subtitle: 'Precisão e controle em cada operação.',
                  height: compact ? 134 : 175,
                ),
                SizedBox(height: compact ? 10 : 21),
                _sectionLabel('ACESSO À PLATAFORMA'),
                SizedBox(height: compact ? 4 : 9),
                const Text(
                  'Entre na sua conta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _onAccent,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Acesse com sua conta EAVision pelo SmartFarm Atlantic.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                SizedBox(height: compact ? 10 : 19),
                Container(
                  decoration: _panelDecoration(borderColor: _outline),
                  padding: EdgeInsets.all(compact ? 13 : 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('username'),
                          controller: _username,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person_outline, color: _muted),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Informe seu usuário'
                                  : null,
                        ),
                        SizedBox(height: compact ? 9 : 13),
                        TextFormField(
                          key: const Key('password'),
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock_outline, color: _muted),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty
                                  ? 'Informe sua senha'
                                  : null,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        SizedBox(height: compact ? 10 : 18),
                        FilledButton.icon(
                          key: const Key('submit-login'),
                          onPressed: _busy ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _onAccent,
                            minimumSize: const Size.fromHeight(51),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 19),
                          label: Text(
                            _busy ? 'Entrando...' : 'Entrar no SmartFarm',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF6F78)),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: compact ? 10 : 25),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: _positive, size: 15),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Atlantic Drones • Acesso autenticado',
                        style: TextStyle(color: _muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
        title: _logo(width: 206),
        toolbarHeight: 68,
        actions: [
          IconButton(
            key: const Key('open-web-modules'),
            tooltip: 'Módulos do SmartFarm Web',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SmartFarmWebModulesPage(gateway: widget.gateway),
              ),
            ),
            icon: const Icon(Icons.apps_rounded),
          ),
          if (_tab == 1)
            IconButton(
              key: const Key('import-kml'),
              tooltip: 'Importar KML',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KmlImportPage(),
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined),
            ),
          if (_tab >= 1 && _tab <= 3)
            IconButton(
              key: const Key('reload'),
              tooltip: 'Atualizar',
              onPressed: _busy ? null : () => _loadRecords(_tab),
              icon: const Icon(Icons.refresh),
            ),
          const SizedBox(width: 7),
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
        backgroundColor: _panel,
        indicatorColor: _accent.withValues(alpha: 0.20),
        height: 76,
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

  /// Cartão responsivo com as métricas oficiais da Gestão de Dispositivos.
  Widget _deviceCard(SmartFarmRecord record) {
    final fields = record.fields;
    final alias = (fields['uavAlias'] ??
            fields['deviceSn'] ?? fields['sn'] ?? '')
        .toString().trim();
    final nickname = _deviceNicknames.containsKey(alias)
        ? _deviceNicknames[alias]!
        : (fields['uavNickname'] ?? '').toString().trim();
    final metrics = SmartFarmDeviceMetrics.fromDetails(
      _deviceStats[alias] ?? fields,
    );
    return GestureDetector(
      key: Key('device-card-' + alias),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDeviceDetails(record),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flight_outlined, color: _accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname.isEmpty ? 'Sem apelido' : nickname,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alias.isEmpty ? 'Código não informado' : alias,
                      style: const TextStyle(color: _muted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      metrics.areaHa,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Área de Trabalho (ha)',
                      style: TextStyle(color: _muted, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Container(height: 40, width: 1, color: _outline),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      metrics.flightHours,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Horas de Voo',
                      style: TextStyle(color: _muted, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _shortcut({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _panelDecoration(),
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 9, 19, 24),
      children: [
        _sectionLabel('CENTRAL DE OPERAÇÕES'),
        const SizedBox(height: 7),
        Text(
          'Olá, ${_user ?? 'Usuário'}',
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Seu campo. Sua frota. Tudo em um só lugar.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _photoBanner(
          title: 'Agricultura conectada',
          subtitle: 'Talhões, aeronaves e operações sob o mesmo controle.',
          height: 184,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _sectionLabel('ACESSO RÁPIDO'),
            const Spacer(),
            const Text(
              'SmartFarm Atlantic',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _shortcut(
          title: 'Gestão de talhões',
          subtitle: 'Consulte áreas ou importe arquivos KML',
          icon: Icons.map_outlined,
          color: _accent,
          onTap: () => _navigate(1),
        ),
        _shortcut(
          title: 'Frota de drones',
          subtitle: 'Visualize os equipamentos cadastrados',
          icon: Icons.flight_outlined,
          color: _positive,
          onTap: () => _navigate(2),
        ),
        _shortcut(
          title: 'Registros de operações',
          subtitle: 'Acompanhe os dados de voo disponíveis',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFC18A53),
          onTap: () => _navigate(3),
        ),
        const SizedBox(height: 6),
        _shortcut(
          title: 'Módulos do SmartFarm Web',
          subtitle: 'Mapas, modelos, demandas, histórico e configurações',
          icon: Icons.apps_rounded,
          color: _accent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SmartFarmWebModulesPage(gateway: widget.gateway),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: _accent),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Esta etapa oferece consultas de dados e prévia KML. '
                  'Mapas georreferenciados, edição de talhões e comandos '
                  'de voo serão integrados em etapas posteriores.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordsScreen() {
    final resource = SmartFarmResource.values[_tab - 1];
    final visible = resource != SmartFarmResource.plots ||
        _plotQuery.trim().isEmpty
        ? _records
        : _records.where((record) {
            final fields = record.fields;
            final combined = [
              PlotDisplay.name(fields),
              PlotDisplay.id(fields),
              PlotDisplay.requirement(fields),
              PlotDisplay.location(fields),
            ].join(' ').toLowerCase();
            return combined.contains(_plotQuery.toLowerCase().trim());
          }).toList(growable: false);
    if (_busy) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: _panelDecoration(borderColor: const Color(0xFF783B47)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: Color(0xFFFF6F78),
                ),
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
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadRecords(_tab),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(19, 12, 19, 28),
        children: [
          _sectionLabel('SMARTFARM  /  EAVISION'),
          const SizedBox(height: 7),
          Text(
            resource.label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registros disponíveis na sua conta autenticada.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 15),
          if (resource == SmartFarmResource.plots) ...[
            TextField(
              key: const Key('plot-search'),
              decoration: const InputDecoration(
                labelText: 'Buscar nome ou ID do talhão',
                prefixIcon: Icon(Icons.search_outlined),
              ),
              onChanged: (value) => setState(() => _plotQuery = value),
            ),
            const SizedBox(height: 13),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: _panelDecoration(borderColor: _outline),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resource == SmartFarmResource.plots
                        ? 'Talhões: ' + visible.length.toString() +
                          (_plotQuery.isEmpty ? '' : ' de ' + _records.length.toString())
                        : 'Registros exibidos: ' + _records.length.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.verified_user_outlined,
                    color: _positive, size: 19),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: _panelDecoration(),
              child: const Column(
                children: [
                  Icon(Icons.folder_open_outlined, color: _muted, size: 45),
                  SizedBox(height: 14),
                  Text(
                    'Nenhum registro retornado para esta conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          for (final record in visible)
            if (resource == SmartFarmResource.plots)
              SmartFarmPlotCard(
                record: record,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SmartFarmPlotMapPage(
                      gateway: widget.gateway,
                      record: record,
                    ),
                  ),
                ),
              )
            else if (resource == SmartFarmResource.devices)
              _deviceCard(record)
            else
              Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: _panelDecoration(),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 7,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    resource == SmartFarmResource.devices
                        ? Icons.flight_outlined
                        : resource == SmartFarmResource.plots
                        ? Icons.map_outlined
                        : Icons.assignment_outlined,
                    color: _accent,
                  ),
                ),
                title: Text(
                  record.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: record.subtitle == null
                    ? null
                    : Text(
                        record.subtitle!,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
              ),
            ),
          if (_recordsHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                key: const Key('records-load-more'),
                onPressed: _loadingMore ? null :
                    () => _loadRecords(_tab, loadMore: true),
                icon: const Icon(Icons.expand_more),
                label: Text(
                  _loadingMore ? 'Carregando...' : 'Carregar mais registros',
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _profile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 28),
      children: [
        _sectionLabel('PREFERÊNCIAS E ACESSO'),
        const SizedBox(height: 8),
        const Text(
          'Minha conta',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: _panelDecoration(),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _accent,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user ?? 'Usuário',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Sessão SmartFarm Atlantic',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_user_outlined,
                  color: _positive, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('sign-out'),
          onPressed: _busy ? null : _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: _onAccent,
            side: const BorderSide(color: _outline),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
      ],
    );
  }
}

/// Detalhes do dispositivo no mesmo fluxo do SmartFarm Web.
class _DeviceDetailsSheet extends StatefulWidget {
  const _DeviceDetailsSheet({
    required this.gateway,
    required this.record,
    required this.nickname,
    required this.initialDetails,
    required this.onSaved,
  });

  final SmartFarmGateway gateway;
  final SmartFarmRecord record;
  final String nickname;
  final Map<String, dynamic> initialDetails;
  final ValueChanged<String> onSaved;

  @override
  State<_DeviceDetailsSheet> createState() => _DeviceDetailsSheetState();
}

class _DeviceDetailsSheetState extends State<_DeviceDetailsSheet> {
  late final TextEditingController _nicknameController;
  late Map<String, dynamic> _details;
  late String _nickname;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname;
    _nicknameController = TextEditingController(text: _nickname);
    _details = Map<String, dynamic>.from(widget.initialDetails);
    _refreshDetails();
  }

  Future<void> _refreshDetails() async {
    try {
      final details = await widget.gateway.moduleDetail(
        SmartFarmModule.devices, widget.record,
      );
      if (!mounted) return;
      setState(() => _details = {..._details, ...details});
    } catch (_) {
      // Os detalhes da lista continuam disponíveis mesmo offline.
    }
  }

  Future<void> _saveNickname() async {
    if (_saving) return;
    final alias = (widget.record.fields['uavAlias'] ?? '').toString().trim();
    final name = _nicknameController.text.trim();
    if (alias.isEmpty || name.length > 90) {
      setState(() => _error = 'Apelido ou identificador inválido.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.saveDeviceNickname(alias, name);
      if (!mounted) return;
      widget.onSaved(name);
      setState(() {
        _nickname = name;
        _editing = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Widget _metric(String value, String title) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 17),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, dynamic value) {
    final text = (value ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label,
                style: const TextStyle(color: _muted, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(text.isEmpty ? '—' : text,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = {...widget.record.fields, ..._details};
    final metrics = SmartFarmDeviceMetrics.fromDetails(fields);
    final alias = (fields['uavAlias'] ?? '').toString().trim();
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
              child: Row(children: [
                const Expanded(
                  child: Text('Detalhes do Dispositivo',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Fechar detalhes',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: _muted),
                ),
              ]),
            ),
            const Divider(color: _outline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(_nickname.isEmpty ? (alias.isEmpty ? 'Aeronave' : alias) : _nickname,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _metric(metrics.areaHa, 'Área de Trabalho (ha)'),
                    const SizedBox(width: 10),
                    _metric(metrics.flightHours, 'Horas de Voo'),
                  ]),
                  const SizedBox(height: 18),
                  _field('Identificação', alias),
                  const Divider(color: _outline, height: 1),
                  if (_editing) ...[
                    const SizedBox(height: 15),
                    TextField(
                      key: const Key('device-nickname-input'),
                      controller: _nicknameController,
                      autofocus: true,
                      maxLength: 90,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveNickname(),
                      decoration: const InputDecoration(
                        labelText: 'Apelido do drone',
                        hintText: 'Digite um apelido',
                      ),
                    ),
                    if (_error != null)
                      Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFFF7A7A), fontSize: 12)),
                    Row(children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _editing = false;
                                  _error = null;
                                  _nicknameController.text = _nickname;
                                }),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const Key('device-nickname-save'),
                        onPressed: _saving ? null : _saveNickname,
                        child: Text(_saving ? 'Salvando...' : 'Salvar apelido'),
                      ),
                    ]),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        const Text('Apelido',
                            style: TextStyle(color: _muted)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_nickname.isEmpty ? '—' : _nickname,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right),
                        ),
                        IconButton(
                          key: const Key('device-nickname-edit'),
                          tooltip: 'Editar apelido',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => setState(() => _editing = true),
                        ),
                      ]),
                    ),
                    const Divider(color: _outline, height: 1),
                  ],
                  _field('Modelo', fields['uavTypeName']),
                  const Divider(color: _outline, height: 1),
                  _field('Código da aeronave', fields['uavCode']),
                  const Divider(color: _outline, height: 1),
                  _field('Código do dispositivo', fields['deviceCode']),
                  const Divider(color: _outline, height: 1),
                  _field('Código do produto', fields['productCode']),
                  const SizedBox(height: 20),
                  const Text(
                    'As métricas são consultadas na conta EAVision. '
                    '“—” significa que a API não forneceu o valor.',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
