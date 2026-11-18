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
