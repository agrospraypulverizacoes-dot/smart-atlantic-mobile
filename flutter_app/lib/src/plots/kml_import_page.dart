import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'kml_parser.dart';
import '../data/smartfarm_api.dart';

class KmlImportPage extends StatefulWidget {
  const KmlImportPage({super.key, this.gateway});
  final SmartFarmGateway? gateway;
  @override
  State<KmlImportPage> createState() => _KmlImportPageState();
}

class _KmlImportPageState extends State<KmlImportPage> {
  final _plots = <KmlPlot>[];
  bool _loading = false;
  String? _error;
  int _selection = 0;
  List<int>? _bytes;
  String? _fileName;
  List<Map<String, dynamic>> _demands = const [];
  int? _demandId;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.gateway != null) _loadDemands();
  }

  Future<void> _loadDemands() async {
    try {
      final list = await widget.gateway!.plotDemands();
      if (mounted) setState(() => _demands = list);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _upload() async {
    if (_bytes == null || _fileName == null || _demandId == null ||
        widget.gateway == null || _uploading) return;
    final approve = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar talhões na EAVision?'),
        content: Text('Arquivo: ' + _fileName! +
          '\nDemanda ID: ' + _demandId.toString() +
          '\n\nConfirme os contornos antes de criar os registros.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar agora')),
        ],
      ),
    );
    if (approve != true || !mounted) return;
    setState(() { _uploading = true; _error = null; });
    try {
      await widget.gateway!.importPlotKml(
        requirementId: _demandId!, fileName: _fileName!, bytes: _bytes!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _chooseKml() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml'],
      );
      final found = <KmlPlot>[];
      final failures = <String>[];
      for (final file in files) {
        try {
          if (!file.name.toLowerCase().endsWith('.kml')) {
            throw const FormatException('Arquivo não é KML ou excede 5 MB.');
          }
          final data = await file.readAsBytes();
          if (data.lengthInBytes > 5 * 1024 * 1024) {
            throw const FormatException('KML maior que 5 MB.');
          }
          final parsed = readKmlPlots(utf8.decode(data), file.name);
          found.addAll(parsed);
          if (parsed.isNotEmpty) { _bytes = data; _fileName = file.name; }
        } catch (error) {
          failures.add([file.name, error.toString()].join(': '));
        }
      }
      if (!mounted) return;
      setState(() {
        _plots.addAll(found);
        _error = failures.isEmpty ? null : failures.join('\n');
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _plots.length;
    final selected = _plots.isEmpty ? null : _plots[_selection];
    return Scaffold(
      appBar: AppBar(title: const Text('Talhões KML')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Gestão de talhões',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Importe arquivos KML para separar os contornos e '
              'visualizar cada talhão com nome e coordenadas originais.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('choose-kml'),
            onPressed: _loading ? null : _chooseKml,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_loading ? 'Importando...' : 'Selecionar KML'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF958D))),
          ],
          const SizedBox(height: 20),
          Text('Talhões carregados: $count',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          if (selected != null) ...[
            const SizedBox(height: 16),
            Text(selected.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 230,
              color: const Color(0xFF0E1A2A),
              child: CustomPaint(
                painter: _BoundaryPainter(selected),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Prévia geométrica local sem mapa de fundo. '
              'Ainda não corresponde a uma missão de voo.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9EAFC3))),
            const SizedBox(height: 12),
            for (var i = 0; i < _plots.length; i++)
              ListTile(
                selected: i == _selection,
                leading: const Icon(Icons.map_outlined),
                title: Text(_plots[i].name),
                subtitle: Text(_plots[i].source),
                onTap: () => setState(() => _selection = i),
              ),
            OutlinedButton(
              onPressed: () => setState(() {
                _plots.clear(); _selection = 0; _error = null;
              }),
              child: const Text('Limpar sessão'),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.gateway != null) ...[
            DropdownButtonFormField<int>(
              key: const Key('kml-demand'),
              initialValue: _demandId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Demanda de destino'),
              items: [
                for (final d in _demands)
                  if (int.tryParse(d['requirementId'].toString()) != null)
                    DropdownMenuItem(
                      value: int.parse(d['requirementId'].toString()),
                      child: Text((d['requirementName'] ?? 'Demanda').toString(),
                        overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (id) => setState(() => _demandId = id),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('kml-upload'),
              onPressed: (_bytes == null || _demandId == null || _uploading)
                  ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading ? 'Enviando...' : 'Importar na EAVision'),
            ),
            const SizedBox(height: 10),
            const Text('Os talhões serão criados apenas após confirmação.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9EAFC3))),
          ] else
            const Text('Prévia local. Conecte a conta para importar.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9EAFC3))),
        ],
      ),
    );
  }
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter(this.plot);
  final KmlPlot plot;
  @override
  void paint(Canvas canvas, Size size) {
    final ring = plot.ring;
    if (ring.length < 4 || size.isEmpty) return;
    final west = ring.map((v) => v.longitude).reduce(math.min);
    final east = ring.map((v) => v.longitude).reduce(math.max);
    final south = ring.map((v) => v.latitude).reduce(math.min);
    final north = ring.map((v) => v.latitude).reduce(math.max);
    final factor = math.cos((north + south) * math.pi / 360).abs();
    final width = (east - west) * factor;
    final height = north - south;
    final scale = math.min((size.width - 28) / math.max(width, 1e-9),
      (size.height - 28) / math.max(height, 1e-9));
    final x0 = (size.width - width * scale) / 2;
    final y0 = (size.height - height * scale) / 2;
    Offset xy(KmlVertex v) => Offset(
      x0 + (v.longitude - west) * factor * scale,
      size.height - y0 - (v.latitude - south) * scale,
    );
    final initial = xy(ring.first);
    final outline = Path()..moveTo(initial.dx, initial.dy);
    for (final point in ring.skip(1)) {
      final pt = xy(point);
      outline.lineTo(pt.dx, pt.dy);
    }
    outline.close();
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF1E78FF));
  }
  @override
  bool shouldRepaint(covariant _BoundaryPainter previous) =>
      previous.plot != plot;
}
