import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/gtfs_models.dart';

/// Acesso à localização do utilizador (opcional e com tratamento de erros).
class LocationService {
  const LocationService();

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
