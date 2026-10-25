import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'route_detail_screen.dart';

/// Lista de carreiras (linhas) da TCB — uma entrada por número de carreira.
class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feed = app.feed;

    return Scaffold(
      appBar: AppBar(title: const Text('Carreiras')),
      body: feed == null
          ? const Center(child: CircularProgressIndicator())
          : _buildList(context, feed, app),
    );
  }

  Widget _buildList(BuildContext context, GtfsFeed feed, AppState app) {
    // Agrupa por shortName: um botão por carreira.
    final byNumber = <String, List<GtfsRoute>>{};
    for (final r in feed.routes.values) {
      final key = r.shortName.trim().isEmpty ? r.id : r.shortName.trim();
      (byNumber[key] ??= []).add(r);
    }

    final numbers = byNumber.keys.toList()
      ..sort((a, b) => _numCompare(a, b));

    return ListView.separated(
      itemCount: numbers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final number = numbers[i];
        final variants = byNumber[number]!;
        final rep = variants.first;
        final running = app.vehiclesForRouteNumber(number).length;

        return ListTile(
          leading: LineBadge(label: number, colorValue: rep.colorValue),
          title: Text('Carreira $number'),
          subtitle: Text(
            variants.length == 1
                ? (rep.longName.isNotEmpty ? rep.longName : '1 destino')
                : '${variants.length} destinos',
          ),
          trailing: running > 0
              ? Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.directions_bus, size: 16),
                  label: Text('$running'),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RouteDetailScreen(shortName: number),
            ),
          ),
        );
      },
    );
  }

  static int _numCompare(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }
}
