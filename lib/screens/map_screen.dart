import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../models/vehicle.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/markers.dart';
import 'stop_detail_screen.dart';

/// Mapa principal: paragens + posições em tempo real dos autocarros.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  bool _showStops = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('A carregar dados da TCB…'),
          ],
        ),
      );
    }

    if (app.error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Sem ligação aos dados',
        subtitle: app.error,
      );
    }

    final feed = app.feed!;
    final markers = <Marker>[];

    if (_showStops) {
      for (final stop in feed.stops.values) {
        markers.add(Marker(
          point: stop.point,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _openStop(stop),
            child: Center(
              child: StopMarkerWidget(
                selected: false,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ));
      }
    }

    for (final v in app.vehicles) {
      markers.add(Marker(
        point: v.point,
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: BusMarkerWidget(
          color: _vehicleColor(context, app, v),
          bearing: v.bearing,
        ),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: app.currentLocation ?? kDefaultCenter,
            initialZoom: 13,
            minZoom: 10,
            maxZoom: 18,
            onTap: (_, __) => _hideKeyboard(),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tcb_live',
              maxZoom: 19,
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Indicador de tempo real.
        if (app.realtimeEnabled)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _RealtimeChip(app: app),
          ),
        // Botões de ação.
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'stops',
                tooltip: _showStops ? 'Ocultar paragens' : 'Mostrar paragens',
                backgroundColor: _showStops
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                onPressed: () => setState(() => _showStops = !_showStops),
                child: Icon(
                  Icons.signpost,
                  color: _showStops
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'locate',
                tooltip: 'A minha localização',
                onPressed: () async {
                  final ok = await app.locateMe();
                  if (ok && app.currentLocation != null) {
                    _controller.move(app.currentLocation!, 15);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sem acesso à localização (permissão ou GPS).'),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _vehicleColor(BuildContext context, AppState app, LiveVehicle v) {
    if (v.routeColor != null) return Color(v.routeColor!);
    final feed = app.feed;
    if (feed != null && v.routeId != null) {
      final route = feed.routes[v.routeId];
      if (route != null) return Color(route.colorValue);
    }
    return Theme.of(context).colorScheme.primary;
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openStop(Stop stop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(stop: stop),
      ),
    );
  }
}

class _RealtimeChip extends StatelessWidget {
  const _RealtimeChip({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    String text;
    Color bg;

    if (app.realtimeError != null) {
      icon = Icons.error_outline;
      text = app.realtimeError!;
      bg = scheme.errorContainer;
    } else if (app.vehiclesLoading) {
      icon = Icons.sync;
      text = 'A atualizar posições…';
      bg = scheme.surfaceContainerHigh;
    } else {
      icon = Icons.wifi_tethering;
      text = '${app.vehicles.length} autocarros em direto';
      bg = scheme.primaryContainer;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: scheme.onSurface),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
