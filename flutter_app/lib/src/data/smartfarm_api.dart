// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum SmartFarmResource {
  plots('plots', 'Talhões'),
  devices('devices', 'Drones'),
  operations('operations', 'Operações');

  const SmartFarmResource(this.path, this.label);
  final String path;
  final String label;
}

/// Métricas da aeronave com as mesmas unidades usadas no SmartFarm Web.
class SmartFarmDeviceMetrics {
  const SmartFarmDeviceMetrics({
    required this.areaHa,
    required this.flightHours,
  });

  final String areaHa;
  final String flightHours;

  static double? _number(dynamic value) {
    if (value == null || value == '') return null;
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().trim().replaceAll(',', '.'));
    return number != null && number.isFinite ? number : null;
  }

  static String _format(double value, {bool stripZeros = false}) {
    var text = value.toStringAsFixed(2);
    if (stripZeros) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return text.replaceAll('.', ',');
  }

  factory SmartFarmDeviceMetrics.fromDetails(Map<String, dynamic>? details) {
    final workArea = _number(details?['workArea']);
    final directHours = _number(
      details?['flightHours'] ??
          details?['flightHour'] ??
          details?['flyHours'],
    );
    final seconds = _number(
      details?['flightTime'] ?? details?['totalFlightTime'],
    );
    // Um campo de horas nulo/zero não deve ocultar uma duração
    // positiva fornecida explicitamente em segundos pela API.
    final hours = (directHours != null && directHours > 0)
        ? directHours
        : (seconds != null && seconds > 0)
            ? seconds / 3600
            : directHours ?? (seconds == null ? null : seconds / 3600);
    return SmartFarmDeviceMetrics(
      // EAVision armazena workArea em mu: 15 mu correspondem a 1 ha.
      areaHa: workArea == null ? '—' : _format(workArea / 15),
      // "—" indica ausência do campo, diferente de zero confirmado.
      flightHours: hours == null ? '—' : _format(hours, stripZeros: true),
    );
  }
}

class SmartFarmRecord {
  const SmartFarmRecord(this.fields);
  final Map<String, dynamic> fields;

  String get title {
    for (final key in [
      'name', 'fieldName', 'mapName', 'templateName', 'uavName',
      'taskName', 'plotName', 'uavAlias', 'date', 'taskCode',
      'cropName', 'title', 'accountName',
    ]) {
      final value = fields[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Registro';
  }

  String? get subtitle {
    for (final key in ['id', 'deviceSn', 'sn', 'fieldId']) {
      final value = fields[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return '$key: $value';
    }
    return null;
  }
}


enum SmartFarmModule {
  plots('plots', 'Talhões', 'Território', 'Áreas cadastradas', true),
  maps('maps', 'Gestão de mapas', 'Território', 'Mapas da conta', true),
  prescriptions('prescriptions', 'Prescrições', 'Território', 'Mapas de aplicação', true),
  cropTypes('crop-types', 'Tipos de cultivo', 'Território', 'Culturas cadastradas', true),
  cropsTop('crops-top', 'Cultivos principais', 'Território', 'Classificações de cultivo', false),
  cropShapes('crop-shapes', 'Formatos de cultivo', 'Território', 'Modelos de cultivo', true),
  devices('devices', 'Frota de drones', 'Equipamentos', 'Aeronaves vinculadas', false),
  operations('operations', 'Tarefas de voo', 'Operações', 'Registros de tarefas', true),
  operationManager('operation-manager', 'Histórico de operações', 'Operações', 'Histórico no período', true),
  operationSummary('operation-summary', 'Resumo operacional', 'Operações', 'Indicadores por período', true),
  operationDaily('operation-daily', 'Operações diárias', 'Operações', 'Indicadores diários', true),
  operationDemand('operation-demand', 'Demandas operacionais', 'Operações', 'Demandas registradas', true),
  sprayTemplates('spray-templates', 'Modelos de pulverização', 'Modelos', 'Parâmetros de pulverização', true),
  spreadTemplates('spread-templates', 'Modelos de dispersão', 'Modelos', 'Parâmetros para sólidos', true),
  units('units', 'Unidades de medida', 'Conta', 'Preferências da conta', false),
  user('user', 'Dados do usuário', 'Conta', 'Perfil EAVision', false);

  const SmartFarmModule(this.path, this.label, this.group, this.description, this.paged);
  final String path;
  final String label;
  final String group;
  final String description;
  final bool paged;
  bool get usesGet => switch (this) {
    SmartFarmModule.cropTypes ||
    SmartFarmModule.cropsTop ||
    SmartFarmModule.units ||
    SmartFarmModule.user => true,
    _ => false,
  };
  bool get period => switch (this) {
    SmartFarmModule.operationManager ||
    SmartFarmModule.operationSummary ||
    SmartFarmModule.operationDaily => true,
    _ => false,
  };
}

class SmartFarmPage {
  const SmartFarmPage({required this.records, required this.pageIndex, required this.hasMore, this.total});
  final List<SmartFarmRecord> records;
  final int pageIndex;
  final bool hasMore;
  final int? total;
}

/// Interpreta os formatos de resposta observados no SmartFarm Web/EAVision.
SmartFarmPage parseSmartFarmPage(
  Map<String, dynamic> response, {
  required int pageIndex,
  required int pageSize,
  bool paged = true,
}) {
  final status = response['status'];
  if (status != null && status.toString() != '200') {
    throw SmartFarmApiException(
      (response['message'] ?? response['detail'] ??
       ('Consulta EAVision recusada (status ' + status.toString() + ')')).toString(),
    );
  }
  final containers = <Map<dynamic, dynamic>>[];
  dynamic node = response;
  List<dynamic>? rows;
  for (var i = 0; i < 9; i++) {
    if (node is List) { rows = node; break; }
    if (node is! Map) break;
    containers.add(node);
    for (final key in ['records', 'list', 'rows', 'items', 'content']) {
      if (node[key] is List) { rows = node[key] as List<dynamic>; break; }
    }
    if (rows != null) break;
    dynamic child;
    for (final key in ['data', 'page', 'result', 'content', 'response']) {
      if (node[key] is Map || node[key] is List) { child = node[key]; break; }
    }
    if (child == null) break;
    node = child;
  }
  if (rows == null && !paged && node is Map && node.isNotEmpty) {
    rows = [node];
  }
  final items = (rows ?? const <dynamic>[])
      .whereType<Map>()
      .map((x) => SmartFarmRecord(Map<String, dynamic>.from(x)))
      .toList(growable: false);
  int? total;
  bool? explicitMore;
  for (final container in containers) {
    for (final key in ['totalCount', 'totalElements', 'total', 'recordCount']) {
      final parsed = int.tryParse((container[key] ?? '').toString());
      if (parsed != null && parsed >= 0) { total = parsed; break; }
    }
    if (total != null) break;
  }
  for (final container in containers) {
    if (container['hasMore'] is bool) { explicitMore = container['hasMore'] as bool; break; }
    if (container['hasNext'] is bool) { explicitMore = container['hasNext'] as bool; break; }
    if (container['last'] is bool) { explicitMore = !(container['last'] as bool); break; }
  }
  return SmartFarmPage(
    records: items, pageIndex: pageIndex, total: total,
    hasMore: paged && (explicitMore ??
       (total == null ? items.length >= pageSize : pageIndex * pageSize < total)),
  );
}

class SmartFarmApiException implements Exception {
  const SmartFarmApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Nome exibido no aplicativo; o login pode continuar sendo um e-mail.
String smartFarmAccountDisplayName(Map<String, dynamic> session) {
  final candidates = <dynamic>[];
  void collect(dynamic data) {
    if (data is! Map) return;
    for (final key in [
      'accountName', 'nickName', 'nickname', 'realName', 'fullName', 'name',
      'username',
    ]) {
      candidates.add(data[key]);
    }
    final account = data['account'];
    if (account is Map) {
      candidates.add(account['accountName']);
      candidates.add(account['name']);
    }
  }

  final user = session['user'];
  if (user is Map) {
    collect(user['data']);
    collect(user);
  }
  collect(session['context']);
  candidates.add(session['username']);
  for (final candidate in candidates) {
    if (candidate is! String) continue;
    final value = candidate.trim();
    if (value.isNotEmpty && !value.contains('@')) return value;
  }
  return 'Usuário';
}

abstract class SmartFarmGateway {
  Future<String?> currentUser();
  Future<String> signIn(String username, String password);
  Future<void> signOut();
  Future<List<SmartFarmRecord>> records(SmartFarmResource resource);
  // Implementações de teste anteriores continuam válidas.
  Future<SmartFarmPage> recordsPage(
    SmartFarmResource resource, {int pageIndex = 1, int pageSize = 50}
  ) async {
    final items = await records(resource);
    return SmartFarmPage(
      records: pageIndex == 1 ? items : const [],
      pageIndex: pageIndex, hasMore: false, total: items.length,
    );
  }
  Future<SmartFarmPage> modulePage(
    SmartFarmModule module, {
    int pageIndex = 1, int pageSize = 50, String filter = '',
    DateTime? from, DateTime? to,
  }) => throw const SmartFarmApiException('Módulo indisponível neste ambiente.');
  Future<Map<String, dynamic>> moduleDetail(
    SmartFarmModule module, SmartFarmRecord record,
  ) async => record.fields;
  /// Apelidos são salvos no SmartFarm e compartilhados com o Web.
  /// Demanda válida é obrigatória para criar/importar um talhão.
  Future<List<Map<String, dynamic>>> plotDemands() async => const [];

  /// Criação de talhão por KML, usando o mesmo endpoint do Web.
  Future<Map<String, dynamic>> importPlotKml({
    required int requirementId,
    required String fileName,
    required List<int> bytes,
  }) => throw const SmartFarmApiException('Importação indisponível.');

  /// Atualiza nome/limite após confirmação do operador.
  Future<Map<String, dynamic>> savePlotBoundary({
    required int fieldId,
    required List<Map<String, double>> points,
    String? fieldName,
  }) => throw const SmartFarmApiException('Edição indisponível.');

  Future<Map<String, String>> deviceNicknames() async => const {};
  Future<void> saveDeviceNickname(String uavAlias, String nickname) async {
    throw const SmartFarmApiException('Edição não disponível neste ambiente.');
  }
}

class SmartFarmApi implements SmartFarmGateway {
  SmartFarmApi({
    HttpClient? httpClient,
    Uri? baseUrl,
    this._timeout = const Duration(seconds: 15),
  }) : _client = httpClient ?? HttpClient(),
       _base = baseUrl ?? Uri.parse('https://smartfarm.atlanticdrones.com.br');

  static const sessionName = 'atlantic_smartfarm_session';
  final HttpClient _client;
  final Uri _base;
  final Duration _timeout;
  String? _cookie;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      final uri = _base.resolve(path);
      final target = query == null ? uri : uri.replace(queryParameters: query);
      final request = await _client
          .openUrl(body == null ? 'GET' : 'POST', target)
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_cookie != null) {
        request.headers.set(HttpHeaders.cookieHeader, _cookie!);
      }
      if (body != null) {
        request.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(_timeout);
      for (final cookie in response.cookies) {
        if (cookie.name == sessionName) {
          _cookie = cookie.maxAge == 0 ? null : '${cookie.name}=${cookie.value}';
        }
      }
      final payload = await utf8.decoder.bind(response).join().timeout(_timeout);
      dynamic decoded;
      try {
        decoded = jsonDecode(payload);
      } on FormatException {
        throw const SmartFarmApiException('Resposta inválida do servidor.');
      }
      if (decoded is! Map) {
        throw const SmartFarmApiException('Formato de dados inesperado.');
      }
      final result = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SmartFarmApiException(
          (result['detail'] ?? result['message'] ??
                  'Erro HTTP ${response.statusCode}')
              .toString(),
        );
      }
      return result;
    } on TimeoutException {
      throw const SmartFarmApiException('Tempo de conexão esgotado.');
    } on SocketException {
      throw const SmartFarmApiException('Sem conexão com o SmartFarm.');
    } on HandshakeException {
      throw const SmartFarmApiException('Conexão HTTPS indisponível.');
    }
  }

  @override
  Future<String?> currentUser() async {
    if (_cookie == null) return null;
    final response = await _request('/api/v1/auth/me');
    if (response['ok'] != true) return null;
    return smartFarmAccountDisplayName(response);
  }

  @override
  Future<String> signIn(String username, String password) async {
    _cookie = null;
    try {
      final login = await _request(
        '/api/v1/auth/login',
        body: {'username': username, 'password': password},
      );
      if (login['ok'] == false) {
        throw const SmartFarmApiException('Usuário ou senha inválidos.');
      }
      final user = await currentUser();
      if (user == null) {
        throw const SmartFarmApiException(
          'A sessão não foi confirmada pelo SmartFarm.',
        );
      }
      return user;
    } catch (_) {
      _cookie = null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _request('/api/v1/auth/logout', body: {});
    } finally {
      _cookie = null;
    }
  }

  @override
  Future<List<SmartFarmRecord>> records(SmartFarmResource resource) async =>
      (await recordsPage(resource)).records;

  @override
  Future<SmartFarmPage> recordsPage(
    SmartFarmResource resource, {int pageIndex = 1, int pageSize = 50}
  ) => modulePage(
    switch (resource) {
      SmartFarmResource.plots => SmartFarmModule.plots,
      SmartFarmResource.devices => SmartFarmModule.devices,
      SmartFarmResource.operations => SmartFarmModule.operations,
    },
    pageIndex: pageIndex,
    // A interface MapCloud carrega todos os talhões de uma vez para
    // permitir pesquisa local sem omitir registros.
    pageSize: resource == SmartFarmResource.plots ? 10000 : pageSize,
  );

  @override
  Future<SmartFarmPage> modulePage(
    SmartFarmModule module, {
    int pageIndex = 1, int pageSize = 50, String filter = '',
    DateTime? from, DateTime? to,
  }) async {
    if (module == SmartFarmModule.plots) {
      pageSize = 10000;
    }
    if (pageIndex < 1 || pageSize < 1 ||
        pageSize > (module == SmartFarmModule.plots ? 10000 : 100)) {
      throw const SmartFarmApiException('Paginação inválida.');
    }
    final body = <String, dynamic>{
      'pageIndex': pageIndex, 'pageSize': pageSize,
    };
    if (module == SmartFarmModule.maps) {
      body.addAll({'mapName': filter, 'type': 1});
    }
    if (module == SmartFarmModule.sprayTemplates ||
        module == SmartFarmModule.spreadTemplates) {
      body['templateName'] = filter;
    }
    if (module == SmartFarmModule.operationDemand) {
      body['keyWord'] = filter;
    }
    if (module == SmartFarmModule.operations ||
        module == SmartFarmModule.operationManager ||
        module == SmartFarmModule.operationSummary ||
        module == SmartFarmModule.operationDaily) {
      body['searchType'] = 2;
    }
    if (module.period) {
      final now = DateTime.now();
      final start = from ?? DateTime(now.year, 1, 1);
      final end = to ?? now;
      String date(DateTime value) =>
          value.year.toString().padLeft(4, '0') + '-' +
          value.month.toString().padLeft(2, '0') + '-' +
          value.day.toString().padLeft(2, '0');
      body.addAll({'startTime': date(start), 'endTime': date(end)});
    }
    Map<String, String>? query;
    if (module.usesGet && module == SmartFarmModule.cropTypes) {
      query = {
        'pageIndex': pageIndex.toString(), 'pageSize': pageSize.toString(),
      };
    }
    final response = await _request(
      '/api/v1/eav/read/' + module.path,
      body: module.usesGet ? null : body,
      query: query,
    );
    return parseSmartFarmPage(
      response, pageIndex: pageIndex, pageSize: pageSize,
      paged: module.paged,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> plotDemands() async {
    final response = await _request('/api/v1/eav/demands');
    final raw = response['items'] ?? response['data'] ?? response['demands'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['requirementId'] != null)
          Map<String, dynamic>.from(item),
    ];
  }

  @override
  Future<Map<String, dynamic>> savePlotBoundary({
    required int fieldId,
    required List<Map<String, double>> points,
    String? fieldName,
  }) async {
    if (fieldId <= 0 || points.length < 3 || points.length > 500 ||
        points.any((p) =>
          p['lat'] == null || p['lng'] == null ||
          p['lat']! < -90 || p['lat']! > 90 ||
          p['lng']! < -180 || p['lng']! > 180)) {
      throw const SmartFarmApiException('Perímetro ou talhão inválido.');
    }
    final name = fieldName?.trim();
    if (name != null && (name.isEmpty || name.length > 50)) {
      throw const SmartFarmApiException('Nome inválido (máximo 50 caracteres).');
    }
    final response = await _request(
      '/api/v1/eav/plots/' + fieldId.toString() + '/boundary',
      body: {
        'points': points,
        if (name != null) 'fieldName': name,
        // Não envia barreiras ou exclusões: o backend preserva os dados oficiais.
      },
    );
    if (response['status'] != 200 && response['ok'] != true) {
      throw SmartFarmApiException(
        (response['detail'] ?? response['message'] ?? 'Alteração não confirmada.').toString(),
      );
    }
    return response;
  }

  @override
  Future<Map<String, dynamic>> importPlotKml({
    required int requirementId,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (requirementId <= 0 || bytes.isEmpty ||
        bytes.length > 20 * 1024 * 1024 ||
        !fileName.toLowerCase().endsWith('.kml')) {
      throw const SmartFarmApiException('Demanda ou arquivo KML inválido.');
    }
    final safeName = fileName.split(RegExp(r'[/\\]')).last
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final uri = _base.resolve('/api/v1/eav/plots/import-kml')
        .replace(queryParameters: {'requirementId': requirementId.toString()});
    try {
      final request = await _client.postUrl(uri).timeout(const Duration(seconds: 25));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Filename', safeName);
      request.headers.contentType = ContentType('application', 'vnd.google-earth.kml+xml');
      if (_cookie != null) request.headers.set(HttpHeaders.cookieHeader, _cookie!);
      request.add(bytes);
      final response = await request.close().timeout(const Duration(seconds: 100));
      final text = await utf8.decoder.bind(response).join()
          .timeout(const Duration(seconds: 100));
      final raw = jsonDecode(text);
      if (raw is! Map) throw const SmartFarmApiException('Resposta inesperada.');
      final result = Map<String, dynamic>.from(raw);
      if (response.statusCode < 200 || response.statusCode >= 300 ||
          result['status'] != 200) {
        throw SmartFarmApiException(
          (result['detail'] ?? result['message'] ?? 'Importação não confirmada.').toString(),
        );
      }
      return result;
    } on TimeoutException {
      throw const SmartFarmApiException('A importação excedeu o tempo de espera.');
    } on SocketException {
      throw const SmartFarmApiException('Sem conexão para enviar o KML.');
    } on FormatException {
      throw const SmartFarmApiException('Resposta inválida ao importar o KML.');
    }
  }

  @override
  Future<Map<String, String>> deviceNicknames() async {
    final response = await _request('/api/v1/devices/nicknames');
    final raw = response['names'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.key.toString().trim().isNotEmpty)
          entry.key.toString(): (entry.value ?? '').toString().trim(),
    };
  }

  @override
  Future<void> saveDeviceNickname(String uavAlias, String nickname) async {
    final alias = uavAlias.trim();
    final name = nickname.trim();
    if (alias.isEmpty || alias.length > 100 || name.length > 90) {
      throw const SmartFarmApiException('Identificação ou apelido inválido.');
    }
    final response = await _request(
      '/api/v1/devices/nicknames',
      body: {'uavAlias': alias, 'nickname': name},
    );
    if (response['ok'] == false) {
      throw SmartFarmApiException(
        (response['detail'] ?? response['message'] ??
          'Não foi possível salvar o apelido.').toString(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> moduleDetail(
    SmartFarmModule module, SmartFarmRecord record,
  ) async {
    final fields = record.fields;
    Map<String, dynamic>? result;
    if (module == SmartFarmModule.plots) {
      final id = fields['fieldId'] ?? fields['id'];
      if (id != null && id.toString().isNotEmpty) {
        result = await _request(
          '/api/v1/eav/read/field-detail',
          query: {'fieldId': id.toString()},
        );
      }
    } else if (module == SmartFarmModule.devices) {
      final alias = fields['uavAlias'];
      if (alias != null && alias.toString().isNotEmpty) {
        result = await _request(
          '/api/v1/eav/read/device-task-stat',
          body: {'uavAlias': alias.toString()},
        );
      }
    } else if (module == SmartFarmModule.operations ||
        module == SmartFarmModule.operationManager) {
      final taskId = fields['taskId'];
      if (taskId != null && taskId.toString().isNotEmpty) {
        result = await _request(
          '/api/v1/eav/read/playback-task-detail',
          query: {'taskId': taskId.toString()},
        );
      }
    }
    if (result == null) return fields;
    final status = result['status'];
    if (status != null && status.toString() != '200') {
      throw SmartFarmApiException(
        (result['message'] ?? 'Falha ao carregar detalhes.').toString(),
      );
    }
    final data = result['data'];
    if (data is Map) {
      final additions = Map<String, dynamic>.from(data);
      // O detalhe pode retornar campos nulos que constam completos
      // na listagem do MapCloud; não descartar geometria existente.
      additions.removeWhere((key, value) => value == null ||
          (value is String && value.trim().isEmpty));
      if (module == SmartFarmModule.devices) additions['_confirmed'] = true;
      return {...fields, ...additions};
    }
    return {...fields, '_detail': data};
  }

  void dispose() => _client.close(force: true);
}
