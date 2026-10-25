import '../models/gtfs_models.dart';

/// Uma partida prevista numa paragem (baseada no horário GTFS).
class Departure {
  const Departure({
    required this.trip,
    required this.route,
    required this.departureSeconds,
  });

  final Trip trip;
  final GtfsRoute route;

  /// Segundos desde a meia-noite do dia de serviço (pode ser > 86400).
  final int departureSeconds;

  String get lineName =>
      route.shortName.isNotEmpty ? route.shortName : route.longName;

  String get headsign =>
      trip.headsign.isNotEmpty ? trip.headsign : route.longName;

  /// Instante real de partida (considera viagens pós-meia-noite).
  DateTime departureAt(DateTime now) {
    final base = DateTime(now.year, now.month, now.day);
    return base.add(Duration(seconds: departureSeconds));
  }

  /// Minutos até à partida (pode ser 0 para "agora").
  int minutesUntil(DateTime now) {
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    return ((departureSeconds - nowSec) / 60).floor();
  }
}

/// Calcula as próximas passagens de uma paragem a partir do horário.
class DepartureEngine {
  const DepartureEngine._();

  /// Passagens de uma viagem concreta por uma paragem (para o detalhe da carreira).
  ///
  /// Devolve as próximas passagens em [stopId] das viagens de [tripIds], com a
  /// mesma lógica de janela e tolerância de [nextDepartures].
  static List<Departure> nextDeparturesForTrips(
    GtfsFeed feed,
    String stopId,
    Set<String> tripIds,
    DateTime now, {
    int limit = 6,
    Duration window = const Duration(hours: 3),
  }) {
    final active = feed.activeServicesOn(now);
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    final windowSec = window.inSeconds;

    final result = <Departure>[];
    final times = feed.stopTimesByStop[stopId] ?? const <StopTime>[];

    for (final st in times) {
      if (!tripIds.contains(st.tripId)) continue;
      final trip = feed.trips[st.tripId];
      if (trip == null) continue;
      if (!active.contains(trip.serviceId)) continue;

      var dep = st.departure;
      if (dep < 0) dep = st.arrival;
      if (dep < 0) continue;
      if (dep < nowSec - 60) continue;
      if (dep - nowSec > windowSec) continue;

      final route = feed.routes[trip.routeId];
      if (route == null) continue;

      result.add(Departure(
        trip: trip,
        route: route,
        departureSeconds: dep,
      ));
    }

    result.sort((a, b) => a.departureSeconds.compareTo(b.departureSeconds));
    return result.take(limit).toList();
  }

  static List<Departure> nextDepartures(
    GtfsFeed feed,
    String stopId,
    DateTime now, {
    int limit = 20,
    Duration window = const Duration(hours: 2),
  }) {
    final active = feed.activeServicesOn(now);
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    final windowSec = window.inSeconds;

    final result = <Departure>[];
    final times = feed.stopTimesByStop[stopId] ?? const <StopTime>[];

    for (final st in times) {
      final trip = feed.trips[st.tripId];
      if (trip == null) continue;
      if (!active.contains(trip.serviceId)) continue;

      var dep = st.departure;
      if (dep < 0) dep = st.arrival;
      if (dep < 0) continue;

      // Ignora partidas já decorridas (com 1 minuto de tolerância).
      if (dep < nowSec - 60) continue;
      // Janela máxima de consulta.
      if (dep - nowSec > windowSec) continue;

      final route = feed.routes[trip.routeId];
      if (route == null) continue;

      result.add(Departure(
        trip: trip,
        route: route,
        departureSeconds: dep,
      ));
    }

    result.sort((a, b) => a.departureSeconds.compareTo(b.departureSeconds));
    return result.take(limit).toList();
  }
}
