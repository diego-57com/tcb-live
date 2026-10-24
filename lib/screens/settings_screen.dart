import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Definições: configuração do tempo real e dados/atribuição.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _arrayPath = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _url.dispose();
    _arrayPath.dispose();
    super.dispose();
  }

  void _seed(AppState app) {
    if (_seeded) return;
    _url.text = app.realtimeUrl;
    _arrayPath.text = app.realtimeArrayPath.join(', ');
    _seeded = true;
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
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mostrar posições em direto'),
                  subtitle: const Text('Usa um endpoint JSON (backend privado da TCB).'),
                  value: app.realtimeEnabled,
                  onChanged: (v) async {
                    await app.setRealtimeConfig(
                      url: _url.text.trim(),
                      enabled: v,
                      arrayPath: _parseArrayPath(_arrayPath.text),
                    );
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'URL do endpoint (JSON)',
                      hintText: 'https://…/vehicles',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: TextField(
                    controller: _arrayPath,
                    decoration: const InputDecoration(
                      labelText: 'Caminho até à lista (separado por vírgulas)',
                      hintText: 'ex.: data, vehicles  (vazio = a raiz é uma lista)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Como descobrir o URL: abre o site "Mapa em direto" da TCB no Chrome '
                      '→ F12 (DevTools) → separador Network → procura pedidos XHR/fetch '
                      'que devolvem posições de autocarros → copia esse URL aqui.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar e atualizar'),
                      onPressed: () async {
                        await app.setRealtimeConfig(
                          url: _url.text.trim(),
                          enabled: app.realtimeEnabled,
                          arrayPath: _parseArrayPath(_arrayPath.text),
                        );
                        if (app.realtimeEnabled && app.realtimeUrl.isNotEmpty) {
                          await app.refreshVehicles();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Configuração guardada.')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Dados'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Recarregar dados GTFS'),
              subtitle: const Text('Descarrega de novo o horário/paragens da TCB.'),
              onTap: app.loadGtfs,
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Atribuições'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dados de horários e paragens: Transportes Colectivos do Barreiro '
                '(GTFS, licença CC BY 4.0).\n\n'
                'Mapa: © OpenStreetMap contributors (tiles OSM).\n\n'
                'Esta app não é afiliada à TCB. As posições em tempo real usam o '
                'endpoint configurado por ti acima.',
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
              'TCB Live · v1.0.0',
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

  List<String> _parseArrayPath(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
