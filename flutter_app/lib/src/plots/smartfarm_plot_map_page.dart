// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../data/smartfarm_api.dart';
import 'plot_geometry.dart';
import 'field_mobile_tools.dart';

const _background = Color(0xFF071019);
const _panel = Color(0xFF0E1A2A);
const _muted = Color(0xFF9EAFC3);
const _accent = Color(0xFF1E78FF);
const _outline = Color(0xFF263A50);
const _positive = Color(0xFF67C23A);

/// Cartão de talhão equivalente à listagem do SmartFarm Web.
class SmartFarmPlotCard extends StatelessWidget {
  const SmartFarmPlotCard({
    super.key, required this.record, required this.onTap,
    this.isFavorite = false, this.onFavorite,
  });
  final SmartFarmRecord record;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final fields = record.fields;
    final location = PlotDisplay.location(fields);
    final requirement = PlotDisplay.requirement(fields);
    final id = PlotDisplay.id(fields);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('plot-card-' + id),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        PlotDisplay.name(fields),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(PlotDisplay.area(fields),
                      style: const TextStyle(
                        color: Color(0xFFE0ECFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      key: Key('plot-favorite-' + id),
                      tooltip: isFavorite
                          ? 'Retirar dos favoritos'
                          : 'Adicionar aos favoritos',
                      onPressed: onFavorite,
                      icon: Icon(isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFFFC35A)
                            : _muted),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: _muted),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  id.isEmpty ? 'Talhão MapCloud' : '#' + id,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: _muted, size: 15),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(location,
                          style: const TextStyle(
                            color: _muted, fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (requirement.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132D4D),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(requirement,
                      style: const TextStyle(
                        color: Color(0xFF91C4FF), fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exibe o limite geográfico fornecido pela EAVision.
/// Não envia edições ou novos dados ao servidor.
class SmartFarmPlotMapPage extends StatefulWidget {
  const SmartFarmPlotMapPage({
    super.key, required this.gateway, required this.record,
  });
  final SmartFarmGateway gateway;
  final SmartFarmRecord record;

  @override
  State<SmartFarmPlotMapPage> createState() => _SmartFarmPlotMapPageState();
}

class _SmartFarmPlotMapPageState extends State<SmartFarmPlotMapPage> {
  late Future<Map<String, dynamic>> _detail;
  final _controller = MapController();
  bool _satellite = true;
  bool _satelliteUnavailable = false;
  int _satelliteTileFailures = 0;
  int _tileRetry = 0;
  bool _fullScreen = false;
  Position? _myPosition;
  bool _locating = false;
  bool _editingBoundary = false;
  bool _savingBoundary = false;
  List<LatLng> _draftBoundary = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = widget.gateway.moduleDetail(
      SmartFarmModule.plots, widget.record);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final p = await FieldLocation.locate();
      if (!mounted) return;
      setState(() => _myPosition = p);
      _controller.move(LatLng(p.latitude, p.longitude), 17);
      if (p.accuracy > 30) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('GPS aproximado (±' + p.accuracy.toStringAsFixed(0)
              + ' m). Não use para demarcação.'),
        ));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _navigateToPlot(PlotGeometry geometry) async {
    final center = geometry.bounds?.center;
    if (center == null) return;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rota até o talhão'),
        content: const Text('O destino é o centro aproximado do talhão, '
          'não necessariamente a entrada da propriedade. Confirme a rota antes de viajar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir navegação')),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    try {
      await FieldLocation.navigateTo(center);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _renamePlot() async {
    final detail = await _detail;
    if (!mounted) return;
    final fields = {...widget.record.fields, ...detail};
    final id = int.tryParse(PlotDisplay.id(fields));
    final geometry = PlotGeometry.fromFields(fields);
    if (id == null || geometry.boundaries.isEmpty) return;
    final controller = TextEditingController(text: PlotDisplay.name(fields));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nome do talhão'),
        content: TextField(
          key: const Key('plot-rename-input'),
          controller: controller, maxLength: 50,
          decoration: const InputDecoration(labelText: 'Novo nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Continuar')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty ||
        name == PlotDisplay.name(fields)) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar alteração'),
        content: Text('Renomear o talhão para "' + name +
          '" na EAVision? O perímetro existente será preservado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      final ring = geometry.boundaries.first;
      await widget.gateway.savePlotBoundary(
        fieldId: id, fieldName: name,
        points: ring.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _beginEditBoundary() async {
    final details = await _detail;
    if (!mounted) return;
    final geo = PlotGeometry.fromFields({...widget.record.fields, ...details});
    if (!geo.hasBoundary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O limite do talhão não está disponível.')),
      );
      return;
    }
    setState(() {
      _editingBoundary = true;
      _draftBoundary = [];
      _fullScreen = true;
    });
  }

  Future<void> _saveBoundary() async {
    if (_savingBoundary || _draftBoundary.length < 3) return;
    final id = int.tryParse(PlotDisplay.id(widget.record.fields));
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Substituir limite do talhão?'),
        content: Text('Você desenhou ' + _draftBoundary.length.toString() +
          ' vértices. A EAVision será atualizada somente após confirmar. '
          'Obstáculos e exclusões existentes serão preservados. '
          'Revise o perímetro antes de continuar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar na EAVision')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _savingBoundary = true);
    try {
      await widget.gateway.savePlotBoundary(
        fieldId: id,
        points: _draftBoundary.map((p) =>
          {'lat': p.latitude, 'lng': p.longitude}).toList(),
      );
      if (mounted) setState(() {
        _editingBoundary = false;
        _savingBoundary = false;
        _draftBoundary = [];
        _reload();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _savingBoundary = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())));
      }
    }
  }

  void _retrySatellite() {
    setState(() {
      _satellite = true;
      _satelliteUnavailable = false;
      _satelliteTileFailures = 0;
      _tileRetry++;
    });
  }

  void _onSatelliteTileError(Object error) {
    // Falhas no provedor de imagens nunca removem os perímetros da EAVision.
    debugPrint('SMARTFARM_SATELLITE_TILE_ERROR: $error');
    if (!_satellite || _satelliteUnavailable) return;
    _satelliteTileFailures++;
    if (_satelliteTileFailures < 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_satellite || _satelliteUnavailable) return;
      setState(() {
        _satellite = false;
        _satelliteUnavailable = true;
        _tileRetry++;
      });
    });
  }

  Widget _map(PlotGeometry geometry, {double? viewportHeight}) {
    final bounds = geometry.bounds;
    if (bounds == null) {
      return Container(
        height: viewportHeight ?? 310,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: _muted, size: 42),
                SizedBox(height: 14),
                Text(
                  'A EAVision não retornou o perímetro deste talhão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final height = viewportHeight ??
        math.min(530.0,
            math.max(360.0, MediaQuery.sizeOf(context).height * 0.51));
    return ClipRRect(
      borderRadius: viewportHeight == null
          ? BorderRadius.circular(18)
          : BorderRadius.zero,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: bounds.center,
                onTap: (_, point) {
                  if (_editingBoundary && _draftBoundary.length < 500) {
                    setState(() => _draftBoundary = [..._draftBoundary, point]);
                  }
                },
                initialZoom: 15,
                minZoom: 2,
                maxZoom: 20,
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(32),
                ),
              ),
              children: [
                TileLayer(
                  key: ValueKey('$_satellite-$_tileRetry'),
                  urlTemplate: _satellite
                      ? 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // A alternativa mantém as imagens de satélite no mesmo serviço Esri.
                  fallbackUrl: _satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : null,
                  errorTileCallback: (tile, error, stackTrace) {
                    if (_satellite) _onSatelliteTileError(error);
                  },
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  userAgentPackageName:
                      'br.com.atlanticdrones.smartfarm_mobile',
                  maxNativeZoom: _satellite ? 18 : 19,
                ),
                PolygonLayer(
                  polygons: [
                    for (final ring in geometry.boundaries)
                      Polygon(
                        points: ring,
                        color: _accent.withValues(alpha: 0.16),
                        borderColor: _accent,
                        borderStrokeWidth: 3.0,
                      ),
                    for (final ring in geometry.obstacles)
                      Polygon(
                        points: ring,
                        color: const Color(0x44FF5A68),
                        borderColor: const Color(0xFFFF5968),
                        borderStrokeWidth: 2.0,
                      ),
                    for (final ring in geometry.noSpray)
                      Polygon(
                        points: ring,
                        color: const Color(0x33FFAD42),
                        borderColor: const Color(0xFFFFAD42),
                        borderStrokeWidth: 2.0,
                      ),
                  ],
                ),
                if (_editingBoundary) ...[
                  if (_draftBoundary.length >= 3)
                    PolygonLayer(polygons: [
                      Polygon(
                        points: _draftBoundary,
                        color: const Color(0x33FFC35A),
                        borderColor: const Color(0xFFFFC35A),
                        borderStrokeWidth: 3,
                      ),
                    ]),
                  MarkerLayer(markers: [
                    for (final p in _draftBoundary)
                      Marker(
                        point: p, width: 20, height: 20,
                        child: const Icon(Icons.circle,
                          color: Color(0xFFFFC35A), size: 15),
                      ),
                  ]),
                ],
                if (_myPosition != null) ...[
                  CircleLayer(circles: [
                    CircleMarker(
                      point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                      radius: _myPosition!.accuracy.clamp(3, 500).toDouble(),
                      useRadiusInMeter: true,
                      color: const Color(0x221E78FF),
                      borderColor: const Color(0xFF52A4FF),
                      borderStrokeWidth: 1,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                      width: 34, height: 34,
                      child: const Icon(Icons.my_location,
                          color: Color(0xFF58B2FF), size: 27),
                    ),
                  ]),
                ],
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('Esri World Imagery / OpenStreetMap'),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: _editingBoundary
                ? Row(children: [
                    IconButton(
                      key: const Key('plot-boundary-cancel'),
                      tooltip: 'Cancelar edição',
                      onPressed: () => setState(() {
                        _editingBoundary = false;
                        _draftBoundary = [];
                      }),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(child: OutlinedButton(
                      key: const Key('plot-boundary-undo'),
                      onPressed: _draftBoundary.isEmpty ? null :
                        () => setState(() => _draftBoundary.removeLast()),
                      child: Text('Desfazer (' + _draftBoundary.length.toString() + ')'),
                    )),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('plot-boundary-save'),
                      onPressed: _savingBoundary || _draftBoundary.length < 3
                          ? null : _saveBoundary,
                      child: Text(_savingBoundary ? 'Salvando...' : 'Salvar limite'),
                    ),
                  ])
                : Row(children: [
                Expanded(child: FilledButton.icon(
                  key: const Key('plot-gps'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xF00C2239),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _locating ? null : _locateMe,
                  icon: Icon(_locating ? Icons.hourglass_top : Icons.my_location,
                      size: 18),
                  label: Text(_locating ? 'Localizando...' : 'Meu GPS'),
                )),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  key: const Key('plot-route'),
                  onPressed: () => _navigateToPlot(geometry),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Ir ao talhão'),
                )),
              ]),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xED071019),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _retrySatellite,
                          child: Text('Satélite',
                            style: TextStyle(
                              color: _satellite ? Colors.white : _muted,
                              fontWeight: _satellite
                                  ? FontWeight.w800 : FontWeight.w400,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _satellite = false;
                            _satelliteUnavailable = false;
                            _satelliteTileFailures = 0;
                          }),
                          child: Text('Mapa',
                            style: TextStyle(
                              color: !_satellite ? Colors.white : _muted,
                              fontWeight: !_satellite
                                  ? FontWeight.w800 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xED071019),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      tooltip: 'Centralizar talhão',
                      onPressed: () => _controller.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(32),
                        ),
                      ),
                      icon: const Icon(Icons.center_focus_strong,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (_satelliteUnavailable)
              Positioned(
                top: 88, left: 12, right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xED071019),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB454)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                    child: Row(
                      children: [
                        const Icon(Icons.satellite_alt_outlined,
                            color: Color(0xFFFFB454), size: 18),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Text(
                            'Satélite indisponível. Exibindo mapa.',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                        TextButton(
                          key: const Key('retry-satellite'),
                          onPressed: _retrySatellite,
                          child: const Text('Tentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xE8071019),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  geometry.vertexCount.toString() + ' pontos no limite',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(title,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text(_fullScreen ? 'Talhão · Mapa ampliado' : 'Mapa do talhão'),
      actions: [
        if (!_editingBoundary)
          IconButton(
            key: const Key('plot-rename'),
            tooltip: 'Renomear talhão',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: _renamePlot,
          ),
        if (!_editingBoundary)
          IconButton(
            key: const Key('plot-boundary-edit'),
            tooltip: 'Redesenhar limite',
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: _beginEditBoundary,
          ),
        IconButton(
          key: const Key('plot-map-fullscreen'),
          tooltip: _fullScreen
              ? 'Sair da tela cheia'
              : 'Abrir mapa em tela cheia',
          icon: Icon(_fullScreen
              ? Icons.fullscreen_exit
              : Icons.fullscreen),
          onPressed: () => setState(() => _fullScreen = !_fullScreen),
        ),
        IconButton(
          tooltip: 'Atualizar detalhes',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_reload),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snapshot) {
        final fields = {
          ...widget.record.fields,
          ...?snapshot.data,
        };
        final geometry = PlotGeometry.fromFields(fields);
        if (_fullScreen) {
          return LayoutBuilder(
            builder: (context, constraints) => _map(
              geometry,
              viewportHeight: constraints.maxHeight,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 28),
          children: [
            Text(PlotDisplay.name(fields),
              style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Talhão #' + PlotDisplay.id(fields) +
                  ' · ' + PlotDisplay.area(fields),
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 15),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: _accent),
              ),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Não foi possível carregar os detalhes: ' +
                      snapshot.error.toString(),
                  style: const TextStyle(color: Color(0xFFFFA26D)),
                ),
              ),
            _map(geometry),
            if (_myPosition != null && geometry.bounds != null) ...[
              const SizedBox(height: 10),
              Text(
                'Precisão do GPS: ±' + _myPosition!.accuracy.toStringAsFixed(0) +
                ' m · distância em linha reta: ' +
                (Geolocator.distanceBetween(
                  _myPosition!.latitude, _myPosition!.longitude,
                  geometry.bounds!.center.latitude,
                  geometry.bounds!.center.longitude,
                ) / 1000).toStringAsFixed(2) + ' km',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detalhes do talhão',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const Divider(color: _outline, height: 25),
                  _detailRow('Área', PlotDisplay.area(fields)),
                  _detailRow('Identificador', PlotDisplay.id(fields)),
                  _detailRow('Requisito', PlotDisplay.requirement(fields)),
                  _detailRow('Localização', PlotDisplay.location(fields)),
                  _detailRow('Obstáculos',
                      geometry.obstacles.length.toString()),
                  _detailRow('Áreas excluídas',
                      geometry.noSpray.length.toString()),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 17, color: _positive),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Geometria original da EAVision · Visualização somente leitura',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    ],
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
