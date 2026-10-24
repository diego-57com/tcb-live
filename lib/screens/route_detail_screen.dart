import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Detalhe de uma carreira: variantes (destinos), trajeto no mapa e paragens.
class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key, required this.route});

  final GtfsRoute route;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  Trip? _selected;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feed = app.feed;
    final route = widget.route;

    if (feed == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Carreira ${route.displayName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final trips = feed.trips.values.where((t) => t.routeId == route.id).toList();
    final variants = _variants(trips);
    final selected =
        _selected ?? (variants.isNotEmpty ? variants.first : null);

    return Scaffold(
      appBar: AppBar(title: Text('Carreira ${route.displayName}')),
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
                      label: route.displayName,
                      colorValue: route.colorValue,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        route.longName.isNotEmpty &&
                                route.longName != route.displayName
                            ? route.longName
                            : 'Carreira ${route.displayName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                if (variants.length > 1) ...[
                  const SizedBox(height: 16),
                  Text('Destinos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: variants.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final v = variants[i];
                        final isSel = selected?.id == v.id;
                        return ChoiceChip(
                          selected: isSel,
                          label: Text(v.headsign.isNotEmpty ? v.headsign : 'Viagem ${i + 1}'),
                          onSelected: (_) => setState(() => _selected = v),
                        );
                      },
                    ),
                  ),
                ],
                if (selected != null && selected.shapeId != null &&
                    feed.shapes.containsKey(selected.shapeId)) ...[
                  const SizedBox(height: 16),
                  _ShapeMap(points: feed.shapes[selected.shapeId!]!),
                ],
                const SizedBox(height: 16),
                Text('Paragens', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (selected == null)
                  const EmptyState(icon: Icons.signpost, title: 'Seleciona um destino')
                else
                  ..._stopRows(feed, selected),
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
    return out;
  }
}

class _ShapeMap extends StatelessWidget {
  const _ShapeMap({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(24),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tcb_live',
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 5,
                  color: scheme.primary,
                ),
              ],
            ),
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
                // Linha de ligação.
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
                    color: isFirst || isLast
                        ? scheme.primary
                        : scheme.surface,
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
                      fontWeight: isFirst || isLast
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
