/// Modelos de dados do feed GTFS estático.
///
/// Apenas os campos necessários para a app: paragens, carreiras, viagens,
/// horários de paragem, calendário e geometria (shapes).
library;

import 'package:latlong2/latlong.dart';

/// Uma paragem (stop) da rede TCB.
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.code,
    this.description,
    this.zoneId,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? code;
  final String? description;
  final String? zoneId;

  LatLng get point => LatLng(lat, lon);

  @override
  String toString() => 'Stop($id, $name)';
}

/// Uma carreira (linha), ex.: "1", "150".
class GtfsRoute {
  const GtfsRoute({
    required this.id,
    required this.shortName,
    required this.longName,
    this.color,
    this.textColor,
    this.type = 3,
  });

  final String id;
  final String shortName;
  final String longName;
  final String? color;
  final String? textColor;

  /// Tipo GTFS (3 = autocarro).
  final int type;

  /// Número curto para mostrar, com fallback.
  String get displayName =>
      shortName.isNotEmpty ? shortName : (longName.isNotEmpty ? longName : id);

  /// Cor da linha em `Color`, derivada de `color` (#RRGGBB) ou do hash do id.
  int get colorValue {
    final hex = color?.replaceFirst('#', '');
    if (hex != null && hex.length == 6) {
      return int.tryParse('FF$hex', radix: 16) ?? 0xFF0B7A4E;
    }
    // Cor estável por linha.
    final palette = <int>[
      0xFF0B7A4E,
      0xFF1565C0,
      0xFFC62828,
      0xFF6A1B9A,
      0xFFEF6C00,
      0xFF00838F,
      0xFF283593,
      0xFFAD1457,
    ];
    return palette[id.hashCode.abs() % palette.length];
  }
}

/// Uma viagem (trip) de uma carreira.
class Trip {
  const Trip({
    required this.id,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
    this.shapeId,
    this.directionId,
  });

  final String id;
  final String routeId;
  final String serviceId;
  final String headsign;
  final String? shapeId;
  final int? directionId;
}

/// Uma passagem de uma viagem por uma paragem (stop_times.txt).
class StopTime {
  const StopTime({
    required this.tripId,
    required this.stopId,
    required this.arrival,
    required this.departure,
    required this.sequence,
  });

  final String tripId;
  final String stopId;

  /// Segundos desde a meia-noite (podem passar de 86400 em viagens noturnas).
  final int arrival;
  final int departure;
  final int sequence;
}

/// Regras de serviço de um dia (calendar.txt).
class ServiceCalendar {
  const ServiceCalendar({
    required this.serviceId,
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  final String serviceId;

  /// YYYYMMDD (int).
  final int startDate;
  final int endDate;

  /// Dias da semana ativos (1=segunda … 7=domingo).
  final Set<int> days;

  bool runsOn(DateTime d) {
    final ymd = d.year * 10000 + d.month * 100 + d.day;
    if (ymd < startDate || ymd > endDate) return false;
    return days.contains(d.weekday);
  }
}

/// Exceção pontual de calendário (calendar_dates.txt).
class CalendarDateException {
  const CalendarDateException({
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });

  final String serviceId;

  /// YYYYMMDD (int).
  final int date;

  /// 1 = adicionado, 2 = removido.
  final int exceptionType;
}

/// Feed GTFS completo (só o que a app usa), indexado para consulta rápida.
class GtfsFeed {
  GtfsFeed({
    required this.stops,
    required this.routes,
    required this.trips,
    required this.stopTimesByStop,
    required this.stopTimesByTrip,
    required this.tripsByStop,
    required this.calendar,
    required this.calendarDates,
    required this.shapes,
  });

  final Map<String, Stop> stops;
  final Map<String, GtfsRoute> routes;
  final Map<String, Trip> trips;

  /// `stop_id -> [StopTime]` (não ordenado).
  final Map<String, List<StopTime>> stopTimesByStop;

  /// `trip_id -> [StopTime]` ordenado por [StopTime.sequence].
  final Map<String, List<StopTime>> stopTimesByTrip;

  /// `stop_id -> [trip_id]` que param ali (sem duplicados).
  final Map<String, Set<String>> tripsByStop;

  final Map<String, ServiceCalendar> calendar;
  final Map<String, List<CalendarDateException>> calendarDates;

  /// `shape_id -> [LatLng]`.
  final Map<String, List<LatLng>> shapes;

  /// Serviços ativos numa data, aplicando exceções.
  Set<String> activeServicesOn(DateTime d) {
    final ymd = d.year * 10000 + d.month * 100 + d.day;
    final active = <String>{};
    calendar.forEach((serviceId, cal) {
      if (cal.runsOn(d)) active.add(serviceId);
    });
    calendarDates.forEach((serviceId, exceptions) {
      for (final e in exceptions) {
        if (e.date == ymd) {
          if (e.exceptionType == 1) {
            active.add(serviceId);
          } else if (e.exceptionType == 2) {
            active.remove(serviceId);
          }
        }
      }
    });
    return active;
  }

  /// Carreiras que param numa paragem (ordenadas por número).
  List<GtfsRoute> routesAtStop(String stopId) {
    final tripIds = tripsByStop[stopId] ?? const <String>{};
    final seen = <String, GtfsRoute>{};
    for (final t in tripIds) {
      final trip = trips[t];
      if (trip == null) continue;
      final route = routes[trip.routeId];
      if (route != null) seen[route.id] = route;
    }
    final list = seen.values.toList();
    list.sort((a, b) => _numCompare(a.shortName, b.shortName));
    return list;
  }

  /// Paragens de uma viagem, por ordem de passagem.
  List<Stop> stopsOfTrip(String tripId) {
    final times = stopTimesByTrip[tripId] ?? const <StopTime>[];
    final out = <Stop>[];
    for (final st in times) {
      final stop = stops[st.stopId];
      if (stop != null) out.add(stop);
    }
    return out;
  }

  /// Todas as routes (variantes) com o mesmo número curto.
  List<GtfsRoute> routesForShortName(String shortName) {
    final out = routes.values
        .where((r) => r.shortName.trim() == shortName.trim())
        .toList();
    out.sort((a, b) => a.longName.compareTo(b.longName));
    return out;
  }

  /// Primeira route com o número curto indicado.
  GtfsRoute? routeByShortName(String shortName) {
    for (final r in routes.values) {
      if (r.shortName.trim() == shortName.trim()) return r;
    }
    return null;
  }

  /// Trips de todas as variantes com o mesmo número curto.
  List<Trip> tripsForShortName(String shortName) {
    final ids = routesForShortName(shortName).map((r) => r.id).toSet();
    return trips.values.where((t) => ids.contains(t.routeId)).toList();
  }

  static int _numCompare(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }
}
