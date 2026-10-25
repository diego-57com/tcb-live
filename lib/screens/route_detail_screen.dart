import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../models/vehicle.dart';
import '../services/departure_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/markers.dart';

/// Detalhe de uma carreira (por número): variantes, trajeto e autocarros em direto.
class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.shortName,
    this.initialHeadsign,
  });

  final String shortName;
  final String? initialHeadsign;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  Trip? _selected;
  bool _seeded = false;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _seed(List<Trip> variants) {
    if (_seeded || variants.isEmpty) return;
    _seeded = true;
    final wanted = widget.initialHeadsign;
    if (wanted != null && wanted.trim().isNotEmpty) {
      final w = wanted.toLowerCase();
      for (final t in variants) {
        final h = t.headsign.toLowerCase();
        if (h == w || h.contains(w) || w.contains(h)) {
          _selected = t;
          return;
        }
      }
    }
    _selected = variants.first;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feed = app.feed;
    final number = widget.shortName;

    if (feed == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Carreira $number')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final routes = feed.routesForShortName(number);
    final rep = routes.isNotEmpty ? routes.first : null;
    final trips = feed.tripsForShortName(number);
    final variants = _variants(trips);
    _seed(variants);

    final selected = _selected;
    // Filtrar autocarros pela variante selecionada
    final liveVehicles = _vehiclesForVariant(
      app.vehiclesForRouteNumber(number),
      selected ?? (variants.isNotEmpty ? variants.first : null),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Carreira $number')),
      body: trips.isEmpty
          ? const EmptyState(
              icon: Icons.route,
              title: 'Sem viagens para esta carreira',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    LineBadge(
                      label: number,
                      colorValue: rep?.colorValue ?? 0xFF0B7A4E,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${variants.length} destino${variants.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (liveVehicles.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.directions_bus, size: 16),
                        label: Text('${liveVehicles.length} em direto'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Variante', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < variants.length; i++)
                      ChoiceChip(
                        selected: _selected?.id == variants[i].id,
                        label: Text(
                          variants[i].headsign.isNotEmpty
                              ? variants[i].headsign
                              : 'Viagem ${i + 1}',
                        ),
                        onSelected: (_) =>
                            setState(() => _selected = variants[i]),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selected == null)
                  const EmptyState(
                      icon: Icons.signpost, title: 'Seleciona uma variante')
                else ...[
                  _RouteMap(
                    feed: feed,
                    trip: selected!,
                    vehicles: liveVehicles,
                    routeColor: rep?.colorValue,
                  ),
                  const SizedBox(height: 16),
                  Text('Paragens',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  ..._stopRows(feed, selected!, liveVehicles),
                ],
              ],
            ),
    );
  }

  /// Filtra os veículos pela variante (trip) selecionada.
  /// Se a headsign da viagem coincide (total ou parcial) com a headsign de algum
  /// veículo, apenas esses veículos são devolvidos. Se não houver match, devolve
  /// a lista completa (para não ficar sem automóveis).
  List<LiveVehicle> _vehiclesForVariant(
      List<LiveVehicle> vehicles, Trip? trip) {
    if (trip == null || trip.headsign == null || trip.headsign.trim().isEmpty) {
      return vehicles; // Sem headsign da viagem → mostrar todos
    }
    final h = trip.headsign.trim().toLowerCase();
    final matched = vehicles.where((v) {
      final hV = (v.headsign ?? '').trim().toLowerCase();
      if (hV.isEmpty) return false; // veículo sem headsign → excluir
      // Match total ou parcial (contém)
      return hV == h || hV.contains(h) || h.contains(h);
    }).toList();
    // Se ninguém match, mostrar todos (fallback)
    return matched.isEmpty ? vehicles : matched;
  }

  /// Devolve as previsões de passagens para as paragens da variante selecionada,
  /// organizadas pela variante.
  List<Widget> _stopRows(
      GtfsFeed feed, Trip trip, List<LiveVehicle> vehicles) {
    final stops = feed.stopsOfTrip(trip.id);
    if (stops.isEmpty) {
      return const [
        EmptyState(icon: Icons.signpost, title: 'Sem paragens definidas'),
      ];
    }

    // Associa cada autocarro à paragem mais próxima (posição aproximada).
    final busAtStop = <int, List<LiveVehicle>>{};
    for (final v in vehicles) {
      final idx = _nearestStopIndex(stops, v.point);
      if (idx >= 0) (busAtStop[idx] ??= []).add(v);
    }

    // Viagens desta variante (mesmo shape/headsign da trip selecionada).
    final tripIds = feed
        .tripsForShortName(widget.shortName)
        .where((t) => _sameVariant(t, trip))
        .map((t) => t.id)
        .toSet();

    return [
      for (var i = 0; i < stops.length; i++)
        _StopRow(
          index: i,
          stop: stops[i],
          total: stops.length,
          buses: busAtStop[i] ?? const [],
          routeColor: _routeColorValue(feed, trip),
          departures: DepartureEngine.nextDeparturesForTrips(
            feed,
            stops[i].id,
            tripIds.isEmpty ? {trip.id} : tripIds,
            _now,
            limit: 4,
          ),
          now: _now,
        ),
    ];
  }

  static bool _sameVariant(Trip a, Trip b) {
    if (a.shapeId != null && b.shapeId != null) return a.shapeId == b.shapeId;
    return a.headsign == b.headsign;
  }

  int _routeColorValue(GtfsFeed feed, Trip trip) {
    final route = feed.routes[trip.routeId];
    return route?.colorValue ?? 0xFF0B7A4E;
  }

  /// Índice da paragem mais próxima de [point] (posição aproximada).
  int _nearestStopIndex(List<Stop> stops, LatLng point) {
    const distance = Distance();
    var best = -1;
    var bestMeters = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final m = distance.as(LengthUnit.Meter, point, stops[i].point);
      if (m < bestMeters) {
        bestMeters = m;
        best = i;
      }
    }
    return best;
  }

  List<Trip> _variants(List<Trip> trips) {
    final seen = <String>{};
    final out = <Trip>[];
    for (final t in trips) {
      final key = t.headsign.isEmpty ? t.id : t.headsign;
      if (seen.add(key)) out.add(t);
    }
    out.sort((a, b) => a.headsign.compareTo(b.headsign));
    return out;
  }
}

/// Mapa de uma única variante: trajeto, paragens da variante e autocarros.
class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.feed,
    required this.trip,
    required this.vehicles,
    this.routeColor,
  });

  final GtfsFeed feed;
  final Trip trip;
  final List<LiveVehicle> vehicles;
  final int? routeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = routeColor != null ? Color(routeColor!) : scheme.primary;

    // Apenas o shape da variante selecionada — sem sobreposição.
    final shapeId = trip.shapeId;
    final path = shapeId == null ? <LatLng>[] : (feed.shapes[shapeId] ?? <LatLng>[]);

    final stops = feed.stopsOfTrip(trip.id);

    final markers = <Marker>[
      for (final stop in stops)
        Marker(
          point: stop.point,
          width: 18,
          height: 18,
          alignment: Alignment.center,
          child: StopMarkerWidget(selected: false, color: color),
        ),
      for (final v in vehicles)
        Marker(
          point: v.point,
          width: 44,
          height: 56,
          alignment: Alignment.center,
          child: BusMarkerWidget(
            color: color,
            bearing: v.bearing,
            label: v.routeName,
          ),
        ),
    ];

    final allPoints = <LatLng>[
      ...path,
      ...stops.map((s) => s.point),
      ...vehicles.map((v) => v.point),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          options: MapOptions(
            initialCenter:
                allPoints.isNotEmpty ? allPoints.first : const LatLng(38.6526, -9.0748),
            initialZoom: 13,
            initialCameraFit: allPoints.length >= 2
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(allPoints),
                    padding: const EdgeInsets.all(32),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tcb_live',
              maxZoom: 19,
            ),
            if (path.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: path, strokeWidth: 4, color: color),
              ]),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}

/// Linha do tempo de uma paragem: bolinha do autocarro, nome e horários.
class _StopRow extends StatefulWidget {
  const _StopRow({
    required this.index,
    required this.stop,
    required this.total,
    required this.buses,
    required this.routeColor,
    required this.departures,
    required this.now,
  });

  final int index;
  final Stop stop;
  final int total;
  final List<LiveVehicle> buses;
  final int routeColor;
  final List<Departure> departures;
  final DateTime now;

  @override
  State<_StopRow> createState() => _StopRowState;
}

class _StopRowState extends State<_StopRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = widget.index == 0;
    final isLast = widget.index == widget.total - 1;
    final color = Color(widget.routeColor);
    final hasBus = widget.buses.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isFirst ? Colors.transparent : scheme.outlineVariant,
                        ),
                      ),
                      if (hasBus)
                        _BusBubble(color: color)
                      else
                        Container(
                          width: isFirst || isLast ? 14 : 10,
                          height: isFirst || isLast ? 14 : 10,
                          decoration: BoxDecoration(
                            color: isFirst || isLast ? scheme.primary : scheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(scheme.primary, width: 2),
                          ),
                        ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isLast ? Colors.transparent : scheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.stop.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight:
                                          isFirst || isLast ? FontWeight.w700 : FontWeight.w500,
                                    ),
                              ),
                              if (hasBus)
                                Text(
                                  'Autocarro nesta paragem',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: color),
                                ),
                            ],
                          ),
                        ),
                        if (_nextLabel() != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _nextLabel()!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
                          ),
                        ],
                        Icon(
                          _open ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: scheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: widget.departures.isEmpty
                ? Text(
                    'Sem passagens nas próximas 3 horas.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in widget.departures)
                        _DepartureLine(departure: d, now: widget.now),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Minutos até à próxima passagem, se estiver a 10 min ou menos.
  String? _nextLabel() {
    if (widget.departures.isEmpty) return null;
    final mins = widget.departures.first.minutesUntil(widget.now);
    if (mins > 10) return null;
    return mins <= 0 ? 'agora' : '$mins min';
  }
}

/// Bolinha com o símbolo do autocarro na linha do tempo.
class _BusBubble extends StatelessWidget {
  const _BusBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.color(Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: const Icon(Icons.directions_bus, size: 13, color: Colors.white),
    );
  }
}

/// Uma passagem dentro do menu expandido de uma paragem.
class _DepartureLine extends StatelessWidget {
  const _DepartureLine({required this.departure, required this.now});

  final Departure departure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mins = departure.minutesUntil(now);
    final time = _clock(departure.departureSeconds);

    // Tempo até chegar: em minutos quando for 10 min ou menos.
    final String wait;
    if (mins <= 0) {
      wait = 'agora';
    } else if (mins <= 10) {
      wait = '$mins min';
    } else {
      wait = 'em ${mins ~/ 60}h${(mins % 60).toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 14, color: scheme.outline),
          const SizedBox(width: 6),
          Text(
            time,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              departure.headsign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            wait,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: mins <= 10 ? FontWeight.w700 : FontWeight.w400,
                  color: mins <= 0 ? scheme.primary : (mins < 5 ? scheme.error : scheme.outline),
                ),
          ),
        ],
      ),
    );
  }

  static String _clock(int seconds) {
    final h = (seconds ~/ 3600) % 24;
    final m = (seconds % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}