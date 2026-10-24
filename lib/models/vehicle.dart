import 'package:latlong2/latlong.dart';

/// Um veículo (autocarro) em posição de tempo real.
class LiveVehicle {
  const LiveVehicle({
    required this.id,
    required this.lat,
    required this.lon,
    this.routeId,
    this.routeName,
    this.headsign,
    this.bearing,
    this.speedKmh,
    this.tripId,
    this.updatedAt,
  });

  final String id;
  final double lat;
  final double lon;
  final String? routeId;
  final String? routeName;
  final String? headsign;

  /// Rumo em graus (0=N, 90=E); usado para rodar o ícone.
  final double? bearing;

  /// Velocidade em km/h (pode ser null).
  final double? speedKmh;
  final String? tripId;
  final DateTime? updatedAt;

  LatLng get point => LatLng(lat, lon);

  LiveVehicle copyWith({
    String? id,
    double? lat,
    double? lon,
    String? routeId,
    String? routeName,
    String? headsign,
    double? bearing,
    double? speedKmh,
    String? tripId,
    DateTime? updatedAt,
  }) {
    return LiveVehicle(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      headsign: headsign ?? this.headsign,
      bearing: bearing ?? this.bearing,
      speedKmh: speedKmh ?? this.speedKmh,
      tripId: tripId ?? this.tripId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
