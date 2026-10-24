import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

import '../models/gtfs_models.dart';
import 'csv.dart';

/// Parser do feed GTFS estático (ZIP) da TCB.
class GtfsParser {
  const GtfsParser._();

  /// Faz o parsing dos bytes de um ZIP GTFS para um [GtfsFeed] indexado.
  static GtfsFeed parse(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <String, String>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.split('/').last.toLowerCase();
      if (name.endsWith('.txt')) {
        files[name] = utf8.decode(file.readBytes(), allowMalformed: true);
      }
    }

    final stopTimes = _stopTimes(files);

    return GtfsFeed(
      stops: _parseStops(files),
      routes: _parseRoutes(files),
      trips: _parseTrips(files),
      stopTimesByStop: stopTimes.byStop,
      stopTimesByTrip: stopTimes.byTrip,
      tripsByStop: _tripsByStop(files),
      calendar: _parseCalendar(files),
      calendarDates: _parseCalendarDates(files),
      shapes: _parseShapes(files),
    );
  }

  static Map<String, Stop> _parseStops(Map<String, String> f) {
    final txt = f['stops.txt'];
    if (txt == null) return const {};
    final out = <String, Stop>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['stop_id'];
      if (id == null || id.isEmpty) continue;
      out[id] = Stop(
        id: id,
        name: (m['stop_name'] ?? '').trim(),
        lat: double.tryParse(m['stop_lat'] ?? '') ?? 0,
        lon: double.tryParse(m['stop_lon'] ?? '') ?? 0,
        code: _emptyToNull(m['stop_code']),
        description: _emptyToNull(m['stop_desc']),
        zoneId: _emptyToNull(m['zone_id']),
      );
    }
    return out;
  }

  static Map<String, GtfsRoute> _parseRoutes(Map<String, String> f) {
    final txt = f['routes.txt'];
    if (txt == null) return const {};
    final out = <String, GtfsRoute>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['route_id'];
      if (id == null || id.isEmpty) continue;
      out[id] = GtfsRoute(
        id: id,
        shortName: (m['route_short_name'] ?? '').trim(),
        longName: (m['route_long_name'] ?? '').trim(),
        color: _emptyToNull(m['route_color']),
        textColor: _emptyToNull(m['route_text_color']),
        type: int.tryParse(m['route_type'] ?? '') ?? 3,
      );
    }
    return out;
  }

  static Map<String, Trip> _parseTrips(Map<String, String> f) {
    final txt = f['trips.txt'];
    if (txt == null) return const {};
    final out = <String, Trip>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['trip_id'];
      if (id == null || id.isEmpty) continue;
      out[id] = Trip(
        id: id,
        routeId: m['route_id'] ?? '',
        serviceId: m['service_id'] ?? '',
        headsign: (m['trip_headsign'] ?? '').trim(),
        shapeId: _emptyToNull(m['shape_id']),
        directionId: int.tryParse(m['direction_id'] ?? ''),
      );
    }
    return out;
  }

  static ({Map<String, List<StopTime>> byStop, Map<String, List<StopTime>> byTrip})
      _stopTimes(Map<String, String> f) {
    final txt = f['stop_times.txt'];
    if (txt == null) return (byStop: const {}, byTrip: const {});
    final byStop = <String, List<StopTime>>{};
    final byTrip = <String, List<StopTime>>{};
    for (final m in parseCsvToMaps(txt)) {
      final tripId = m['trip_id'];
      final stopId = m['stop_id'];
      if (tripId == null || stopId == null || stopId.isEmpty) continue;
      final st = StopTime(
        tripId: tripId,
        stopId: stopId,
        arrival: _timeToSeconds(m['arrival_time'] ?? ''),
        departure: _timeToSeconds(m['departure_time'] ?? ''),
        sequence: int.tryParse(m['stop_sequence'] ?? '') ?? 0,
      );
      (byStop[stopId] ??= []).add(st);
      (byTrip[tripId] ??= []).add(st);
    }
    byTrip.forEach((_, v) => v.sort((a, b) => a.sequence.compareTo(b.sequence)));
    return (byStop: byStop, byTrip: byTrip);
  }

  static Map<String, Set<String>> _tripsByStop(Map<String, String> f) {
    final txt = f['stop_times.txt'];
    if (txt == null) return const {};
    final out = <String, Set<String>>{};
    for (final m in parseCsvToMaps(txt)) {
      final tripId = m['trip_id'];
      final stopId = m['stop_id'];
      if (tripId == null || stopId == null || stopId.isEmpty) continue;
      (out[stopId] ??= <String>{}).add(tripId);
    }
    return out;
  }

  static Map<String, ServiceCalendar> _parseCalendar(Map<String, String> f) {
    final txt = f['calendar.txt'];
    if (txt == null) return const {};
    final out = <String, ServiceCalendar>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['service_id'];
      if (id == null || id.isEmpty) continue;
      final days = <int>{};
      const map = {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7};
      map.forEach((col, wd) {
        if ((m[col] ?? '') == '1') days.add(wd);
      });
      out[id] = ServiceCalendar(
        serviceId: id,
        startDate: int.tryParse(m['start_date'] ?? '') ?? 0,
        endDate: int.tryParse(m['end_date'] ?? '') ?? 0,
        days: days,
      );
    }
    return out;
  }

  static Map<String, List<CalendarDateException>> _parseCalendarDates(
      Map<String, String> f) {
    final txt = f['calendar_dates.txt'];
    if (txt == null) return const {};
    final out = <String, List<CalendarDateException>>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['service_id'];
      if (id == null || id.isEmpty) continue;
      (out[id] ??= []).add(CalendarDateException(
        serviceId: id,
        date: int.tryParse(m['date'] ?? '') ?? 0,
        exceptionType: int.tryParse(m['exception_type'] ?? '') ?? 0,
      ));
    }
    return out;
  }

  static Map<String, List<LatLng>> _parseShapes(Map<String, String> f) {
    final txt = f['shapes.txt'];
    if (txt == null) return const {};
    final byShape = <String, Map<int, LatLng>>{};
    for (final m in parseCsvToMaps(txt)) {
      final id = m['shape_id'];
      final lat = double.tryParse(m['shape_pt_lat'] ?? '');
      final lon = double.tryParse(m['shape_pt_lon'] ?? '');
      final seq = int.tryParse(m['shape_pt_sequence'] ?? '');
      if (id == null || id.isEmpty || lat == null || lon == null || seq == null) {
        continue;
      }
      (byShape[id] ??= {})[seq] = LatLng(lat, lon);
    }
    final out = <String, List<LatLng>>{};
    byShape.forEach((id, pts) {
      final keys = pts.keys.toList()..sort();
      out[id] = keys.map((k) => pts[k]!).toList();
    });
    return out;
  }

  static int _timeToSeconds(String t) {
    final parts = t.split(':');
    if (parts.length < 3) return -1;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  static String? _emptyToNull(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
