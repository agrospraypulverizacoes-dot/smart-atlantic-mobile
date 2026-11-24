import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// A localização é consultada somente após uma ação explícita do operador.
class FieldLocation {
  static Future<Position> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do celular para usar o GPS.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'O SmartFarm não recebeu permissão de localização. '
        'Verifique as permissões nas configurações do celular.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 18),
      ),
    );
  }

  static Uri directionsUri(LatLng destination) => Uri.https(
    'www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination.latitude.toStringAsFixed(7) + ',' +
          destination.longitude.toStringAsFixed(7),
      'travelmode': 'driving',
    },
  );

  /// Abre a navegação externa. O GPS não é enviado ao servidor SmartFarm.
  static Future<void> navigateTo(LatLng destination) async {
    final ok = await launchUrl(
      directionsUri(destination), mode: LaunchMode.externalApplication,
    );
    if (!ok) throw StateError('Não foi possível abrir a navegação.');
  }
}

/// IDs favoritos ficam no dispositivo, separados pela conta de origem.
class FieldFavorites {
  FieldFavorites(this.account);
  final String account;
  static const _prefix = 'atlantic_smartfarm.mobile_favorites.v1.';
  String get _key => _prefix + Uri.encodeComponent(account);

  Future<Set<String>> load() async {
    final prefs = SharedPreferencesAsync();
    return (await prefs.getStringList(_key) ?? <String>[]).toSet();
  }

  Future<void> save(Set<String> ids) async {
    final prefs = SharedPreferencesAsync();
    final values = ids.toList()..sort();
    await prefs.setStringList(_key, values);
  }
}
