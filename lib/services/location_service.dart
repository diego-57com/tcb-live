import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/gtfs_models.dart';

/// Acesso à localização do utilizador (opcional e com tratamento de erros).
class LocationService {
  const LocationService();

  StreamSubscription<Position>? _sub;

  /// Posição atual, ou null se não houver permissão/serviço/erro.
  Future<LatLng?> currentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Pede permissão de localização. Devolve true se concedida.
  Future<bool> requestTrackingPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Inicia atualizações contínuas de posição. Chama [onPosition] a cada nova leitura.
  void startTracking(void Function(LatLng) onPosition) {
    stopTracking();
    _sub = Geolocator.positionStream.listen((pos) {
      onPosition(LatLng(pos.latitude, pos.longitude));
    });
  }

  /// Para as atualizações contínuas.
  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  /// Paragens ordenadas por distância à posição dada.
  List<Stop> nearestStops(
    GtfsFeed feed,
    LatLng origin, {
    int limit = 20,
  }) {
    final all = feed.stops.values.toList();
    return sortByDistance(all, origin).take(limit).toList();
  }

  /// Ordena uma lista de paragens pela distância a [origin].
  static List<Stop> sortByDistance(List<Stop> stops, LatLng origin) {
    final list = stops.toList();
    list.sort((a, b) => distanceMeters(origin, a.point).compareTo(distanceMeters(origin, b.point)));
    return list;
  }

  /// Distância (metros) entre dois pontos (haversine).
  static double distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
