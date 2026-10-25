import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Definições: configuração do tempo real (feita pelo utilizador) e dados.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _arrayPath = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _bearing = TextEditingController();
  final _headsign = TextEditingController();
  final _color = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _url.dispose();
    _arrayPath.dispose();
    _lat.dispose();
    _lon.dispose();
    _bearing.dispose();
    _headsign.dispose();
    _color.dispose();
    super.dispose();
  }

  void _seed(AppState app) {
    if (_seeded) return;
    _url.text = app.realtimeUrl;
    _arrayPath.text = app.realtimeArrayPath.join(', ');
    _lat.text = app.latField;
    _lon.text = app.lonField;
    _bearing.text = app.bearingField;
    _headsign.text = app.headsignField;
    _color.text = app.colorField;
    _seeded = true;
  }

  Future<void> _save(AppState app) async {
    await app.setRealtimeConfig(
      url: _url.text.trim(),
      enabled: app.realtimeEnabled,
      arrayPath: _parseList(_arrayPath.text),
      latField: _lat.text.trim().isEmpty ? 'lat' : _lat.text.trim(),
      lonField: _lon.text.trim().isEmpty ? 'lon' : _lon.text.trim(),
      bearingField: _bearing.text.trim(),
      headsignField: _headsign.text.trim(),
      colorField: _color.text.trim(),
    );
    if (app.realtimeEnabled && app.realtimeUrl.isNotEmpty) {
      await app.refreshVehicles();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuração guardada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _seed(app);

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'Tempo real'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar posições em direto'),
                    subtitle: const Text(
                      'Lê um endpoint JSON que tu configurares abaixo.',
                    ),
                    value: app.realtimeEnabled,
                    onChanged: (v) async {
                      await app.setRealtimeConfig(
                        url: _url.text.trim(),
                        enabled: v,
                        arrayPath: _parseList(_arrayPath.text),
                        latField: _lat.text.trim().isEmpty
                            ? 'lat'
                            : _lat.text.trim(),
                        lonField: _lon.text.trim().isEmpty
                            ? 'lon'
                            : _lon.text.trim(),
                        bearingField: _bearing.text.trim(),
                        headsignField: _headsign.text.trim(),
                        colorField: _color.text.trim(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _field(_url, 'URL do endpoint (JSON)',
                      'https://exemplo.pt/api/realtime'),
                  _field(_arrayPath, 'Caminho até à lista (vírgulas)',
                      'ex.: results, vehicles  (vazio = a raiz é a lista)'),
                  const Divider(height: 32),
                  Text(
                    'Mapeamento dos campos (vazio = padrão)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _field(_lat, 'Campo da latitude', 'padrão: lat'),
                  _field(_lon, 'Campo da longitude', 'padrão: lon'),
                  _field(_bearing, 'Campo do rumo (bearing)', 'padrão: bearing'),
                  _field(_headsign, 'Campo do destino', 'padrão: headsign'),
                  _field(_color, 'Campo da cor (hex)',
                      'opcional, ex.: route_color'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar e atualizar'),
                    onPressed: () => _save(app),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atualizar posições a cada ${app.refreshSeconds}s',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in const [3, 5, 10, 15, 30, 60])
                        ChoiceChip(
                          label: Text('${s}s'),
                          selected: app.refreshSeconds == s,
                          onSelected: (_) => app.setRefreshSeconds(s),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Dados'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Recarregar dados GTFS'),
              subtitle:
                  const Text('Descarrega de novo o horário/paragens da TCB.'),
              onTap: app.loadGtfs,
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Atribuições'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dados de horários e paragens: Transportes Colectivos do '
                'Barreiro (GTFS, licença CC BY 4.0).\n\n'
                'Mapa: © OpenStreetMap contributors.\n\n'
                'As posições em tempo real usam apenas o endpoint que '
                'configurares nesta aplicação. Esta app não é afiliada à TCB.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      height: 1.5,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'TCB Live · v1.1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  List<String> _parseList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
