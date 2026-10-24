import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gtfs_models.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'stop_detail_screen.dart';

enum _Filter { all, favorites, nearby }

/// Lista e pesquisa de paragens.
class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});

  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feed = app.feed;

    return Scaffold(
      appBar: AppBar(title: const Text('Paragens')),
      body: feed == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchField(
                    controller: _search,
                    hint: 'Pesquisar paragem (nome ou nº)…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip(_Filter.all, 'Todas', Icons.all_inclusive),
                      _chip(_Filter.favorites, 'Favoritas', Icons.star),
                      _chip(_Filter.nearby, 'Próximas', Icons.near_me),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildList(context, app, feed),
                ),
              ],
            ),
    );
  }

  Widget _chip(_Filter value, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? scheme.onSecondaryContainer : scheme.outline,
        ),
        label: Text(label),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppState app, GtfsFeed feed) {
    final query = _normalize(_search.text.trim());
    var stops = feed.stops.values.where((s) {
      if (query.isNotEmpty) {
        final name = _normalize(s.name);
        final code = _normalize(s.code ?? '');
        if (!name.contains(query) && !code.contains(query)) return false;
      }
      if (_filter == _Filter.favorites && !app.favorites.contains(s.id)) {
        return false;
      }
      return true;
    }).toList();

    if (_filter == _Filter.nearby) {
      final origin = app.currentLocation ?? kDefaultCenter;
      stops = LocationService.sortByDistance(stops, origin);
    } else {
      stops.sort((a, b) => _numCompare(a.name, b.name));
    }

    if (stops.isEmpty) {
      return EmptyState(
        icon: _filter == _Filter.favorites ? Icons.star_border : Icons.search_off,
        title: _filter == _Filter.favorites
            ? 'Sem paragens favoritas'
            : 'Nenhuma paragem encontrada',
        subtitle: _filter == _Filter.favorites
            ? 'Toca na estrela numa paragem para a guardar.'
            : 'Tenta outro termo de pesquisa.',
      );
    }

    return ListView.separated(
      itemCount: stops.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final stop = stops[i];
        final fav = app.favorites.contains(stop.id);
        return ListTile(
          leading: _StopBadge(stop: stop),
          title: Text(stop.name),
          subtitle: Text(
            stop.code != null && stop.code!.isNotEmpty
                ? 'Paragem ${stop.code}'
                : 'Paragem ${stop.id}',
          ),
          trailing: IconButton(
            icon: Icon(
              fav ? Icons.star : Icons.star_border,
              color: fav ? Colors.amber : null,
            ),
            onPressed: () => app.toggleFavorite(stop.id),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
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

  static String _normalize(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    var out = s.toLowerCase();
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}

class _StopBadge extends StatelessWidget {
  const _StopBadge({required this.stop});

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = stop.code != null && stop.code!.isNotEmpty
        ? stop.code!
        : stop.id;
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: label.length > 3 ? 11 : 13,
        ),
      ),
    );
  }
}
