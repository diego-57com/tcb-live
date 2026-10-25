import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vehicle.dart';

/// Fonte de posições em tempo real (genérica e configurável pelo utilizador).
abstract class RealtimeSource {
  Future<List<LiveVehicle>> fetch();
}

/// Extrai uma lista de veículos de um endpoint JSON.
class JsonVehiclesSource implements RealtimeSource {
  JsonVehiclesSource(this.config);

  final JsonVehiclesConfig config;

  @override
  Future<List<LiveVehicle>> fetch() async {
    final resp = await http.get(Uri.parse(config.url));
    if (resp.statusCode != 200) {
      throw Exception('Realtime HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));

    dynamic list = decoded;
    for (final key in config.arrayPath) {
      if (list is Map) {
        list = list[key];
      } else {
        list = null;
        break;
      }
    }
    if (list is! List) {
      throw const FormatException('Caminho do array não encontrado no JSON');
    }

    final out = <LiveVehicle>[];
    for (final item in list) {
      if (item is! Map) continue;
      final lat = _num(item, config.latField);
      final lon = _num(item, config.lonField);
      final id = _str(item, config.idField);
      if (lat == null || lon == null || id == null) continue;
      out.add(LiveVehicle(
        id: id,
        lat: lat,
        lon: lon,
        routeId: _str(item, config.routeField),
        routeName: _str(item, config.routeNameField),
        headsign: _str(item, config.headsignField),
        routeColor: _color(item, config.routeColorField),
        bearing: _num(item, config.bearingField),
        speedKmh: _num(item, config.speedField),
        tripId: _str(item, config.tripField),
        updatedAt: _date(item, config.updatedAtField),
      ));
    }
    return out;
  }

  static String? _str(Map item, String? path) {
    final v = _dig(item, path);
    if (v == null) return null;
    return v.toString();
  }

  static double? _num(Map item, String? path) {
    final v = _dig(item, path);
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _color(Map item, String? path) {
    final v = _dig(item, path);
    if (v == null) return null;
    final s = v.toString().trim().replaceFirst('#', '');
    if (s.length == 6) {
      return int.tryParse('FF$s', radix: 16);
    }
    return null;
  }

  static DateTime? _date(Map item, String? path) {
    final v = _dig(item, path);
    if (v == null) return null;
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        v.toInt() > 1e12 ? v.toInt() : v.toInt() * 1000,
      );
    }
    return DateTime.tryParse(v.toString());
  }

  static dynamic _dig(Map item, String? path) {
    if (path == null || path.isEmpty) return null;
    dynamic cur = item;
    for (final key in path.split('.')) {
      if (cur is Map && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur;
  }
}

/// Configuração do mapeamento JSON → [LiveVehicle].
///
/// Os valores por omissão são genéricos; o utilizador configura na aplicação
/// os caminhos específicos da fonte que quiser usar.
class JsonVehiclesConfig {
  const JsonVehiclesConfig({
    required this.url,
    this.arrayPath = const <String>[],
    this.idField = 'id',
    this.latField = 'lat',
    this.lonField = 'lon',
    this.routeField = 'route_id',
    this.routeNameField = 'route_short_name',
    this.headsignField = 'headsign',
    this.routeColorField,
    this.bearingField = 'bearing',
    this.speedField = 'speed',
    this.tripField = 'trip_id',
    this.updatedAtField = 'timestamp',
  });

  final String url;

  /// Caminho até ao array de veículos. Vazio se a raiz já for uma lista.
  final List<String> arrayPath;

  final String idField;
  final String latField;
  final String lonField;
  final String? routeField;
  final String? routeNameField;
  final String? headsignField;
  final String? routeColorField;
  final String? bearingField;
  final String? speedField;
  final String? tripField;
  final String? updatedAtField;
}
