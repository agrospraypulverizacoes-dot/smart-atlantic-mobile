// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../data/smartfarm_api.dart';
import '../plots/smartfarm_plot_map_page.dart';

const _bg = Color(0xFF071019);
const _panel = Color(0xFF0E1A2A);
const _accent = Color(0xFF1E78FF);
const _border = Color(0xFF263A50);
const _muted = Color(0xFF9EAFC3);
const _green = Color(0xFF67C23A);

/// Catálogo de módulos de consulta disponíveis no backend SmartFarm Atlantic.
/// Consultas não alteram dados nem enviam comandos de voo.
class SmartFarmWebModulesPage extends StatefulWidget {
  const SmartFarmWebModulesPage({super.key, required this.gateway});

  final SmartFarmGateway gateway;

  @override
  State<SmartFarmWebModulesPage> createState() => _SmartFarmWebModulesPageState();
}

class _SmartFarmWebModulesPageState extends State<SmartFarmWebModulesPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = SmartFarmModule.values.where((module) {
      final q = _query.toLowerCase().trim();
      return q.isEmpty ||
          module.label.toLowerCase().contains(q) ||
          module.group.toLowerCase().contains(q) ||
          module.description.toLowerCase().contains(q);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos SmartFarm',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(17, 10, 17, 25),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_panel, _bg]),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CENTRAL SMART FARM',
                      style: TextStyle(
                        color: _green, fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: 1.6,
                      )),
                  SizedBox(height: 9),
                  Text('Funcionalidades do sistema web',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    'Explore dados de talhões, frota, mapas, demandas, '
                    'histórico de operações, modelos e conta EAVision.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: _green, size: 18),
                      SizedBox(width: 8),
                      Text('Consultas autenticadas • Somente leitura',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('module-search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Buscar módulo',
                prefixIcon: Icon(Icons.search_outlined),
              ),
            ),
            const SizedBox(height: 15),
            for (final group in const [
              'Território', 'Equipamentos', 'Operações', 'Modelos', 'Conta',
            ])
              if (matches.any((module) => module.group == group)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
                  child: Text(
                    group.toUpperCase(),
                    style: const TextStyle(
                      color: _muted, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 1.8,
                    ),
                  ),
                ),
                for (final module in matches.where((m) => m.group == group))
                  Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(
                      color: _panel,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      key: Key('module-' + module.path),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconFor(module), color: _accent),
                      ),
                      title: Text(
                        module.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        module.description,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SmartFarmModuleRecordsPage(
                            gateway: widget.gateway,
                            module: module,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            if (matches.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('Nenhum módulo encontrado.',
                      style: TextStyle(color: _muted)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(SmartFarmModule module) => switch (module.group) {
    'Território' => Icons.map_outlined,
    'Equipamentos' => Icons.flight_outlined,
    'Operações' => Icons.timeline_outlined,
    'Modelos' => Icons.tune_outlined,
    _ => Icons.person_outline,
  };
}

class SmartFarmModuleRecordsPage extends StatefulWidget {
  const SmartFarmModuleRecordsPage({
    super.key, required this.gateway, required this.module,
  });

  final SmartFarmGateway gateway;
  final SmartFarmModule module;

  @override
  State<SmartFarmModuleRecordsPage> createState() =>
      _SmartFarmModuleRecordsPageState();
}

class _SmartFarmModuleRecordsPageState extends State<SmartFarmModuleRecordsPage> {
  final _filter = TextEditingController();
  final _items = <SmartFarmRecord>[];
  bool _loading = false;
  bool _hasMore = false;
  int _page = 0;
  int? _total;
  String? _error;
  DateTime? _start;
  DateTime? _end;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _requestVersion++;
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    final version = ++_requestVersion;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 0;
        _hasMore = false;
        _total = null;
      }
    });
    try {
      final result = await widget.gateway.modulePage(
        widget.module,
        pageIndex: page,
        pageSize: 50,
        filter: _filter.text.trim(),
        from: _start,
        to: _end,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _page = result.pageIndex;
        _items.addAll(result.records);
        _total = result.total;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectPeriod() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _start ?? DateTime(today.year, 1),
        end: _end ?? today,
      ),
      helpText: 'Período da operação',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
    await _load(reset: true);
  }

  String _periodLabel(DateTime? date) {
    if (date == null) return 'Selecionar período';
    return date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    return Scaffold(
      appBar: AppBar(
        title: Text(module.label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        actions: [
          IconButton(
            key: const Key('module-refresh'),
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar dados',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: [
            Text(module.group.toUpperCase(),
              style: const TextStyle(
                color: _green, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              module.description,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (module == SmartFarmModule.maps ||
                module == SmartFarmModule.sprayTemplates ||
                module == SmartFarmModule.spreadTemplates ||
                module == SmartFarmModule.operationDemand) ...[
              TextField(
                key: const Key('module-filter'),
                controller: _filter,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(reset: true),
                decoration: InputDecoration(
                  labelText: module == SmartFarmModule.maps
                      ? 'Pesquisar mapa' : 'Pesquisar registros',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Pesquisar',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _load(reset: true),
                  ),
                ),
              ),
              const SizedBox(height: 13),
            ],
            if (module.period) ...[
              OutlinedButton.icon(
                key: const Key('module-period'),
                onPressed: _selectPeriod,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _start == null ? 'Período: ano atual' :
                  _periodLabel(_start) + ' — ' + _periodLabel(_end),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _panel,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dns_outlined, color: _accent, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registros carregados: ' + _items.length.toString() +
                      (_total == null ? '' : ' / ' + _total.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.verified_user_outlined,
                      color: _green, size: 19),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D1D25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _load(reset: _page == 0),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            for (final record in _items)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: _accent),
                  title: Text(record.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: record.subtitle == null
                      ? null
                      : Text(record.subtitle!,
                          style: const TextStyle(color: _muted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => module == SmartFarmModule.plots
                          ? SmartFarmPlotMapPage(
                              gateway: widget.gateway,
                              record: record,
                            )
                          : SmartFarmRecordDetailPage(
                              gateway: widget.gateway,
                              module: module,
                              record: record,
                            ),
                    ),
                  ),
                ),
              ),
            if (!_loading && _error == null && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text('Nenhum dado retornado para esta consulta.',
                      style: TextStyle(color: _muted)),
                ),
              ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton.icon(
                  key: const Key('module-next-page'),
                  onPressed: _loading ? null : () => _load(),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Carregar mais registros'),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(21),
                child: Center(
                  child: CircularProgressIndicator(color: _accent),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Os dados são consultados na conta EAVision autenticada. '
              'Nenhuma alteração é enviada ao servidor nesta tela.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartFarmRecordDetailPage extends StatefulWidget {
  const SmartFarmRecordDetailPage({
    super.key, required this.gateway, required this.module,
    required this.record,
  });
  final SmartFarmGateway gateway;
  final SmartFarmModule module;
  final SmartFarmRecord record;

  @override
  State<SmartFarmRecordDetailPage> createState() =>
      _SmartFarmRecordDetailPageState();
}

class _SmartFarmRecordDetailPageState extends State<SmartFarmRecordDetailPage> {
  late Future<Map<String, dynamic>> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.gateway.moduleDetail(widget.module, widget.record);
  }

  String _render(dynamic value) {
    if (value == null) return '—';
    if (value is Map || value is List) {
      final raw = const JsonEncoder.withIndent('  ').convert(value);
      return raw.length > 4000 ? raw.substring(0, 4000) + '\n…' : raw;
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes do registro')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Detalhes adicionais indisponíveis: ' +
                      snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _detail = widget.gateway.moduleDetail(
                        widget.module, widget.record,
                      );
                    }),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final details = snapshot.data ?? widget.record.fields;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(widget.record.title,
              style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 23),
            ),
            const SizedBox(height: 6),
            const Text('Dados de origem da EAVision',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            for (final entry in details.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                      style: const TextStyle(
                        color: _muted, fontSize: 12,
                        fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    SelectableText(
                      _render(entry.value),
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
