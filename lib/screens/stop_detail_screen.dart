import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../services/departure_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Detalhe de uma paragem: próximas passagens e carreiras que ali param.
class StopDetailScreen extends StatefulWidget {
  const StopDetailScreen({super.key, required this.stop});

  final Stop stop;

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feed = app.feed;
    final stop = widget.stop;

    final departures = feed == null
        ? const <Departure>[]
        : DepartureEngine.nextDepartures(feed, stop.id, _now);

    final routes = feed == null ? const <GtfsRoute>[] : feed.routesAtStop(stop.id);
    final fav = app.favorites.contains(stop.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(stop.name),
        actions: [
          IconButton(
            icon: Icon(
              fav ? Icons.star : Icons.star_border,
              color: fav ? Colors.amber : null,
            ),
            onPressed: () => app.toggleFavorite(stop.id),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _now = DateTime.now());
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              stop.code != null && stop.code!.isNotEmpty
                  ? 'Paragem ${stop.code}'
                  : 'Paragem ${stop.id}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (routes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Carreiras', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in routes)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LineBadge(
                          label: r.displayName,
                          colorValue: r.colorValue,
                          size: 26,
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Próximas passagens',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _clock(_now),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (departures.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: EmptyState(
                  icon: Icons.bus_alert,
                  title: 'Sem passagens nas próximas 2 horas',
                  subtitle: 'Pode não haver serviço a esta hora ou dia.',
                ),
              )
            else
              for (final d in departures)
                DepartureTile(departure: d, now: _now),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
