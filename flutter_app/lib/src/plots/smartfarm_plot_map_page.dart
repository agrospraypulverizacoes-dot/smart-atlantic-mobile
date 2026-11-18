import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../data/smartfarm_api.dart';
import 'plot_geometry.dart';

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
  });
  final SmartFarmRecord record;
  final VoidCallback onTap;

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
                    const SizedBox(width: 4),
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

  Widget _map(PlotGeometry geometry) {
    final bounds = geometry.bounds;
    if (bounds == null) {
      return Container(
        height: 310,
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
    final height = math.min(530.0,
        math.max(360.0, MediaQuery.sizeOf(context).height * 0.51));
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: bounds.center,
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
                  key: ValueKey(_satellite),
                  urlTemplate: _satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('Esri World Imagery / OpenStreetMap'),
                  ],
                ),
              ],
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
                          onPressed: () => setState(() => _satellite = true),
                          child: Text('Satélite',
                            style: TextStyle(
                              color: _satellite ? Colors.white : _muted,
                              fontWeight: _satellite
                                  ? FontWeight.w800 : FontWeight.w400,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _satellite = false),
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
      title: const Text('Mapa do talhão'),
      actions: [
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
