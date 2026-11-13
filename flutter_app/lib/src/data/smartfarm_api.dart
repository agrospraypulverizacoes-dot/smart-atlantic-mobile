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

class SmartFarmRecord {
  const SmartFarmRecord(this.fields);
  final Map<String, dynamic> fields;

  String get title {
    for (final key in ['name', 'fieldName', 'uavName', 'taskName', 'plotName']) {
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

class SmartFarmApiException implements Exception {
  const SmartFarmApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class SmartFarmGateway {
  Future<String?> currentUser();
  Future<String> signIn(String username, String password);
  Future<void> signOut();
  Future<List<SmartFarmRecord>> records(SmartFarmResource resource);
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
  }) async {
    try {
      final request = await _client
          .openUrl(body == null ? 'GET' : 'POST', _base.resolve(path))
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
    return (response['username'] ?? response['user'] ?? 'Usuário').toString();
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
  Future<List<SmartFarmRecord>> records(SmartFarmResource resource) async {
    final request = <String, dynamic>{'pageIndex': 1, 'pageSize': 30};
    if (resource == SmartFarmResource.operations) request['searchType'] = 2;
    final response = await _request(
      '/api/v1/eav/read/${resource.path}',
      body: request,
    );
    dynamic node = response['data'] ?? response;
    if (node is Map && node['data'] != null) node = node['data'];
    if (node is Map) {
      for (final key in ['records', 'list', 'rows', 'items']) {
        if (node[key] is List) {
          node = node[key];
          break;
        }
      }
    }
    if (node is! List) return const [];
    return node
        .whereType<Map>()
        .map((item) => SmartFarmRecord(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  void dispose() => _client.close(force: true);
}
