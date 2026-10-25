import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../models/vehicle.dart';
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

    final live = app.vehiclesForRouteNumber(number);

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
                    if (live.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.directions_bus, size: 16),
                        label: Text('${live.length} em direto'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _RouteMap(feed: feed, vehicles: live, routeColor: rep?.colorValue),
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
                Text('Paragens', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (_selected == null)
                  const EmptyState(icon: Icons.signpost, title: 'Seleciona uma variante')
                else ..._stopRows(feed, _selected!),
              ],
            ),
    );
  }

  List<Widget> _stopRows(GtfsFeed feed, Trip trip) {
    final stops = feed.stopsOfTrip(trip.id);
    if (stops.isEmpty) {
      return const [
        EmptyState(icon: Icons.signpost, title: 'Sem paragens definidas'),
      ];
    }
    return [
      for (var i = 0; i < stops.length; i++)
        _StopRow(index: i, stop: stops[i], total: stops.length),
    ];
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

/// Mapa da carreira: trajetos de todas as variantes + autocarros em direto.
class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.feed,
    required this.vehicles,
    this.routeColor,
  });

  final GtfsFeed feed;
  final List<LiveVehicle> vehicles;
  final int? routeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = routeColor != null ? Color(routeColor!) : scheme.primary;

    // Um polyline por shape distinto das variantes da carreira.
    final polylines = <Polyline>[];
    final seenShapes = <String>{};
    for (final trip in feed.trips.values) {
      final sid = trip.shapeId;
      if (sid == null || sid.isEmpty) continue;
      if (!seenShapes.add(sid)) continue;
      final pts = feed.shapes[sid];
      if (pts == null || pts.length < 2) continue;
      polylines.add(Polyline(
        points: pts,
        strokeWidth: 3,
        color: color.withAlpha(120),
      ));
    }

    final markers = <Marker>[
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
      ...polylines.expand((p) => p.points),
      ...vehicles.map((v) => v.point),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: allPoints.isNotEmpty
                ? allPoints.first
                : const LatLng(38.6526, -9.0748),
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
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.index,
    required this.stop,
    required this.total,
  });

  final int index;
  final Stop stop;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = index == 0;
    final isLast = index == total - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : scheme.outlineVariant,
                  ),
                ),
                Container(
                  width: isFirst || isLast ? 14 : 10,
                  height: isFirst || isLast ? 14 : 10,
                  decoration: BoxDecoration(
                    color: isFirst || isLast ? scheme.primary : scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2),
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
              child: Text(
                stop.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isFirst || isLast ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
