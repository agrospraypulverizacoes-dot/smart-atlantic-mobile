import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'plot_geometry.dart';

/// Visualizador de relevo somente leitura. Reutiliza a mesma engine (MapLibre
/// GL JS 5.17), fonte de elevação DEM Terrarium e simbologia do SmartFarm Web.
/// Não abre uma rota web fictícia nem compartilha cookies ou tokens EAVision.
class SmartFarmPlot3DViewer extends StatefulWidget {
  const SmartFarmPlot3DViewer({super.key, required this.geometry});

  final PlotGeometry geometry;

  @override
  State<SmartFarmPlot3DViewer> createState() => _SmartFarmPlot3DViewerState();
}

/// Converte as geometrias já obtidas da EAVision, sem novas chamadas de API.
/// GeoJSON exige [longitude, latitude], diferente do tipo LatLng do Flutter.
Map<String, dynamic> smartFarm3DGeoJson(PlotGeometry geometry) {
  final features = <Map<String, dynamic>>[];

  void append(String kind, List<List<dynamic>> rings) {
    for (final ring in rings) {
      if (ring.length < 3) continue;
      final coordinates = ring.map((point) {
        final value = point as dynamic;
        return <double>[value.longitude, value.latitude];
      }).toList();
      if (coordinates.first[0] != coordinates.last[0] ||
          coordinates.first[1] != coordinates.last[1]) {
        coordinates.add(List<double>.from(coordinates.first));
      }
      features.add({
        'type': 'Feature',
        'properties': {'kind': kind, 'selected': kind == 'plot'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
      });
    }
  }

  append('plot', geometry.boundaries);
  append('obstacle', geometry.obstacles);
  append('no-spray', geometry.noSpray);
  return {'type': 'FeatureCollection', 'features': features};
}

String smartFarmPlot3DHtml(PlotGeometry geometry) {
  final geojson = jsonEncode(smartFarm3DGeoJson(geometry));
  final bounds = geometry.bounds;
  if (bounds == null) throw StateError('Talhão sem perímetro disponível.');
  final bbox = jsonEncode([
    [bounds.west, bounds.south],
    [bounds.east, bounds.north],
  ]);
  return _html3D
      .replaceFirst('__GEOJSON__', geojson)
      .replaceFirst('__BOUNDS__', bbox);
}

class _SmartFarmPlot3DViewerState extends State<SmartFarmPlot3DViewer> {
  late WebViewController _controller;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() {
      _error = null;
      _ready = false;
    });
    _controller = WebViewController();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(const Color(0xFF071019));
      await _controller.addJavaScriptChannel(
        'Atlantic3D',
        onMessageReceived: (event) {
          if (!mounted) return;
          final text = event.message;
          if (text == 'ready') {
            setState(() => _ready = true);
          } else if (text.startsWith('error:')) {
            setState(() => _error = text.substring(6).trim());
          }
        },
      );
      await _controller.loadHtmlString(
        smartFarmPlot3DHtml(widget.geometry),
        baseUrl: 'https://smartfarm.atlanticdrones.com.br/',
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(key: const Key('plot-3d-webview'), controller: _controller),
        if (!_ready && _error == null)
          const ColoredBox(
            color: Color(0xFF071019),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E78FF)),
                  SizedBox(height: 12),
                  Text('Carregando relevo 3D...',
                      style: TextStyle(color: Color(0xFFD6E4F1))),
                  SizedBox(height: 6),
                  Text('Requer internet e aceleração gráfica',
                      style: TextStyle(
                          color: Color(0xFF9EAFC3), fontSize: 11)),
                ],
              ),
            ),
          ),
        if (_error != null)
          ColoredBox(
            color: const Color(0xF4071019),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.terrain_outlined,
                        color: Color(0xFFFFB454), size: 38),
                    const SizedBox(height: 12),
                    const Text('Visualização 3D indisponível',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF9EAFC3), fontSize: 12)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('plot-3d-retry'),
                      onPressed: _start,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Selecione 2D para voltar ao mapa convencional.',
                        style: TextStyle(
                            color: Color(0xFF9EAFC3), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A cena usa os mesmos elementos do módulo SmartFarm Web: raster Esri,
/// elevação Mapzen/Tilezen Terrarium, globo e inclinação 58 graus. O Web usa
/// uma fonte Esri customizada; aqui o raster é carregado diretamente por
/// HTTPS, sem depender da sessão/cookies do navegador do usuário.
const String _html3D = r'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/maplibre-gl@5.17.0/dist/maplibre-gl.css">
<style>
html,body,#map { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background:#071019; }
* { box-sizing:border-box; }
#map { position:absolute; inset:0; }
#controls { position:absolute; right:10px; top:78px; display:flex; flex-direction:column; gap:7px; z-index:5; }
#controls button { background:rgba(7,16,25,.92); color:#edf3f8; border:1px solid #263a50; border-radius:9px; width:44px; height:42px; font-size:11px; font-weight:700; }
#hint { position:absolute; left:10px; bottom:8px; z-index:4; font:11px sans-serif; border-radius:8px; padding:7px 9px; background:rgba(7,16,25,.84); color:#dde5ed; pointer-events:none; }
.maplibregl-ctrl-bottom-right { bottom:30px; }
.maplibregl-ctrl-attrib { font-size:9px!important; }
</style>
<script src="https://cdn.jsdelivr.net/npm/maplibre-gl@5.17.0/dist/maplibre-gl.js"></script>
</head>
<body>
<div id="map"></div>
<div id="controls" role="group" aria-label="Controles 3D">
<button id="center" aria-label="Centralizar talhão">Alvo</button>
<button id="north" aria-label="Orientar para norte">Norte</button>
<button id="tilt" aria-label="Inclinar visão">Inclinar</button>
</div>
<div id="hint">3D • Arraste para navegar e use dois dedos para inclinar</div>
<script>
(function () {
  'use strict';
  const geo = __GEOJSON__;
  const bbox = __BOUNDS__;
  let map = null, finished = false;
  function post(v) {
    try { if(window.Atlantic3D && window.Atlantic3D.postMessage) window.Atlantic3D.postMessage(v); }
    catch (ignored) {}
  }
  function fail(message) {
    if(finished) return;
    finished = true;
    post('error:' + String(message || 'Falha ao abrir o relevo'));
    try { if(map) map.remove(); } catch (ignored) {}
  }
  const watchdog = setTimeout(function(){
    fail('Tempo limite ao carregar o 3D. Verifique a conexão.');
  },22000);

  if(!window.maplibregl || !maplibregl.supported()) {
    clearTimeout(watchdog);
    fail('WebGL indisponível no dispositivo ou no emulador.');
    return;
  }

  const select = ['case',['get','selected'],'#ffb000','#2e9df1'];
  const style = {
    version:8,
    sources:{
      satellite: {
        type:'raster',
        tiles:['https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
        tileSize:256,minzoom:2,maxzoom:18,attribution:'Esri World Imagery'
      },
      relief:{
        type:'raster-dem',
        tiles:['https://elevation-tiles-prod.s3.amazonaws.com/terrarium/{z}/{x}/{y}.png'],
        tileSize:256,maxzoom:14,encoding:'terrarium',attribution:'Mapzen/Tilezen, USGS'
      },
      plots:{type:'geojson',data:geo}
    },
    layers:[
      {id:'satellite',type:'raster',source:'satellite'},
      {id:'plot-fill',type:'fill',source:'plots',filter:['==',['get','kind'],'plot'],
       paint:{'fill-color':select,'fill-opacity':0.17}},
      {id:'plot-border',type:'line',source:'plots',filter:['==',['get','kind'],'plot'],
       paint:{'line-color':select,'line-width':2.0}},
      {id:'obstacles',type:'fill',source:'plots',filter:['==',['get','kind'],'obstacle'],
       paint:{'fill-color':'#ee5664','fill-opacity':0.28}},
      {id:'no-spray',type:'fill',source:'plots',filter:['==',['get','kind'],'no-spray'],
       paint:{'fill-color':'#eaa23b','fill-opacity':0.25}}
    ]
  };
  function focus(){
    if(!map) return;
    map.resize();
    map.fitBounds(bbox,{padding:{top:106,bottom:60,left:35,right:35},
      maxZoom:17,bearing:0,pitch:58,duration:0});
  }
  try {
    map = new maplibregl.Map({
      container:'map',style:style,
      center:[(bbox[0][0]+bbox[1][0])/2,(bbox[0][1]+bbox[1][1])/2],
      zoom:13,pitch:58,bearing:0,maxPitch:80,attributionControl:true,
      renderWorldCopies:false
    });
    map.on('error',function(e){
      const message=String(e && e.error && e.error.message || '');
      if(/terrain|elevation-tiles|raster-dem|terrarium/i.test(message)){
        clearTimeout(watchdog);fail('Dados de relevo indisponíveis. Utilize o modo 2D.');
      }
    });
    map.once('load',function(){
      if(finished) return;
      try {
        map.setProjection({type:'globe'});
        map.setTerrain({source:'relief',exaggeration:1});
        focus();
        clearTimeout(watchdog);
        finished = true;
        post('ready');
      } catch(error) {
        clearTimeout(watchdog);
        fail(error && error.message || String(error));
      }
    });
    document.getElementById('center').onclick=focus;
    document.getElementById('north').onclick=function(){
      if(map) map.easeTo({bearing:0,duration:450});
    };
    document.getElementById('tilt').onclick=function(){
      if(map) map.easeTo({pitch:map.getPitch()>68?30:75,duration:450});
    };
  } catch(error) {
    clearTimeout(watchdog);
    fail(error && error.message || String(error));
  }
})();
</script>
</body></html>''';
