import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'route_detail_screen.dart';

/// Lista de carreiras (linhas) da TCB.
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
          : _buildList(context, feed),
    );
  }

  Widget _buildList(BuildContext context, GtfsFeed feed) {
    final routes = feed.routes.values.toList()
      ..sort((a, b) => _numCompare(a.displayName, b.displayName));

    return ListView.separated(
      itemCount: routes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final r = routes[i];
        return ListTile(
          leading: LineBadge(label: r.displayName, colorValue: r.colorValue),
          title: Text('Carreira ${r.displayName}'),
          subtitle: r.longName.isNotEmpty && r.longName != r.displayName
              ? Text(r.longName)
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RouteDetailScreen(route: r)),
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
